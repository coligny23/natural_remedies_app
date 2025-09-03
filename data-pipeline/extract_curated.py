# extract_curated.py
# Curated extractor for Natural Remedies Encyclopedia:
# - Principles (pp. 10–21)
# - Most Important Herbs (pp. 43–62)
# - Diseases & Remedies (pp. 180 → end)
#
# Produces:
#   structured_extracted.json  (hierarchical, per item)
#   en_chunks_curated.json     (flat chunks for retrieval/translation)
#
# Requires: pdfplumber (with matching pdfminer.six), Pillow

from __future__ import annotations
import re, json, textwrap
from dataclasses import dataclass, asdict, field
from typing import List, Dict, Tuple
from pathlib import Path
import pdfplumber

ROOT = Path(__file__).parent
PDF_PATH = ROOT / "NaturalRemediesEncyclopedia.pdf"   # ensure this filename
OUT_STRUCT = ROOT / "structured_extracted.json"
OUT_CHUNKS = ROOT / "en_chunks_curated.json"

# ------------------------------
# CONFIGURE PAGE RANGES (1-based page numbers as per the book)
# Adjust if your PDF has front-matter that shifts numbering.
# These are inclusive, human-counted pages. We'll translate to zero-based indices.
PRINCIPLES_PAGES = (10, 21)
HERBS_PAGES      = (43, 62)
DISEASES_PAGES   = (180, None)   # None means go to last page
# ------------------------------

MIN_PAR_LEN   = 120      # filter very short lines
WRAP_WIDTH    = 800      # large to avoid over-fragmentation
HEADING_MAX   = 80
SOURCE_NAME   = "Natural Remedies Encyclopedia (PDF)"

# Recognize common subsection keywords (flexible punctuation)
SUBSECTION_KEYS = [
    "SYMPTOMS", "CAUSES", "TREATMENT", "TREATMENTS", "REMEDIES", "DIET",
    "HYDROTHERAPY", "HERBS", "USES", "PREPARATION", "PREPARATIONS",
    "HOW TO USE", "CAUTIONS", "WARNING", "PREVENTION", "PROGNOSIS",
    "NOTES", "OVERVIEW"
]
SUB_RE = re.compile(rf"^\s*({'|'.join(map(re.escape, SUBSECTION_KEYS))})\s*[:\-–—]?\s*$", re.I)

def to_zero_based_span(pdf: pdfplumber.PDF, human_span: Tuple[int,int|None]) -> Tuple[int,int]:
    start, end = human_span
    n_pages = len(pdf.pages)
    if end is None: end = n_pages
    # clamp
    start = max(1, start); end = min(n_pages, end)
    # to zero-based inclusive
    return (start-1, end-1)

def clean_text(s: str) -> str:
    if not s: return ""
    s = s.replace("\u00ad", "")               # soft hyphen
    s = s.replace("-\n", "")                  # hyphen wrapped
    s = re.sub(r"[ \t]+\n", "\n", s)          # strip trailing spaces
    s = re.sub(r"\s+\n\s+", "\n", s)          # compact
    s = re.sub(r"\n{2,}", "\n\n", s)          # max one blank line
    s = re.sub(r"[ \t]{2,}", " ", s)          # multi-space → single
    return s.strip()

def likely_heading(line: str) -> bool:
    line = line.strip()
    if not line or len(line) > HEADING_MAX: return False
    # Heuristics: ALL CAPS words, Title-Case short, or ends with ":" alone.
    letters = re.sub(r"[^A-Za-z]", "", line)
    if len(letters) < 3: return False
    # All caps ratio
    caps = sum(1 for c in letters if c.isupper())
    ratio = caps / max(1, len(letters))
    if ratio > 0.85: return True
    # Title-like, few words, no trailing punctuation
    if len(line.split()) <= 6 and not line.endswith("."):
        # avoid false positives like "Part 2" or "Section 5"
        if not re.match(r"^(Part|Section|Chapter)\b", line, re.I):
            return True
    return False

