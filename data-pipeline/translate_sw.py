# translate_sw.py
# Purpose: Add Swahili translations to the JSON produced by extract_chunks.py.
# It only fills content_sw when it's missing, and marks translation_status="machine".
# Run:
#   python translate_sw.py

import json
from pathlib import Path
from argostranslate import translate

ROOT = Path(__file__).parent
IN_PATH  = ROOT / "en_chunks.json"
OUT_PATH = ROOT / "en_sw_chunks.json"
BATCH_LIMIT = None  # e.g., 200 for testing small batches; None = translate all

def get_engine(from_code="en", to_code="sw"):
    langs = translate.get_installed_languages()
    try:
        from_lang = next(l for l in langs if l.code == from_code)
        to_lang   = next(l for l in langs if l.code == to_code)
    except StopIteration:
        raise RuntimeError(
            f"Missing Argos model for {from_code}->{to_code}. "
            "Install the .argosmodel files, then rerun."
        )
    return from_lang.get_translation(to_lang)

def main():
    assert IN_PATH.exists(), f"Input JSON not found: {IN_PATH.resolve()}"
    data = json.loads(IN_PATH.read_text(encoding="utf-8"))
    engine = get_engine("en", "sw")

    count = 0
    for item in data:
        if item.get("content_sw"):  # already has Swahili (human or prior machine)
            continue
        text = item.get("content_en")
        if not text:
            continue
        # Optional safety: limit very long strings (Argos can handle, but keep it tidy)
        text = text[:3000]
        item["content_sw"] = engine.translate(text)
        # Set status only if it was 'original' (keep 'human' if you pre-filled any)
        if item.get("translation_status") == "original":
            item["translation_status"] = "machine"
        count += 1
        if BATCH_LIMIT and count >= BATCH_LIMIT:
            break

    OUT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Translated {count} items → {OUT_PATH.resolve()}")

if __name__ == "__main__":
    main()
