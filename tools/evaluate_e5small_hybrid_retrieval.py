#!/usr/bin/env python3
"""
evaluate_e5small_hybrid_retrieval.py

Evaluates E5 semantic retrieval with optional lightweight lexical/title reranking.

"""

import argparse
import json
import re
import struct
from pathlib import Path

import numpy as np
import torch
from transformers import AutoTokenizer, AutoModel


MODEL_ID = "intfloat/multilingual-e5-small"
TOKEN_RE = re.compile(r"[a-zA-ZÀ-ÿ0-9']+")


def tokenize(text):
    return [t.lower() for t in TOKEN_RE.findall(text or "") if len(t) > 1]


def average_pool(last_hidden_states, attention_mask):
    last_hidden = last_hidden_states.masked_fill(~attention_mask[..., None].bool(), 0.0)
    return last_hidden.sum(dim=1) / attention_mask.sum(dim=1)[..., None]


def load_index(index_path):
    with open(index_path, "rb") as f:
        n = struct.unpack("<I", f.read(4))[0]
        d = struct.unpack("<H", f.read(2))[0]
        vectors = np.frombuffer(f.read(), dtype=np.float32)
    return vectors.reshape(n, d)


@torch.no_grad()
def encode_query(query, tokenizer, model, device, max_len=512):
    text = "query: " + query
    inputs = tokenizer(
        [text],
        max_length=max_len,
        padding=True,
        truncation=True,
        return_tensors="pt",
    ).to(device)

    outputs = model(**inputs)
    embeddings = average_pool(outputs.last_hidden_state, inputs["attention_mask"])
    embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
    return embeddings.cpu().numpy()[0].astype(np.float32)


def lexical_score(query, item):
    q_tokens = set(tokenize(query))
    title_tokens = set(tokenize(item.get("title", "")))
    item_id_tokens = set(tokenize(item.get("id", "").replace("-", " ")))

    if not q_tokens:
        return 0.0

    title_hits = len(q_tokens & title_tokens)
    id_hits = len(q_tokens & item_id_tokens)

    score = 0.0
    score += 2.0 * title_hits
    score += 1.0 * id_hits

    # If the English title phrase is directly present in code-switched query.
    title = (item.get("title") or "").lower()
    query_l = (query or "").lower()
    if title and title in query_l:
        score += 4.0

    return score / max(1, len(q_tokens))


def search(query_vec, query_text, index_vectors, meta, k=5, top_n=50, lexical_weight=0.0):
    semantic_scores = index_vectors @ query_vec
    candidate_indices = np.argsort(-semantic_scores)[:top_n]

    rescored = []
    for idx in candidate_indices:
        sem = float(semantic_scores[idx])
        lex = lexical_score(query_text, meta[idx])
        final = sem + lexical_weight * lex
        rescored.append((final, sem, lex, idx))

    rescored.sort(key=lambda x: -x[0])

    results = []
    for rank, (final, sem, lex, idx) in enumerate(rescored[:k], start=1):
        item = meta[idx]
        results.append({
            "rank": rank,
            "id": item["id"],
            "title": item.get("title", ""),
            "score": float(final),
            "semantic_score": float(sem),
            "lexical_score": float(lex),
        })
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", required=True)
    parser.add_argument("--meta", required=True)
    parser.add_argument("--queries", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-len", type=int, default=512)
    parser.add_argument("--top-n", type=int, default=50)
    parser.add_argument("--lexical-weight", type=float, default=0.0)
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Loading model: {MODEL_ID}")
    print(f"Device: {device}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval()
    model.to(device)

    index_vectors = load_index(args.index)
    meta = json.loads(Path(args.meta).read_text(encoding="utf-8"))
    queries = json.loads(Path(args.queries).read_text(encoding="utf-8"))

    if len(meta) != index_vectors.shape[0]:
        raise RuntimeError(f"Meta/index count mismatch: meta={len(meta)}, index={index_vectors.shape[0]}")

    top1 = top3 = top5 = 0
    details = []

    for i, q in enumerate(queries, start=1):
        query = q["query"]
        expected_id = q["expected_id"]

        qvec = encode_query(query, tokenizer, model, device, max_len=args.max_len)

        if qvec.shape[0] != index_vectors.shape[1]:
            raise RuntimeError(f"Dimension mismatch: query={qvec.shape[0]}, index={index_vectors.shape[1]}")

        results = search(
            qvec, query, index_vectors, meta,
            k=5,
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
        "model": MODEL_ID,
        "index": args.index,
        "meta": args.meta,
        "queries": args.queries,
        "total_queries": total,
        "top_n_candidates": args.top_n,
        "lexical_weight": args.lexical_weight,
        "top_1_hits": top1,
        "top_3_hits": top3,
        "top_5_hits": top5,
        "top_1_accuracy": top1 / total if total else 0,
        "top_3_accuracy": top3 / total if total else 0,
        "top_5_accuracy": top5 / total if total else 0,
        "details": details,
    }

    Path(args.output).write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

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
