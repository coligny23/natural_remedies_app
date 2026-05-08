import argparse
import glob
import json
import re
import struct
from pathlib import Path

import numpy as np
import torch
from transformers import AutoTokenizer, AutoModel


MODEL_ID = "intfloat/multilingual-e5-small"


def clean_text(text):
    return re.sub(r"\s+", " ", text or "").strip()


def average_pool(last_hidden_states, attention_mask):
    last_hidden = last_hidden_states.masked_fill(~attention_mask[..., None].bool(), 0.0)
    return last_hidden.sum(dim=1) / attention_mask.sum(dim=1)[..., None]


def load_items(corpus_glob):
    items = []

    for path in sorted(glob.glob(corpus_glob)):
        file_path = Path(path)
        data = json.loads(file_path.read_text(encoding="utf-8"))

        if not isinstance(data, list):
            continue

        for item in data:
            if not isinstance(item, dict):
                continue

            item_id = item.get("id")
            title = item.get("title") or ""

            content = (
                item.get("contentEn")
                or item.get("content_en")
                or item.get("contentSw")
                or item.get("content_sw")
                or item.get("content")
                or ""
            )

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

            # E5 convention: documents/passages should be prefixed with "passage:"
            text = clean_text(f"passage: {title}. {content}")

            items.append({
                "id": item_id,
                "title": title,
                "source_file": file_path.name,
                "text": text,
            })

    return items


@torch.no_grad()
def encode_texts(texts, tokenizer, model, device, batch_size=16, max_len=512):
    all_embeddings = []

    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]

        inputs = tokenizer(
            batch,
            max_length=max_len,
            padding=True,
            truncation=True,
            return_tensors="pt",
        ).to(device)

        outputs = model(**inputs)
        embeddings = average_pool(outputs.last_hidden_state, inputs["attention_mask"])
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)

        all_embeddings.append(embeddings.cpu().numpy().astype(np.float32))

        print(f"Encoded {min(i + batch_size, len(texts))}/{len(texts)}")

    return np.vstack(all_embeddings)


def write_index(path, vectors):
    vectors = vectors.astype(np.float32)
    n, d = vectors.shape

    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("wb") as f:
        f.write(struct.pack("<I", n))
        f.write(struct.pack("<H", d))
        f.write(vectors.tobytes(order="C"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--corpus-glob", required=True)
    parser.add_argument("--index-out", required=True)
    parser.add_argument("--meta-out", required=True)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--max-len", type=int, default=512)
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"

    print(f"Loading model: {MODEL_ID}")
    print(f"Device: {device}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval()
    model.to(device)

    # Save tokenizer/model config locally for documentation and possible export later
    save_dir = Path("assets/models_e5small")
    save_dir.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(save_dir)
    model.config.save_pretrained(save_dir)

    items = load_items(args.corpus_glob)
    print(f"Loaded items: {len(items)}")

    if not items:
        raise RuntimeError("No corpus items loaded. Check your corpus glob path.")

    vectors = encode_texts(
        [item["text"] for item in items],
        tokenizer,
        model,
        device,
        batch_size=args.batch_size,
        max_len=args.max_len,
    )

    write_index(Path(args.index_out), vectors)

    meta = [
        {
            "id": item["id"],
            "title": item["title"],
            "source_file": item["source_file"],
            "model": MODEL_ID,
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