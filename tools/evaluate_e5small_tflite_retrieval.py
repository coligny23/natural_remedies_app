import argparse
import json
import re
import struct
from pathlib import Path

import numpy as np
import tensorflow as tf
from transformers import AutoTokenizer


TOKEN_RE = re.compile(r"[a-zA-ZÀ-ÿ0-9']+")


def tokenize(text):
    return [t.lower() for t in TOKEN_RE.findall(text or "") if len(t) > 1]


def l2_normalize(x):
    x = x.reshape(-1).astype(np.float32)
    return x / (np.linalg.norm(x) + 1e-9)


def load_index(index_path):
    with open(index_path, "rb") as f:
        n = struct.unpack("<I", f.read(4))[0]
        d = struct.unpack("<H", f.read(2))[0]
        vectors = np.frombuffer(f.read(), dtype=np.float32)

    return vectors.reshape(n, d)


def encode_query(interpreter, tokenizer, query, max_len):
    text = "query: " + query

    encoded = tokenizer(
        text,
        padding="max_length",
        truncation=True,
        max_length=max_len,
        return_tensors="np",
    )

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    for i, inp in enumerate(input_details):
        name = inp["name"].lower()

        if "input_ids" in name:
            value = encoded["input_ids"]
        elif "attention_mask" in name or "mask" in name:
            value = encoded["attention_mask"]
        else:
            value = encoded["input_ids"] if i == 0 else encoded["attention_mask"]

        interpreter.set_tensor(inp["index"], value.astype(inp["dtype"]))

    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]["index"])

    return l2_normalize(output)


def lexical_score(query, item):
    q_tokens = set(tokenize(query))

    title_tokens = set(tokenize(item.get("title", "")))
    title_sw_tokens = set(tokenize(item.get("titleSw", "")))
    alias_tokens = set()

    aliases = item.get("aliasesSw", [])
    if isinstance(aliases, list):
        alias_tokens = set(tokenize(" ".join(aliases)))

    id_tokens = set(tokenize(item.get("id", "").replace("-", " ")))

    if not q_tokens:
        return 0.0

    hits = 0
    hits += 2 * len(q_tokens & title_tokens)
    hits += 3 * len(q_tokens & title_sw_tokens)
    hits += 3 * len(q_tokens & alias_tokens)
    hits += len(q_tokens & id_tokens)

    return hits / max(1, len(q_tokens))


def search(query_vec, query_text, index_vectors, meta, top_k=5, top_n=50, lexical_weight=0.0):
    scores = index_vectors @ query_vec
    candidate_indices = np.argsort(-scores)[:top_n]

    rescored = []

    for idx in candidate_indices:
        semantic = float(scores[idx])
        lexical = lexical_score(query_text, meta[idx])
        final = semantic + lexical_weight * lexical
        rescored.append((final, semantic, lexical, idx))

    rescored.sort(key=lambda x: -x[0])

    results = []

    for rank, (final, semantic, lexical, idx) in enumerate(rescored[:top_k], start=1):
        item = meta[idx]
        results.append({
            "rank": rank,
            "id": item["id"],
            "title": item.get("title", ""),
            "titleSw": item.get("titleSw", ""),
            "score": float(final),
            "semantic_score": float(semantic),
            "lexical_score": float(lexical),
        })

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="assets/models_e5small/encoder_e5small_dynamic_quant.tflite")
    parser.add_argument("--tokenizer-dir", default="assets/models_e5small")
    parser.add_argument("--index", required=True)
    parser.add_argument("--meta", required=True)
    parser.add_argument("--queries", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-len", type=int, default=128)
    parser.add_argument("--lexical-weight", type=float, default=0.0)
    parser.add_argument("--top-n", type=int, default=50)

    args = parser.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(args.tokenizer_dir)

    interpreter = tf.lite.Interpreter(model_path=args.model)
    interpreter.allocate_tensors()

    index_vectors = load_index(args.index)
    meta = json.loads(Path(args.meta).read_text(encoding="utf-8"))
    queries = json.loads(Path(args.queries).read_text(encoding="utf-8"))

    top1 = top3 = top5 = 0
    details = []

    for i, q in enumerate(queries, start=1):
        query = q["query"]
        expected_id = q["expected_id"]

        qvec = encode_query(
            interpreter,
            tokenizer,
            query,
            max_len=args.max_len,
        )

        results = search(
            qvec,
            query,
            index_vectors,
            meta,
            top_k=5,
            top_n=args.top_n,
            lexical_weight=args.lexical_weight,
        )

        ids = [r["id"] for r in results]

        h1 = expected_id in ids[:1]
        h3 = expected_id in ids[:3]
        h5 = expected_id in ids[:5]

        top1 += int(h1)
        top3 += int(h3)
        top5 += int(h5)

        details.append({
            "query": query,
            "expected_id": expected_id,
            "top_5_results": results,
            "hit_top_1": h1,
            "hit_top_3": h3,
            "hit_top_5": h5,
        })

        print(f"Evaluated {i}/{len(queries)}")

    total = len(queries)

    report = {
        "model": args.model,
        "index": args.index,
        "meta": args.meta,
        "queries": args.queries,
        "total_queries": total,
        "lexical_weight": args.lexical_weight,
        "top_n": args.top_n,
        "top_1_hits": top1,
        "top_3_hits": top3,
        "top_5_hits": top5,
        "top_1_accuracy": top1 / total if total else 0,
        "top_3_accuracy": top3 / total if total else 0,
        "top_5_accuracy": top5 / total if total else 0,
        "details": details,
    }

    Path(args.output).write_text(
        json.dumps(report, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print("\nEvaluation complete")
    print("-------------------")
    print(f"Total queries: {total}")
    print(f"Lexical weight: {args.lexical_weight}")
    print(f"Top-N candidates reranked: {args.top_n}")
    print(f"Top-1 Accuracy: {top1}/{total} = {report['top_1_accuracy']:.2%}")
    print(f"Top-3 Accuracy: {top3}/{total} = {report['top_3_accuracy']:.2%}")
    print(f"Top-5 Accuracy: {top5}/{total} = {report['top_5_accuracy']:.2%}")
    print(f"Report saved to: {args.output}")


if __name__ == "__main__":
    main()