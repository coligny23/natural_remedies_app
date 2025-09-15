from pathlib import Path
import pdfplumber
from utils_extract import clean_lines, join_paragraphs, looks_like_header, slugify, write_items

PDF = Path("NaturalRemediesEncyclopedia.pdf")  # adjust if needed
OUT = Path("../assets/corpus/en/principles.json")  # relative to data-pipeline/

START_PAGE = 10   # 1-indexed page numbers as seen in book TOC
END_PAGE   = 21

def main():
    with pdfplumber.open(PDF) as pdf:
        # convert to zero-indexed
        pages = [pdf.pages[i-1] for i in range(START_PAGE, END_PAGE+1) if 0 <= i-1 < len(pdf.pages)]
        text = "\n".join(p.extract_text(x_tolerance=2, y_tolerance=2) or "" for p in pages)

    lines = clean_lines(text)
    items = []
    cur = {"title": None, "chunks": []}

    for ln in lines:
        if looks_like_header(ln):
            # start new principle if a current one exists with some content
            if cur["title"] and cur["chunks"]:
                content = join_paragraphs(cur["chunks"])
                items.append({
                    "id": f"principle-{slugify(cur['title'])}",
                    "title": cur["title"],
                    "contentEn": content
                })
            cur = {"title": ln.title(), "chunks": []}
        else:
            cur["chunks"].append(ln)

    if cur["title"] and cur["chunks"]:
        content = join_paragraphs(cur["chunks"])
        items.append({
            "id": f"principle-{slugify(cur['title'])}",
            "title": cur["title"],
            "contentEn": content
        })

    write_items(items, OUT)
    print(f"Wrote {len(items)} principles → {OUT}")

if __name__ == "__main__":
    main()
