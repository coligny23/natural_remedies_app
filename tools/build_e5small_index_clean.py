#!/usr/bin/env python3
"""
build_e5small_index_clean.py

Builds a cleaner E5 multilingual embedding index for AfyaBomba.

Key improvements:
1. Skips raw/import/helper files such as sw_import.json and synonyms.json.
2. Skips malformed IDs and very short generic records.
3. Skips records marked too_short in missingFields.
4. Allows bilingual document text: title + contentSw + contentEn.
5. Stores clean meta.json with source file and vector dimension.

CMD examples:

English:
python tools\build_e5small_index_clean.py --lang en --corpus-glob assets/corpus/en/*.json --index-out assets\embeddings_e5small\index_en_clean.bin --meta-out assets\embeddings_e5small\meta_en_clean.json

Swahili:
python tools\build_e5small_index_clean.py --lang sw --corpus-glob assets/corpus/sw/*.json --index-out assets\embeddings_e5small\index_sw_clean.bin --meta-out assets\embeddings_e5small\meta_sw_clean.json
"""

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

SKIP_FILENAMES = {
    "sw_import.json",
    "synonyms.json",
}

# These are section headers or recurring generic/noisy entries that often behave like retrieval hubs.
# You can remove items from this list if you intentionally want them searchable.
SKIP_IDS = {
    "principle-section-0",
}

VALID_ID_RE = re.compile(r"^[a-z0-9][a-z0-9\-]*$")


def clean_text(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def average_pool(last_hidden_states, attention_mask):
    last_hidden = last_hidden_states.masked_fill(~attention_mask[..., None].bool(), 0.0)
    return last_hidden.sum(dim=1) / attention_mask.sum(dim=1)[..., None]


def extract_sections(item, key):
    sections = item.get(key)
    if not isinstance(sections, list):
        return ""
    parts = []
    for section in sections:
        if isinstance(section, dict):
            parts.append(section.get("title", ""))
            parts.append(section.get("body", ""))
            parts.append(section.get("text", ""))
    return "\n".join(parts)


def load_items(corpus_glob, lang="sw", min_chars=80, bilingual=True):
    items = []
    skipped = []

    for path in sorted(glob.glob(corpus_glob)):
        file_path = Path(path)

        if file_path.name in SKIP_FILENAMES:
            skipped.append((file_path.name, "helper/import file"))
            continue

        data = json.loads(file_path.read_text(encoding="utf-8"))

        if not isinstance(data, list):
            skipped.append((file_path.name, "not a list"))
            continue

        for item in data:
            if not isinstance(item, dict):
                continue

            item_id = item.get("id", "")
            title = item.get("title", "")

            if not item_id or not title:
                skipped.append((file_path.name, "missing id/title"))
                continue

            if item_id in SKIP_IDS:
                skipped.append((item_id, "skip-id"))
                continue

            if not VALID_ID_RE.match(item_id):
                skipped.append((item_id[:80], "malformed id"))
                continue

            missing_fields = item.get("missingFields") or []
            if "too_short" in missing_fields:
                skipped.append((item_id, "too_short"))
                continue

            content_en = clean_text(
                item.get("contentEn")
                or item.get("content_en")
                or item.get("content")
                or extract_sections(item, "sections")
            )

            content_sw = clean_text(
                item.get("contentSw")
                or item.get("content_sw")
                or extract_sections(item, "sectionsSw")
            )

            if lang == "sw":
                main_content = content_sw
                secondary_content = content_en
            else:
                main_content = content_en
                secondary_content = content_sw

            if len(main_content) < min_chars and len(secondary_content) < min_chars:
                skipped.append((item_id, "content too short"))
                continue

            # For Swahili, keep English title too because many medical terms in the corpus remain English.
            # For E5, documents/passages use "passage:" prefix.
            if bilingual:
                doc_text = f"passage: {title}. {main_content}. English reference: {title}. {secondary_content}"
            else:
                doc_text = f"passage: {title}. {main_content}"

            items.append({
                "id": item_id,
                "title": title,
                "source_file": file_path.name,
                "text": clean_text(doc_text),
                "lang": lang,
            })

    return items, skipped


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
    parser.add_argument("--lang", choices=["en", "sw"], required=True)
    parser.add_argument("--corpus-glob", required=True)
    parser.add_argument("--index-out", required=True)
    parser.add_argument("--meta-out", required=True)
    parser.add_argument("--skipped-out", default=None)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--max-len", type=int, default=512)
    parser.add_argument("--min-chars", type=int, default=80)
    parser.add_argument("--no-bilingual", action="store_true")
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Loading model: {MODEL_ID}")
    print(f"Device: {device}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval()
    model.to(device)

    save_dir = Path("assets/models_e5small")
    save_dir.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(save_dir)
    model.config.save_pretrained(save_dir)

    items, skipped = load_items(
        args.corpus_glob,
        lang=args.lang,
        min_chars=args.min_chars,
        bilingual=not args.no_bilingual,
    )

    print(f"Loaded clean items: {len(items)}")
    print(f"Skipped items/files: {len(skipped)}")

    if not items:
        raise RuntimeError("No clean corpus items loaded. Check corpus path/filtering.")

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
            "lang": item["lang"],
            "model": MODEL_ID,
            "vector_dim": int(vectors.shape[1]),
        }
        for item in items
    ]

    Path(args.meta_out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.meta_out).write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    skipped_out = Path(args.skipped_out) if args.skipped_out else Path(args.meta_out).with_name("skipped_items.json")
    skipped_out.write_text(json.dumps(skipped, indent=2, ensure_ascii=False), encoding="utf-8")

    print("\nDone.")
    print(f"Index: {args.index_out}")
    print(f"Meta: {args.meta_out}")
    print(f"Skipped report: {skipped_out}")
    print(f"Shape: {vectors.shape}")


if __name__ == "__main__":
    main()
