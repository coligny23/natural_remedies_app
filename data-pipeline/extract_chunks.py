# extract_chunks.py
# Purpose: Convert the Natural Remedies PDF into JSON "chunks" suitable for the app.
# Run inside your venv:
#   python extract_chunks.py

import json, re, textwrap
from pathlib import Path
import pdfplumber

# Resolve paths relative to THIS file's folder (no backslash escaping needed)
ROOT = Path(__file__).parent
PDF_PATH = ROOT / "NaturalRemediesEncyclopedia.pdf"   # your local copy
OUT_PATH = ROOT / "en_chunks.json"
MIN_PARA_LEN = 160
CHUNK_WIDTH = 600
SOURCE_NAME = "Natural Remedies Encyclopedia (PDF)"
# ----------------------------------------------------------------------------

def clean(s: str) -> str:
    return re.sub(r"\s+", " ", s or "").strip()

def looks_like_heading(line: str) -> bool:
    """Very simple heading detector: mostly uppercase, not too long."""
    l = line.strip()
    if len(l) < 4 or len(l) > 80: 
        return False
    # treat lines with many capitals as headings (tune as needed)
    letters = re.sub(r"[^A-Za-z]", "", l)
    if not letters:
        return False
    uppercase_ratio = sum(c.isupper() for c in letters) / len(letters)
    return uppercase_ratio > 0.8

def split_paragraphs(page_text: str):
    # prefer blank lines; otherwise split at sentence boundaries followed by capital
    if "\n\n" in page_text:
        raw = re.split(r"\n\s*\n", page_text)
    else:
        raw = re.split(r"(?<=\.)\s+(?=[A-Z])", page_text)
    return [clean(p) for p in raw if clean(p)]

def main():
    assert PDF_PATH.exists(), f"PDF not found: {PDF_PATH.resolve()}"
    items = []
    current_section = "General"

    with pdfplumber.open(PDF_PATH) as pdf:
        for pageno, page in enumerate(pdf.pages, start=1):
            text = page.extract_text() or ""
            if not text.strip():
                continue

            # Keep original line breaks for heading detection
            lines = [clean(l) for l in text.splitlines() if clean(l)]
            # Mark headings we see on the page
            for ln in lines[:5]:  # headings tend to be near the top
                if looks_like_heading(ln):
                    current_section = ln.title()
                    break

            # Recompose paragraphs and chunk
            paragraphs = split_paragraphs(text)
            for para in paragraphs:
                if len(para) < MIN_PARA_LEN:
                    continue
                for chunk in textwrap.wrap(
                    para,
                    width=CHUNK_WIDTH,
                    replace_whitespace=False,
                    break_long_words=False,
                    break_on_hyphens=False,
                ):
                    items.append({
                        "id": f"p{pageno}-{len(items):06d}",
                        "type": "chunk",
                        "title": current_section,
                        "section": "Body",
                        "content_en": chunk,
                        "content_sw": None,
                        "lang_original": "en",
                        "translation_status": "original",
                        "tags": [],
                        "source": SOURCE_NAME,
                        "page_range": [pageno, pageno],
                    })

    OUT_PATH.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(items)} chunks → {OUT_PATH.resolve()}")

if __name__ == "__main__":
    main()
