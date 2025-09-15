# utils_extract.py
import re, json, unicodedata
from pathlib import Path

EMDASH = "—"

def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-")
    return re.sub(r"-+", "-", s).lower()

def clean_lines(text: str) -> list[str]:
    # normalize dashes, collapse weird spacing, drop empty tails
    text = text.replace("\u2014", EMDASH).replace("\u2013", "-")
    text = re.sub(r"[ \t]+", " ", text)
    lines = [ln.strip() for ln in text.splitlines()]
    return [ln for ln in lines if ln.strip()]

def join_paragraphs(lines: list[str]) -> str:
    # remove page headers/footers heuristically (short lines with page numbers)
    filtered = []
    for ln in lines:
        if re.fullmatch(r"\d{1,3}", ln):           # bare page number
            continue
        if re.match(r"^\s*\w+\s*\d{1,3}\s*$", ln):  # "Chapter 12  123"
            continue
        filtered.append(ln)
    # de-hyphenation across line breaks
    merged = []
    for ln in filtered:
        if merged and re.search(r"[A-Za-z]-$", merged[-1]) and re.match(r"^[a-z]", ln):
            merged[-1] = merged[-1][:-1] + ln       # glue hyphen break
        else:
            merged.append(ln)
    # paragraph join: keep list bullets as separate lines
    out = []
    buf = []
    for ln in merged:
        if re.match(r"^[•\-\u2022]\s", ln):
            if buf:
                out.append(" ".join(buf)); buf = []
            out.append(ln)
        else:
            buf.append(ln)
    if buf: out.append(" ".join(buf))
    return "\n".join(out)

def write_items(items, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    # Only include keys your app expects
    payload = [{"id": it["id"], "title": it["title"], "contentEn": it["contentEn"], "contentSw": None} for it in items]
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

def looks_like_header(line: str) -> bool:
    # ALL CAPS or Title Case short; avoid obvious non-headers
    if len(line) < 3 or len(line) > 60: return False
    if re.search(r"[.:]$", line): return False
    caps_ratio = sum(c.isupper() for c in line if c.isalpha()) / max(1, sum(c.isalpha() for c in line))
    return caps_ratio > 0.7 or line.istitle()