def split_paragraphs(block: str) -> List[str]:
    # Prefer blank-line split; fallback to sentence split
    if "\n\n" in block:
        parts = re.split(r"\n\s*\n", block)
    else:
        parts = re.split(r"(?<=[.!?])\s+(?=[A-Z])", block)
    return [p.strip() for p in parts if p and len(p.strip()) >= MIN_PAR_LEN]

def page_text(pdf, idx: int) -> str:
    page = pdf.pages[idx]
    txt = page.extract_text() or ""
    # Sometimes better with smaller x_tolerance
    if not txt.strip():
        txt = page.extract_text(x_tolerance=1.5) or ""
    return clean_text(txt)

def collect_text(pdf, zspan: Tuple[int,int]) -> Tuple[str, Dict[int,str]]:
    s, e = zspan
    per_page = {}
    all_txt = []
    for i in range(s, e+1):
        t = page_text(pdf, i)
        per_page[i+1] = t      # store 1-based page for reference
        all_txt.append(t)
    return ("\n\n".join(all_txt), per_page)

@dataclass
class Item:
    id: str
    type: str             # 'principle' | 'herb' | 'condition'
    title: str
    fields: Dict[str,str] = field(default_factory=dict)
    page_range: Tuple[int,int] = (0,0)
    source: str = SOURCE_NAME

def segment_by_headings(text: str) -> List[Tuple[str, str]]:
    """Return list of (heading, body) within a section using heading heuristics."""
    lines = [ln.strip() for ln in text.splitlines()]
    pairs: List[Tuple[str,str]] = []
    curr_head, curr_buf = None, []
    for ln in lines:
        if likely_heading(ln):
            if curr_head and curr_buf:
                pairs.append((curr_head, clean_text("\n".join(curr_buf))))
            curr_head, curr_buf = ln, []
        else:
            curr_buf.append(ln)
    if curr_head and curr_buf:
        pairs.append((curr_head, clean_text("\n".join(curr_buf))))
    return pairs

def split_subsections(body: str) -> Dict[str,str]:
    """Split a body into labeled subsections by keywords; preserve an 'overview'."""
    blocks = []
    buf, current = [], "overview"
    for ln in body.splitlines():
        if SUB_RE.match(ln.strip()):
            # start new block
            if buf:
                blocks.append((current.lower(), clean_text("\n".join(buf))))
            current = SUB_RE.match(ln.strip()).group(1).upper()
            buf = []
        else:
            buf.append(ln)
    if buf:
        blocks.append((current.lower(), clean_text("\n".join(buf))))
    # Merge by key
    out: Dict[str,str] = {}
    for k,v in blocks:
        k = {"treatments":"treatment","remedies":"treatment","preparations":"preparation"}.get(k,k)
        if k in out:
            out[k] = out[k] + "\n\n" + v
        else:
            out[k] = v
    return out

def item_to_chunks(it: Item) -> List[Dict]:
    chunks = []
    base = {
        "source": it.source,
        "page_range": list(it.page_range),
        "lang_original": "en",
        "translation_status": "original",
        "tags": [it.type]
    }
    # primary overview chunk
    if it.fields.get("overview"):
        chunks.append({
            "id": f"{it.type}:{it.title}#overview",
            "type": "chunk",
            "title": f"{it.title} — Overview",
            "section": it.type,
            "facet": "overview",
            "content_en": it.fields["overview"],
            **base
        })
    # subsection chunks
    for k, v in it.fields.items():
        if k == "overview" or not v: continue
        chunks.append({
            "id": f"{it.type}:{it.title}#{k}",
            "type": "chunk",
            "title": f"{it.title} — {k.capitalize()}",
            "section": it.type,
            "facet": k.lower(),
            "content_en": v,
            **base
        })
    return chunks

