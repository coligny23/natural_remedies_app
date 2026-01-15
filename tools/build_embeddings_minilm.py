# tools/build_embeddings_minilm.py
import os, json, glob, struct
from pathlib import Path

import numpy as np
from tqdm import tqdm
import onnxruntime as ort
from tokenizers import BertWordPieceTokenizer

# ----- CONFIG -----
CORPUS_GLOBS = [
    "assets/corpus/en/*.json",
    # "assets/corpus/sw/*.json",
]
VOCAB_PATH = "assets/models/vocab.txt"
ONNX_PATH  = "assets/models/minilm_l6_v2_simplified.onnx"
OUT_META   = "assets/embeddings/meta.json"
OUT_BIN    = "assets/embeddings/index.bin"
MAX_LEN    = 128
# Your preferred batch if the model allows dynamic batching.
PREFERRED_BATCH = 16
LOWERCASE  = True  # MiniLM uncased
# -------------------

def l2_normalize(x: np.ndarray, axis: int = -1, eps: float = 1e-9):
    n = np.linalg.norm(x, axis=axis, keepdims=True)
    return x / (n + eps)

def _first_words(s: str, n=8):
    s = " ".join(s.strip().split())
    parts = s.split()
    return " ".join(parts[:n]) + ("…" if len(parts) > n else "")

def _extract_text(obj) -> str:
    if isinstance(obj, str):
        return obj.strip()
    if not isinstance(obj, dict):
        return ""
    for k in ["contentEn", "contentSW", "contentSw", "content", "content_en", "body", "text"]:
        v = obj.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    secs = obj.get("sections")
    if isinstance(secs, list):
        parts = []
        for s in secs:
            if isinstance(s, dict):
                b = s.get("body") or s.get("text") or ""
                if isinstance(b, str) and b.strip():
                    parts.append(b.strip())
            elif isinstance(s, str) and s.strip():
                parts.append(s.strip())
        if parts:
            return "\n\n".join(parts)
    return ""

def collect_items():
    items = []
    bad_files = 0
    for pat in CORPUS_GLOBS:
        for path in glob.glob(pat):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception as e:
                print(f"[WARN] Failed to load {path}: {e}")
                bad_files += 1
                continue

            if isinstance(data, dict):
                for key in ["items", "data", "records", "list"]:
                    if key in data and isinstance(data[key], list):
                        data = data[key]
                        break

            if not isinstance(data, list):
                print(f"[WARN] {path} did not contain a list; skipping.")
                bad_files += 1
                continue

            stem = Path(path).stem
            lang = "en" if "/en/" in path.replace("\\", "/") else "sw"

            for i, it in enumerate(data):
                if isinstance(it, dict):
                    cid = (it.get("id") or it.get("cid") or "").strip()
                    title = (it.get("title") or "").strip()
                    text = _extract_text(it)
                else:
                    cid = ""
                    title = ""
                    text = _extract_text(it)

                if not text:
                    continue
                if not cid:
                    cid = f"auto-{stem}-{i}"
                if not title:
                    title = _first_words(text, 8)

                items.append({"id": cid, "title": title, "lang": lang, "text": text})

    if bad_files:
        print(f"[INFO] Skipped {bad_files} files due to shape/errors.")
    return items

def pad_batch(tokenizer, texts):
    enc = tokenizer.encode_batch(texts)
    ids, mask = [], []
    for e in enc:
        input_ids = e.ids[:MAX_LEN]
        attn = [1] * len(input_ids)
        if len(input_ids) < MAX_LEN:
            pad = MAX_LEN - len(input_ids)
            input_ids += [0] * pad
            attn += [0] * pad
        ids.append(input_ids)
        mask.append(attn)
    ids_np  = np.asarray(ids,  dtype=np.int64)
    mask_np = np.asarray(mask, dtype=np.int64)
    return ids_np, mask_np

def pick_output_name(sess):
    out_infos = sess.get_outputs()
    names = [o.name for o in out_infos]
    # Prefer explicit "embeddings"
    if "embeddings" in names:
        return "embeddings"
    # Else pick one whose last dim looks like an embedding size (384/512/768)
    for o in out_infos:
        shp = o.shape
        if shp and isinstance(shp[-1], int) and shp[-1] in (384, 512, 768):
            return o.name
    # Fallback to first
    return names[0]

