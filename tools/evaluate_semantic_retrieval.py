#!/usr/bin/env python3
"""
evaluate_semantic_retrieval.py

Evaluates AfyaBomba semantic retrieval using a TFLite encoder and a precomputed
embedding index.

IMPORTANT:
For your encoder.tflite, the real embedding output is likely output index 2:
  Outputs:
    0: inputs_0   [1, 128] int64  -> NOT embedding
    1: inputs_1   [1, 128] int64  -> NOT embedding
    2: Identity_2 [1, 384] float32 -> embedding

Run:
  python tools\evaluate_semantic_retrieval.py --output-mode 2

Expected files:
  assets/models/encoder.tflite
  assets/models/vocab.txt
  assets/embeddings/index.bin
  assets/embeddings/meta.json
  tools/eval_queries.json
"""

import argparse
import json
import struct
from pathlib import Path

import numpy as np
from tokenizers import BertWordPieceTokenizer


def l2_normalize(x, eps=1e-9):
    x = np.asarray(x, dtype=np.float32)
    norm = np.linalg.norm(x)
    return x / (norm + eps)


def load_index(index_path):
    with open(index_path, "rb") as f:
        n = struct.unpack("<I", f.read(4))[0]
        d = struct.unpack("<H", f.read(2))[0]
        vectors = np.frombuffer(f.read(), dtype=np.float32)

    vectors = vectors.reshape(n, d)
    return vectors


def tokenize_query(tokenizer, text, max_len=128):
    encoded = tokenizer.encode(text)

    input_ids = encoded.ids[:max_len]
    attention_mask = [1] * len(input_ids)

    if len(input_ids) < max_len:
        pad_len = max_len - len(input_ids)
        input_ids += [0] * pad_len
        attention_mask += [0] * pad_len

    # Your TFLite model expects int64 inputs.
    input_ids = np.array([input_ids], dtype=np.int64)
    attention_mask = np.array([attention_mask], dtype=np.int64)

    return input_ids, attention_mask


def load_tflite_interpreter(model_path):
    try:
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=model_path)
    except Exception:
        try:
            from tflite_runtime.interpreter import Interpreter
            interpreter = Interpreter(model_path=model_path)
        except Exception as e:
            raise RuntimeError(
                "Could not load TensorFlow Lite interpreter. "
                "Install TensorFlow with: pip install tensorflow"
            ) from e

    interpreter.allocate_tensors()
    return interpreter


def encode_query(interpreter, tokenizer, query, max_len=128, output_mode=2):
    input_ids, attention_mask = tokenize_query(tokenizer, query, max_len=max_len)

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    for i, inp in enumerate(input_details):
        name = inp["name"].lower()

        if "input_ids" in name or "inputs_0" in name or i == 0:
            value = input_ids.astype(inp["dtype"])
        elif "attention_mask" in name or "inputs_1" in name or i == 1:
            value = attention_mask.astype(inp["dtype"])
        else:
            value = input_ids.astype(inp["dtype"])

        interpreter.set_tensor(inp["index"], value)

    interpreter.invoke()

    if output_mode == "auto":
        # Prefer a float output shaped [1, D], especially D > 128.
        chosen = None
        for out in output_details:
            arr = interpreter.get_tensor(out["index"])
            arr_np = np.asarray(arr)
            if np.issubdtype(arr_np.dtype, np.floating):
                squeezed = np.squeeze(arr_np)
                if squeezed.ndim == 1:
                    chosen = out
                    break
        if chosen is None:
            raise RuntimeError(
                "No suitable floating-point embedding output found. "
                "Specify --output-mode manually, e.g. --output-mode 2."
            )
        output = interpreter.get_tensor(chosen["index"])
        output_name = chosen["name"]
    else:
        output_idx = int(output_mode)
        if output_idx >= len(output_details):
            raise RuntimeError(
                f"Invalid output index {output_idx}. "
                f"Model has {len(output_details)} outputs."
            )
        chosen = output_details[output_idx]
        output = interpreter.get_tensor(chosen["index"])
        output_name = chosen["name"]

    output = np.array(output).squeeze()

    if output.ndim != 1:
        raise RuntimeError(f"Unexpected model output shape from {output_name}: {output.shape}")

    if not np.issubdtype(output.dtype, np.floating):
        raise RuntimeError(
            f"Selected output {output_name} is {output.dtype}, not float. "
            "You probably selected token IDs instead of the embedding. "
            "Use --output-mode 2 for this model."
        )

    return l2_normalize(output.astype(np.float32)), output_name


