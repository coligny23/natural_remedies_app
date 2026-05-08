#!/usr/bin/env python3
"""
rebuild_tflite_embedding_index.py

Rebuilds AfyaBomba semantic retrieval assets using the SAME TFLite encoder
that is used during evaluation/app runtime.

It creates:
  assets/embeddings/index.bin
  assets/embeddings/meta.json

Run from project root:
  python tools/rebuild_tflite_embedding_index.py

Optional:
  python tools/rebuild_tflite_embedding_index.py --dry-run
  python tools/rebuild_tflite_embedding_index.py --max-items 10
"""

import argparse
import glob
import json
import re
import struct
from pathlib import Path

import numpy as np
from tokenizers import BertWordPieceTokenizer


TOKEN_RE = re.compile(r"\s+")


def l2_normalize(x, eps=1e-9):
    x = np.asarray(x, dtype=np.float32)
    norm = np.linalg.norm(x)
    return x / (norm + eps)


def clean_text(text):
    text = text or ""
    text = text.replace("\u2014", " ")
    text = text.replace("\u2013", " ")
    text = TOKEN_RE.sub(" ", text)
    return text.strip()


def load_items(corpus_glob):
    items = []

    for path in sorted(glob.glob(corpus_glob)):
        file_path = Path(path)
        data = json.loads(file_path.read_text(encoding="utf-8"))

        if not isinstance(data, list):
            print(f"[SKIP] {file_path}: expected JSON array")
            continue

        for item in data:
            if not isinstance(item, dict):
                continue

            item_id = item.get("id")
            title = item.get("title") or ""

            # Support both naming styles
            content = (
                item.get("contentEn")
                or item.get("content_en")
                or item.get("content")
                or ""
            )

            # If content is stored in sections, merge section bodies
            if not content and isinstance(item.get("sections"), list):
                parts = []
                for section in item["sections"]:
                    if isinstance(section, dict):
                        parts.append(section.get("title", ""))
                        parts.append(section.get("body", ""))
                        parts.append(section.get("text", ""))
                content = "\n".join(parts)

            if not item_id or not title:
                continue

            # Important: use the same searchable text consistently.
            # Title is repeated to give it stronger representation in the embedding.
            embedding_text = clean_text(f"{title}. {title}. {content}")

            items.append({
                "id": item_id,
                "title": title,
                "source_file": file_path.name,
                "text": embedding_text
            })

    return items


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


def tokenize_text(tokenizer, text, max_len=128):
    encoded = tokenizer.encode(text)

    input_ids = encoded.ids[:max_len]
    attention_mask = [1] * len(input_ids)
    token_type_ids = [0] * len(input_ids)

    if len(input_ids) < max_len:
        pad_len = max_len - len(input_ids)
        input_ids += [0] * pad_len
        attention_mask += [0] * pad_len
        token_type_ids += [0] * pad_len

    return {
        "input_ids": np.array([input_ids], dtype=np.int32),
        "attention_mask": np.array([attention_mask], dtype=np.int32),
        "token_type_ids": np.array([token_type_ids], dtype=np.int32),
    }


def set_model_inputs(interpreter, encoded_inputs):
    input_details = interpreter.get_input_details()

    used = set()

    for i, inp in enumerate(input_details):
        name = inp["name"].lower()
        shape = inp["shape"]

        if "input_ids" in name or "input_word_ids" in name or "ids" in name:
            value = encoded_inputs["input_ids"]
            used.add("input_ids")
        elif "attention_mask" in name or "mask" in name:
            value = encoded_inputs["attention_mask"]
            used.add("attention_mask")
        elif "token_type" in name or "segment" in name:
            value = encoded_inputs["token_type_ids"]
            used.add("token_type_ids")
        else:
            # Safe fallback by position
            if i == 0:
                value = encoded_inputs["input_ids"]
            elif i == 1:
                value = encoded_inputs["attention_mask"]
            else:
                value = encoded_inputs["token_type_ids"]

        # Ensure shape compatibility
        value = value.astype(inp["dtype"])

        if list(value.shape) != list(shape):
            try:
                interpreter.resize_tensor_input(inp["index"], value.shape, strict=False)
                interpreter.allocate_tensors()
            except Exception:
                pass

        interpreter.set_tensor(inp["index"], value)


def choose_output_vector(interpreter, output_mode="auto"):
    output_details = interpreter.get_output_details()

    outputs = []
    for idx, out in enumerate(output_details):
        arr = interpreter.get_tensor(out["index"])
        arr = np.asarray(arr)
        outputs.append((idx, out["name"], arr))

    if output_mode != "auto":
        out_idx = int(output_mode)
        arr = outputs[out_idx][2]
        return output_to_vector(arr), outputs[out_idx][1]

    # Prefer 2D output shaped [1, D], usually pooled sentence embedding.
    for idx, name, arr in outputs:
        squeezed = np.squeeze(arr)
        if squeezed.ndim == 1:
            return squeezed.astype(np.float32), name

    # If output is token embeddings [1, seq_len, hidden], use first token as CLS.
    # This is a fallback; mean pooling would need attention_mask.
    for idx, name, arr in outputs:
        if arr.ndim == 3:
            cls = arr[0, 0, :]
            return cls.astype(np.float32), name

    # Last fallback: flatten first output
    idx, name, arr = outputs[0]
    return np.squeeze(arr).reshape(-1).astype(np.float32), name


