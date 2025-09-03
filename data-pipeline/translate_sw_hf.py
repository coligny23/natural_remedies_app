# translate_sw_hf.py
# Fills content_sw in en_chunks.json using Hugging Face Transformers models (EN→SW).
# Requires: transformers, torch (CPU), sentencepiece, huggingface_hub
# Models are cached locally under models/Rogendo/en-sw (downloaded once).

import json
from pathlib import Path
from typing import List

from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, pipeline

ROOT = Path(__file__).parent
IN_PATH  = ROOT / "en_chunks.json"          # produced by extract_chunks.py
OUT_PATH = ROOT / "en_sw_chunks.json"       # output with Swahili filled
MODEL_DIR = ROOT / "models" / "Rogendo" / "en-sw"  # local snapshot path

# Tweakables
MAX_LEN = 192       # seq length cap (keep moderate for CPU)
BATCH  = 16         # batch texts for speed

def load_pipe():
    # Load from local snapshot (offline). If you put it elsewhere, adjust path.
    tok = AutoTokenizer.from_pretrained(MODEL_DIR, local_files_only=True)
    mdl = AutoModelForSeq2SeqLM.from_pretrained(MODEL_DIR, local_files_only=True)
    return pipeline(
        "text2text-generation",
        model=mdl,
        tokenizer=tok,
        device=-1,           # CPU
        framework="pt"
    )

def batched(xs: List[str], n: int):
    for i in range(0, len(xs), n):
        yield xs[i:i+n]

def main():
    assert IN_PATH.exists(), f"Missing input: {IN_PATH}"
    data = json.loads(IN_PATH.read_text(encoding="utf-8"))

    pipe = load_pipe()

    # Collect texts needing translation
    idxs, texts = [], []
    for i, item in enumerate(data):
        if not item.get("content_sw") and item.get("content_en"):
            text = item["content_en"][:3000]  # stay sane on very long strings
            idxs.append(i)
            texts.append(text)

    print(f"Will translate {len(texts)} items EN→SW...")

    out_texts = []
    for chunk in batched(texts, BATCH):
        outs = pipe(chunk, max_length=MAX_LEN, num_beams=4)
        out_texts.extend(o[0]["generated_text"] if isinstance(o, list) else o["generated_text"] for o in outs)

    # Write results back
    for i, sw in zip(idxs, out_texts):
        data[i]["content_sw"] = sw
        if data[i].get("translation_status") == "original":
            data[i]["translation_status"] = "machine"

    OUT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Translated {len(out_texts)} items → {OUT_PATH}")

if __name__ == "__main__":
    main()
