#!/usr/bin/env python3
"""
build_e5small_index_with_aliases.py

Builds an E5 multilingual embedding index using titleSw and aliasesSw fields.

Recommended CMD:
python tools\build_e5small_index_with_aliases.py --lang sw --corpus-glob assets/corpus/sw_aliases/*.json --index-out assets\embeddings_e5small\index_sw_aliases.bin --meta-out assets\embeddings_e5small\meta_sw_aliases.json
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
SKIP_FILENAMES = {"sw_import.json", "synonyms.json", "enrichment_summary.json"}
SKIP_IDS = {"principle-section-0"}
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


def load_items(corpus_glob, lang="sw", min_chars=80):
    items = []
    skipped = []

    for path in sorted(glob.glob(corpus_glob)):
        file_path = Path(path)

        if file_path.name in SKIP_FILENAMES or file_path.suffix.lower() != ".json":
            skipped.append((file_path.name, "helper/import/non-json file"))
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
            title_sw = item.get("titleSw") or title
            aliases_sw = item.get("aliasesSw") or []

            if not item_id or not title:
                skipped.append((file_path.name, "missing id/title"))
                continue
            if item_id in SKIP_IDS:
                skipped.append((item_id, "skip-id"))
                continue
            if not VALID_ID_RE.match(item_id):
                skipped.append((item_id[:80], "malformed id"))
                continue
            if "too_short" in (item.get("missingFields") or []):
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

            if len(content_sw) < min_chars and len(content_en) < min_chars:
                skipped.append((item_id, "content too short"))
                continue

            aliases_text = "; ".join([str(a) for a in aliases_sw if str(a).strip()])

            # E5 document convention: use passage prefix.
            # The alias block is deliberately near the front because user queries are short.
            text = clean_text(
                f"passage: {title_sw}. {title}. "
                f"Search aliases: {aliases_text}. "
                f"Swahili content: {content_sw}. "
                f"English reference: {content_en}"
            )

            items.append({
                "id": item_id,
                "title": title,
                "titleSw": title_sw,
                "aliasesSw": aliases_sw,
                "source_file": file_path.name,
                "text": text,
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
    parser.add_argument("--lang", choices=["en", "sw"], default="sw")
    parser.add_argument("--corpus-glob", required=True)
    parser.add_argument("--index-out", required=True)
    parser.add_argument("--meta-out", required=True)
    parser.add_argument("--skipped-out", default=None)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--max-len", type=int, default=512)
    parser.add_argument("--min-chars", type=int, default=80)
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Loading model: {MODEL_ID}")
    print(f"Device: {device}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval().to(device)

    save_dir = Path("assets/models_e5small")
    save_dir.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(save_dir)
    model.config.save_pretrained(save_dir)

    items, skipped = load_items(args.corpus_glob, lang=args.lang, min_chars=args.min_chars)
    print(f"Loaded clean aliased items: {len(items)}")
    print(f"Skipped items/files: {len(skipped)}")

    if not items:
        raise RuntimeError("No corpus items loaded. Check corpus path/filtering.")

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
            "titleSw": item["titleSw"],
            "aliasesSw": item["aliasesSw"],
            "source_file": item["source_file"],
            "lang": item["lang"],
            "model": MODEL_ID,
            "vector_dim": int(vectors.shape[1]),
        }
        for item in items
    ]

    Path(args.meta_out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.meta_out).write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    skipped_out = Path(args.skipped_out) if args.skipped_out else Path(args.meta_out).with_name("skipped_items_aliases.json")
    skipped_out.write_text(json.dumps(skipped, indent=2, ensure_ascii=False), encoding="utf-8")

    print("\nDone.")
    print(f"Index: {args.index_out}")
    print(f"Meta: {args.meta_out}")
    print(f"Skipped report: {skipped_out}")
    print(f"Shape: {vectors.shape}")


if __name__ == "__main__":
    main()
