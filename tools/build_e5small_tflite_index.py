import argparse
import glob
import json
import re
import struct
from pathlib import Path

import numpy as np
import tensorflow as tf
from transformers import AutoTokenizer


def clean_text(text):
    return re.sub(r"\s+", " ", text or "").strip()


def l2_normalize(x):
    x = x.reshape(-1).astype(np.float32)
    return x / (np.linalg.norm(x) + 1e-9)


def load_items(corpus_glob, lang):
    items = []

    for path in sorted(glob.glob(corpus_glob)):
        file_path = Path(path)

        if file_path.name in {"synonyms.json", "sw_import.json"}:
            continue

        data = json.loads(file_path.read_text(encoding="utf-8"))

        if not isinstance(data, list):
            continue

        for item in data:
            item_id = item.get("id")
            title = item.get("title", "")
            title_sw = item.get("titleSw", "")
            aliases_sw = item.get("aliasesSw", [])

            content_en = item.get("contentEn") or item.get("content_en") or ""
            content_sw = item.get("contentSw") or item.get("content_sw") or ""

            if not item_id or not title:
                continue

            if "missingFields" in item and "too_short" in item["missingFields"]:
                continue

            if lang == "sw":
                alias_text = " ".join(aliases_sw) if isinstance(aliases_sw, list) else ""
                text = f"passage: {title_sw}. {title}. {alias_text}. {content_sw}. English reference: {content_en}"
            else:
                text = f"passage: {title}. {content_en}"

            items.append({
                "id": item_id,
                "title": title,
                "titleSw": title_sw,
                "aliasesSw": aliases_sw,
                "source_file": file_path.name,
                "text": clean_text(text),
            })

    return items


def encode_text(interpreter, tokenizer, text, max_len):
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


def write_index(path, vectors):
    vectors = np.asarray(vectors, dtype=np.float32)
    n, d = vectors.shape

    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("wb") as f:
        f.write(struct.pack("<I", n))
        f.write(struct.pack("<H", d))
        f.write(vectors.tobytes(order="C"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=["en", "sw"], required=True)
    parser.add_argument("--model", default="assets/models_e5small/encoder_e5small_dynamic_quant.tflite")
    parser.add_argument("--tokenizer-dir", default="assets/models_e5small")
    parser.add_argument("--corpus-glob", required=True)
    parser.add_argument("--index-out", required=True)
    parser.add_argument("--meta-out", required=True)
    parser.add_argument("--max-len", type=int, default=128)

    args = parser.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(args.tokenizer_dir)

    interpreter = tf.lite.Interpreter(model_path=args.model)
    interpreter.allocate_tensors()

    items = load_items(args.corpus_glob, args.lang)

    print(f"Loaded items: {len(items)}")
    print(f"Model: {args.model}")

    vectors = []

    for i, item in enumerate(items, start=1):
        vector = encode_text(
            interpreter,
            tokenizer,
            item["text"],
            max_len=args.max_len,
        )
        vectors.append(vector)

        if i % 25 == 0 or i == len(items):
            print(f"Encoded {i}/{len(items)}")

    vectors = np.vstack(vectors).astype(np.float32)

    write_index(Path(args.index_out), vectors)

    meta = [
        {
            "id": item["id"],
            "title": item["title"],
            "titleSw": item.get("titleSw", ""),
            "aliasesSw": item.get("aliasesSw", []),
            "source_file": item["source_file"],
            "model": args.model,
            "vector_dim": int(vectors.shape[1]),
        }
        for item in items
    ]

    Path(args.meta_out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.meta_out).write_text(
        json.dumps(meta, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print("\nDone.")
    print(f"Index: {args.index_out}")
    print(f"Meta: {args.meta_out}")
    print(f"Shape: {vectors.shape}")


if __name__ == "__main__":
    main()