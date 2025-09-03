# translate_en_hf.py
from pathlib import Path
import json
from typing import List
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, pipeline

ROOT = Path(__file__).parent
IN_PATH  = ROOT / "en_sw_chunks.json"
OUT_PATH = ROOT / "sw_en_qacheck.json"
MODEL_DIR = ROOT / "models" / "Rogendo" / "sw-en"

MAX_LEN = 192
BATCH = 16

def load_pipe():
    tok = AutoTokenizer.from_pretrained(MODEL_DIR, local_files_only=True)
    mdl = AutoModelForSeq2SeqLM.from_pretrained(MODEL_DIR, local_files_only=True)
    return pipeline("text2text-generation", model=mdl, tokenizer=tok, device=-1, framework="pt")

def batched(xs: List[str], n: int):
    for i in range(0, len(xs), n):
        yield xs[i:i+n]

def main():
    data = json.loads(IN_PATH.read_text(encoding="utf-8"))
    pipe = load_pipe()

    # translate back a small sample for spot-checking quality
    sample = [it["content_sw"] for it in data[:50] if it.get("content_sw")]
    outs = []
    for chunk in batched(sample, BATCH):
        outs.extend(o["generated_text"] for o in pipe(chunk, max_length=MAX_LEN, num_beams=4))

    Path(OUT_PATH).write_text(json.dumps(outs, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(outs)} back-translations for QA → {OUT_PATH}")

if __name__ == "__main__":
    main()