def output_to_vector(arr):
    arr = np.asarray(arr)
    squeezed = np.squeeze(arr)
    if squeezed.ndim == 1:
        return squeezed.astype(np.float32)
    if arr.ndim == 3:
        return arr[0, 0, :].astype(np.float32)
    return squeezed.reshape(-1).astype(np.float32)


def encode_text(interpreter, tokenizer, text, max_len=128, output_mode="auto"):
    encoded = tokenize_text(tokenizer, text, max_len=max_len)
    set_model_inputs(interpreter, encoded)
    interpreter.invoke()
    vector, output_name = choose_output_vector(interpreter, output_mode=output_mode)
    return l2_normalize(vector), output_name


def write_index(index_path, vectors):
    vectors = np.asarray(vectors, dtype=np.float32)
    n, d = vectors.shape

    index_path.parent.mkdir(parents=True, exist_ok=True)

    with index_path.open("wb") as f:
        f.write(struct.pack("<I", n))
        f.write(struct.pack("<H", d))
        f.write(vectors.tobytes(order="C"))


def write_meta(meta_path, items, model_path, vocab_path, output_name, max_len, vector_dim):
    meta_path.parent.mkdir(parents=True, exist_ok=True)

    # Keep meta as a list because your current evaluator expects list indexing.
    meta = []
    for item in items:
        meta.append({
            "id": item["id"],
            "title": item["title"],
            "source_file": item["source_file"],
            "model": str(model_path),
            "vocab": str(vocab_path),
            "output_tensor": output_name,
            "max_len": max_len,
            "vector_dim": vector_dim
        })

    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="assets/models/encoder.tflite")
    parser.add_argument("--vocab", default="assets/models/vocab.txt")
    parser.add_argument("--corpus-glob", default="assets/corpus/en/*.json")
    parser.add_argument("--index-out", default="assets/embeddings/index.bin")
    parser.add_argument("--meta-out", default="assets/embeddings/meta.json")
    parser.add_argument("--max-len", type=int, default=128)
    parser.add_argument("--max-items", type=int, default=None)
    parser.add_argument("--output-mode", default="auto", help="auto or output index such as 0, 1, 2")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    model_path = Path(args.model)
    vocab_path = Path(args.vocab)
    index_out = Path(args.index_out)
    meta_out = Path(args.meta_out)

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")
    if not vocab_path.exists():
        raise FileNotFoundError(f"Vocab not found: {vocab_path}")

    items = load_items(args.corpus_glob)

    if args.max_items:
        items = items[:args.max_items]

    print("\nRebuilding AfyaBomba TFLite embedding index")
    print("------------------------------------------")
    print(f"Model: {model_path}")
    print(f"Vocab: {vocab_path}")
    print(f"Corpus glob: {args.corpus_glob}")
    print(f"Items loaded: {len(items)}")
    print(f"Output index: {index_out}")
    print(f"Meta output: {meta_out}")

    if not items:
        raise RuntimeError("No corpus items loaded. Check corpus path.")

    if args.dry_run:
        print("\nDry run. First 10 items:")
        for item in items[:10]:
            print(f"  {item['id']} | {item['title']} | {item['source_file']}")
        return

    tokenizer = BertWordPieceTokenizer(
        str(vocab_path),
        lowercase=True,
        clean_text=True,
        handle_chinese_chars=True,
        strip_accents=True,
    )

    interpreter = load_tflite_interpreter(str(model_path))

    vectors = []
    output_name_used = None

    for i, item in enumerate(items, start=1):
        vector, output_name = encode_text(
            interpreter,
            tokenizer,
            item["text"],
            max_len=args.max_len,
            output_mode=args.output_mode
        )

        if output_name_used is None:
            output_name_used = output_name
            print(f"Using output tensor: {output_name_used}")
            print(f"Vector dimension: {vector.shape[0]}")

        vectors.append(vector)

        if i % 25 == 0 or i == len(items):
            print(f"Encoded {i}/{len(items)}")

    vectors = np.vstack(vectors).astype(np.float32)

    write_index(index_out, vectors)
    write_meta(
        meta_out,
        items,
        model_path,
        vocab_path,
        output_name_used,
        args.max_len,
        vectors.shape[1]
    )

    print("\nDone.")
    print(f"Wrote: {index_out}")
    print(f"Wrote: {meta_out}")
    print(f"Final shape: {vectors.shape}")
    print(f"Index size: {index_out.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