def squeeze_to_2d(arr):
    # Accept [B, D], [B, 1, D], [B, D, 1]
    if arr.ndim == 3 and arr.shape[1] == 1:
        arr = arr[:, 0, :]
    if arr.ndim == 3 and arr.shape[2] == 1:
        arr = arr[:, :, 0]
    return arr

def main():
    os.makedirs(os.path.dirname(OUT_META), exist_ok=True)

    print("Loading tokenizer from:", VOCAB_PATH)
    tok = BertWordPieceTokenizer(
        VOCAB_PATH,
        lowercase=LOWERCASE,
        clean_text=True,
        handle_chinese_chars=True,
        strip_accents=True,
    )

    print("Loading ONNX model from:", ONNX_PATH)
    sess = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
    in0 = sess.get_inputs()[0]
    required_batch = in0.shape[0]  # 1 or None
    output_name = pick_output_name(sess)
    print(
        "Inputs:", [i.name for i in sess.get_inputs()],
        "| Outputs:", [o.name for o in sess.get_outputs()],
        "| Using:", output_name,
        "| Required batch:", required_batch
    )

    items = collect_items()
    print(f"Collected {len(items)} items.")
    if not items:
        raise SystemExit("No items collected.")

    # Warm-up on ONE text to detect embedding dimension and verify I/O
    warm_ids, warm_mask = pad_batch(tok, [items[0]["text"]])
    warm_out = sess.run([output_name], {"input_ids": warm_ids, "attention_mask": warm_mask})[0]
    warm_out = squeeze_to_2d(warm_out)
    if warm_out.ndim != 2 or warm_out.shape[0] != 1:
        raise RuntimeError(f"Unexpected warm-up output shape {warm_out.shape}")
    emb_dim = int(warm_out.shape[1])
    print("Detected embedding dim:", emb_dim)

    # Write meta
    meta = [{"id": it["id"], "title": it["title"], "lang": it["lang"]} for it in items]
    with open(OUT_META, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    print("Wrote meta ->", OUT_META)

    # Write index with detected dim
    with open(OUT_BIN, "wb") as fbin:
        N = len(items)
        fbin.write(struct.pack("<I", N))
        fbin.write(struct.pack("<H", emb_dim))

        def encode_batch(text_batch):
            ids_np, mask_np = pad_batch(tok, text_batch)
            out = sess.run([output_name], {"input_ids": ids_np, "attention_mask": mask_np})[0]
            out = squeeze_to_2d(out)
            if out.shape[-1] != emb_dim:
                raise RuntimeError(f"Unexpected embedding shape {out.shape}, expected [B, {emb_dim}]")
            out = l2_normalize(out, axis=1).astype("float32")
            return out

        texts = [it["text"] for it in items]

        # Write warm-up vector first (already computed)
        fbin.write(l2_normalize(warm_out, axis=1).astype("float32").tobytes(order="C"))
        start = 1

        # Choose effective batch
        if isinstance(required_batch, int) and required_batch == 1:
            eff_batch = 1
        else:
            eff_batch = PREFERRED_BATCH

        for i in tqdm(range(start, len(texts), eff_batch), desc="Embedding"):
            batch = texts[i:i+eff_batch]
            if eff_batch == 1 and len(batch) > 1:
                # Safety; shouldn't hit here
                for t in batch:
                    fbin.write(encode_batch([t]).tobytes(order="C"))
            else:
                # If required_batch is 1 but eff_batch>1 (shouldn't happen due to logic above),
                # we still guard by splitting to singletons.
                if isinstance(required_batch, int) and required_batch == 1 and len(batch) > 1:
                    for t in batch:
                        fbin.write(encode_batch([t]).tobytes(order="C"))
                else:
                    vecs = encode_batch(batch)
                    fbin.write(vecs.tobytes(order="C"))

    print(f"Wrote index -> {OUT_BIN} ({os.path.getsize(OUT_BIN)/1024:.1f} KB)")
    print("Done.")

if __name__ == "__main__":
    main()