def top_k_search(query_vector, index_vectors, meta, k=5):
    scores = index_vectors @ query_vector
    top_indices = np.argsort(-scores)[:k]

    results = []
    for rank, idx in enumerate(top_indices, start=1):
        item = meta[idx]
        results.append({
            "rank": rank,
            "id": item["id"],
            "title": item.get("title", ""),
            "score": float(scores[idx])
        })

    return results


def evaluate(args):
    meta = json.load(open(args.meta, encoding="utf-8"))
    index_vectors = load_index(args.index)

    if len(meta) != index_vectors.shape[0]:
        raise RuntimeError(
            f"Meta/index mismatch: meta has {len(meta)} items, "
            f"index has {index_vectors.shape[0]} vectors."
        )

    tokenizer = BertWordPieceTokenizer(
        args.vocab,
        lowercase=True,
        clean_text=True,
        handle_chinese_chars=True,
        strip_accents=True,
    )

    interpreter = load_tflite_interpreter(args.model)

    queries = json.load(open(args.queries, encoding="utf-8"))

    total = len(queries)
    top1_hits = 0
    top3_hits = 0
    top5_hits = 0

    detailed_results = []
    output_name_used = None

    for q in queries:
        query_text = q["query"]
        expected_id = q["expected_id"]

        query_vector, output_name = encode_query(
            interpreter,
            tokenizer,
            query_text,
            max_len=args.max_len,
            output_mode=args.output_mode
        )

        if output_name_used is None:
            output_name_used = output_name
            print(f"Using TFLite output tensor: {output_name_used}")
            print(f"Query vector dimension: {query_vector.shape[0]}")
            print(f"Index vector dimension: {index_vectors.shape[1]}")

        if query_vector.shape[0] != index_vectors.shape[1]:
            raise RuntimeError(
                f"Dimension mismatch: query vector has {query_vector.shape[0]} dimensions, "
                f"but index vectors have {index_vectors.shape[1]} dimensions. "
                "Rebuild index.bin using the same output tensor, e.g. --output-mode 2."
            )

        results = top_k_search(query_vector, index_vectors, meta, k=5)
        top_ids = [r["id"] for r in results]

        hit1 = expected_id in top_ids[:1]
        hit3 = expected_id in top_ids[:3]
        hit5 = expected_id in top_ids[:5]

        top1_hits += int(hit1)
        top3_hits += int(hit3)
        top5_hits += int(hit5)

        detailed_results.append({
            "query": query_text,
            "expected_id": expected_id,
            "top_5_results": results,
            "hit_top_1": hit1,
            "hit_top_3": hit3,
            "hit_top_5": hit5
        })

    report = {
        "model": args.model,
        "index": args.index,
        "meta": args.meta,
        "queries": args.queries,
        "output_tensor": output_name_used,
        "total_queries": total,
        "top_1_accuracy": top1_hits / total if total else 0,
        "top_3_accuracy": top3_hits / total if total else 0,
        "top_5_accuracy": top5_hits / total if total else 0,
        "top_1_hits": top1_hits,
        "top_3_hits": top3_hits,
        "top_5_hits": top5_hits,
        "details": detailed_results
    }

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print("\nEvaluation complete")
    print("-------------------")
    print(f"Total queries: {total}")
    print(f"Top-1 Accuracy: {top1_hits}/{total} = {report['top_1_accuracy']:.2%}")
    print(f"Top-3 Accuracy: {top3_hits}/{total} = {report['top_3_accuracy']:.2%}")
    print(f"Top-5 Accuracy: {top5_hits}/{total} = {report['top_5_accuracy']:.2%}")
    print(f"\nDetailed report saved to: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("--model", default="assets/models/encoder.tflite")
    parser.add_argument("--index", default="assets/embeddings/index.bin")
    parser.add_argument("--meta", default="assets/embeddings/meta.json")
    parser.add_argument("--vocab", default="assets/models/vocab.txt")
    parser.add_argument("--queries", default="tools/eval_queries.json")
    parser.add_argument("--output", default="tools/eval_report.json")
    parser.add_argument("--max-len", type=int, default=128)
    parser.add_argument(
        "--output-mode",
        default="2",
        help="TFLite output index. For this model, use 2 because Identity_2 is the 384-dim embedding."
    )

    args = parser.parse_args()
    evaluate(args)
