#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Builds a compact embedding index (vectors for Day 2 wiring).
Output:
  assets/embeddings/meta.json
  assets/embeddings/index.bin

Format of index.bin:
  [uint32 N][uint16 D][N*D float32 row-major]

Run (from project root):
  python tools/build_embeddings.py --glob "assets/corpus/en/*.json" --dim 384 --seed 42

"""

import os
import json
import glob
import struct
import argparse
from typing import List, Dict

import numpy as np

def try_tqdm(total: int):
    """Return (update_fn, close_fn) with tqdm if present; else minimal fallback."""
    try:
        from tqdm import tqdm  # type: ignore
        bar = tqdm(total=total, unit="item", ncols=80)
        return bar.update, bar.close
    except Exception:
        count = 0
        def update(n=1):
            nonlocal count
            count += n
            if count % 250 == 0 or count == total:
                print(f"  progress: {count}/{total}")
        def close():
            pass
        return update, close

def load_items(paths: List[str]) -> List[Dict]:
    """Read your corpus into a flat list of {id, title, lang, text}.
    Adapts to your JSON array shape: [{ id, title, contentEn, contentSw, ...}, ...].
    """
    items: List[Dict] = []
    for p in paths:
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            print(f"!! Skipping {p}: {e}")
            continue

        if not isinstance(data, list):
            print(f"!! Skipping {p}: not a JSON array")
            continue

        for it in data:
            if not isinstance(it, dict):
                continue
            cid = it.get("id") or it.get("ID") or ""
            title = it.get("title") or it.get("name") or ""
            # Prefer English for now; fall back to Swahili if missing
            text = (it.get("contentEn") or it.get("contentSW") or it.get("contentSw") or "").strip()
            if not cid or not title or not text:
                continue
            items.append({"id": cid, "title": title, "lang": "en", "text": text})
    return items

def write_meta(meta_path: str, items: List[Dict]):
    # Compact JSON (saves size); still UTF-8 safe
    os.makedirs(os.path.dirname(meta_path), exist_ok=True)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, separators=(",", ":"))
    print(f"✓ Wrote meta: {meta_path} ({len(items)} items)")

def write_index_bin(bin_path: str, N: int, D: int, rng: np.random.Generator, batch_size: int = 1024):
    os.makedirs(os.path.dirname(bin_path), exist_ok=True)
    with open(bin_path, "wb") as f:
        # Header
        f.write(struct.pack("<I", N))
        f.write(struct.pack("<H", D))

        update, close = try_tqdm(N)
        remaining = N
        # Generate fake vectors in batches, normalize, and stream to file
        while remaining > 0:
            bsz = min(batch_size, remaining)
            # Normal(0,1) then L2 normalize
            vecs = rng.normal(size=(bsz, D)).astype("float32")
            norms = np.linalg.norm(vecs, axis=1, keepdims=True) + 1e-9
            vecs /= norms
            f.write(vecs.tobytes(order="C"))
            remaining -= bsz
            update(bsz)
        close()
    print(f"✓ Wrote index: {bin_path} (N={N}, D={D})")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glob", default="assets/corpus/en/*.json", help="Glob for corpus JSON files")
    ap.add_argument("--dim", type=int, default=384, help="Embedding dimension")
    ap.add_argument("--seed", type=int, default=42, help="RNG seed (deterministic)")
    ap.add_argument("--batch_size", type=int, default=1024, help="Vectors per batch when writing")
    ap.add_argument("--out_dir", default="assets/embeddings", help="Output dir for meta/index")
    args = ap.parse_args()

    files = sorted(glob.glob(args.glob))
    if not files:
        print(f"!! No files matched: {args.glob}")
        return

    print("Scanning files:")
    for p in files:
        print("  -", p)

    items = load_items(files)
    if not items:
        print("!! No valid items found in corpus JSON. Aborting.")
        return

    # Day 2: FAKE vectors (deterministic). Swap to real encoder later.
    N, D = len(items), args.dim
    rng = np.random.default_rng(args.seed)

    out_dir = args.out_dir
    meta_path = os.path.join(out_dir, "meta.json")
    bin_path = os.path.join(out_dir, "index.bin")

    write_meta(meta_path, items)
    write_index_bin(bin_path, N, D, rng, batch_size=args.batch_size)

    # Small sanity read-back (header only)
    with open(bin_path, "rb") as f:
        n2 = struct.unpack("<I", f.read(4))[0]
        d2 = struct.unpack("<H", f.read(2))[0]
    assert n2 == N and d2 == D, "Header mismatch after write()"
    print("✓ Sanity check OK")

if __name__ == "__main__":
    main()