def extract_principles(pdf, zspan: Tuple[int,int]) -> List[Item]:
    text, _ = collect_text(pdf, zspan)
    # Segment by headings; treat each heading paragraph as one 'principle'
    items: List[Item] = []
    for head, body in segment_by_headings(text):
        fields = {"overview": body}
        items.append(Item(
            id=f"principle:{head}",
            type="principle",
            title=head,
            fields=fields,
            page_range=(zspan[0]+1, zspan[1]+1)
        ))
    return items

def extract_herbs(pdf, zspan: Tuple[int,int]) -> List[Item]:
    text, _ = collect_text(pdf, zspan)
    items: List[Item] = []
    for head, body in segment_by_headings(text):
        subs = split_subsections(body)
        # Map to friendly herb fields
        fields = {
            "overview": subs.pop("overview", ""),
            "uses": subs.pop("uses", ""),
            "preparation": subs.pop("preparation", ""),
            "safety": subs.pop("cautions", "") or subs.pop("warning",""),
        }
        # keep any extras (diet, hydrotherapy, notes)
        fields.update(subs)
        items.append(Item(
            id=f"herb:{head}",
            type="herb",
            title=head.title(),
            fields=fields,
            page_range=(zspan[0]+1, zspan[1]+1)
        ))
    return items

def extract_diseases(pdf, zspan: Tuple[int,int]) -> List[Item]:
    text, _ = collect_text(pdf, zspan)
    items: List[Item] = []
    for head, body in segment_by_headings(text):
        subs = split_subsections(body)
        # Normalize keys for disease schema
        fields = {
            "overview": subs.pop("overview", ""),
            "symptoms": subs.pop("symptoms", ""),
            "causes": subs.pop("causes", ""),
            "treatment": subs.pop("treatment", "") or subs.pop("remedies",""),
            "diet": subs.pop("diet", ""),
            "hydrotherapy": subs.pop("hydrotherapy", ""),
            "notes": subs.pop("notes", "")
        }
        fields.update(subs)  # keep anything else
        items.append(Item(
            id=f"condition:{head}",
            type="condition",
            title=head.title(),
            fields=fields,
            page_range=(zspan[0]+1, zspan[1]+1)
        ))
    return items

def main():
    assert PDF_PATH.exists(), f"PDF not found: {PDF_PATH}"
    items: List[Item] = []
    with pdfplumber.open(str(PDF_PATH)) as pdf:
        p_span = to_zero_based_span(pdf, PRINCIPLES_PAGES)
        h_span = to_zero_based_span(pdf, HERBS_PAGES)
        d_span = to_zero_based_span(pdf, DISEASES_PAGES)

        print("Extracting PRINCIPLES pages:", p_span[0]+1, "to", p_span[1]+1)
        items.extend(extract_principles(pdf, p_span))

        print("Extracting HERBS pages:", h_span[0]+1, "to", h_span[1]+1)
        items.extend(extract_herbs(pdf, h_span))

        print("Extracting DISEASES pages:", d_span[0]+1, "to", d_span[1]+1)
        items.extend(extract_diseases(pdf, d_span))

    # Write structured
    struct = [asdict(it) for it in items if any(it.fields.values())]
    OUT_STRUCT.write_text(json.dumps(struct, ensure_ascii=False, indent=2), encoding="utf-8")

    # Write flat chunks
    chunks: List[Dict] = []
    for it in items:
        chunks.extend(item_to_chunks(it))

    # Filter overly short chunks and dedupe
    seen_ids = set()
    filtered = []
    for c in chunks:
        if len((c.get("content_en") or "").strip()) < MIN_PAR_LEN: 
            continue
        if c["id"] in seen_ids: 
            continue
        seen_ids.add(c["id"])
        # Soft wrap to reduce extreme lengths
        c["content_en"] = textwrap.shorten(c["content_en"], width=5000, placeholder=" …")
        filtered.append(c)

    OUT_CHUNKS.write_text(json.dumps(filtered, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(struct)} items → {OUT_STRUCT}")
    print(f"Wrote {len(filtered)} curated chunks → {OUT_CHUNKS}")

if __name__ == "__main__":
    main()
