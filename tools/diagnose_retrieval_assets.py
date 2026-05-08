#!/usr/bin/env python3
"""
diagnose_retrieval_assets.py

Purpose:
Checks whether AfyaBomba retrieval assets are internally consistent:
- index.bin header and size
- meta.json count vs index count
- duplicate IDs in meta
- expected IDs in eval_queries.json
- exact-title coverage for sanity checking

Run from project root:
  python tools/diagnose_retrieval_assets.py
"""

import json
import struct
from pathlib import Path
from collections import Counter

INDEX = Path("assets/embeddings/index.bin")
META = Path("assets/embeddings/meta.json")
EVAL = Path("tools/eval_queries.json")


def read_index_header(path: Path):
    with path.open("rb") as f:
        n = struct.unpack("<I", f.read(4))[0]
        d = struct.unpack("<H", f.read(2))[0]
    expected_size = 4 + 2 + (n * d * 4)
    actual_size = path.stat().st_size
    return n, d, expected_size, actual_size


def main():
    print("\nAfyaBomba Retrieval Asset Diagnostic")
    print("-----------------------------------")

    if not INDEX.exists():
        print(f"[ERROR] Missing index file: {INDEX}")
        return
    if not META.exists():
        print(f"[ERROR] Missing meta file: {META}")
        return

    n, d, expected_size, actual_size = read_index_header(INDEX)
    print(f"Index vectors: {n}")
    print(f"Index dimension: {d}")
    print(f"Index file size: {actual_size:,} bytes")
    print(f"Expected file size from header: {expected_size:,} bytes")

    if expected_size == actual_size:
        print("[OK] index.bin size matches its header.")
    else:
        print("[WARNING] index.bin size does not match its header.")

    meta = json.loads(META.read_text(encoding="utf-8"))
    print(f"Meta items: {len(meta)}")

    if len(meta) == n:
        print("[OK] meta.json count matches index.bin vector count.")
    else:
        print("[WARNING] meta.json count does not match index.bin vector count.")

    ids = [x.get("id") for x in meta]
    duplicate_ids = [item for item, count in Counter(ids).items() if count > 1]
    print(f"Duplicate IDs in meta: {len(duplicate_ids)}")
    if duplicate_ids:
        print("Examples:", duplicate_ids[:20])

    print("\nFirst 10 meta items:")
    for item in meta[:10]:
        print(f"  {item.get('id')} | {item.get('title')}")

    if EVAL.exists():
        queries = json.loads(EVAL.read_text(encoding="utf-8"))
        expected_ids = [q.get("expected_id") for q in queries]
        missing = sorted(set(expected_ids) - set(ids))
        print(f"\nEvaluation queries: {len(queries)}")
        print(f"Expected IDs missing from meta.json: {len(missing)}")
        if missing:
            print("Missing examples:")
            for x in missing[:30]:
                print(" ", x)
        else:
            print("[OK] All expected IDs exist in meta.json.")

    print("\nInterpretation:")
    print("- If the index dimension is 128 while the model is MiniLM all-MiniLM-L6-v2, verify that the stored vectors are truly the final sentence embeddings.")
    print("- If exact-title queries fail during evaluation, the query encoder and index encoder are probably not the same.")
    print("- If meta/index counts mismatch or expected IDs are missing, rebuild the index and meta together.")


if __name__ == "__main__":
    main()
