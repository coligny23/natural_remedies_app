from pathlib import Path
import re, pdfplumber
from utils_extract import clean_lines, join_paragraphs, looks_like_header, slugify, write_items

PDF = Path("NaturalRemediesEncyclopedia.pdf")
OUT = Path("../assets/corpus/en/herbs.json")

START_PAGE = 43
END_PAGE   = 62

HEADER_RE = re.compile(r"^[A-Z][A-Za-z\s\-']{2,}$")  # simple herb name line

def main():
    with pdfplumber.open(PDF) as pdf:
        pages = [pdf.pages[i-1] for i in range(START_PAGE, END_PAGE+1) if 0 <= i-1 < len(pdf.pages)]
        text = "\n".join(p.extract_text(x_tolerance=2, y_tolerance=2) or "" for p in pages)

    lines = clean_lines(text)

    items = []
    cur_title = None
    cur_chunks = []

    def flush():
        nonlocal cur_title, cur_chunks
        if cur_title and cur_chunks:
            content = join_paragraphs(cur_chunks)
            items.append({
                "id": f"herb-{slugify(cur_title)}",
                "title": cur_title,
                "contentEn": content
            })
        cur_title, cur_chunks = None, []

    for ln in lines:
        if HEADER_RE.match(ln) and looks_like_header(ln):
            flush()
            cur_title = ln.strip().title()
            continue
        if cur_title:
            cur_chunks.append(ln)

    flush()
    write_items(items, OUT)
    print(f"Wrote {len(items)} herbs → {OUT}")

if __name__ == "__main__":
    main()
