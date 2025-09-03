# extract_curated_v2.py
# Curated, structure-aware extractor for:
#  - Principles (pp. 10–21): one numbered principle per item
#  - Most Important Herbs (pp. 43–62): one herb per item
#  - Diseases & Remedies (pp. 180 → end): one condition per item with subsections
#
# Outputs:
#   structured_extracted.json
#   en_chunks_curated.json
#
# Run (from data-pipeline, with venv python):
#   python extract_curated_v2.py

from __future__ import annotations
import re, json, textwrap
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Tuple, Optional
from pathlib import Path
import pdfplumber

ROOT = Path(__file__).parent
PDF_PATH = ROOT / "NaturalRemediesEncyclopedia.pdf"
OUT_STRUCT = ROOT / "structured_extracted.json"
OUT_CHUNKS = ROOT / "en_chunks_curated.json"

# ------------------------------ CONFIG ------------------------------
# Book page numbers (inclusive). Adjust if PDF indexing is offset.
PRINCIPLES_PAGES = (10, 21)
HERBS_PAGES      = (43, 62)
DISEASES_PAGES   = (180, None)   # None = to last page

MIN_PAR_LEN  = 80      # very short snippets are dropped
WRAP_WIDTH   = 6000    # we keep paragraphs intact; shorten later if needed
SOURCE_NAME  = "Natural Remedies Encyclopedia (PDF)"
# -------------------------------------------------------------------

# Subsection labels we want to split on inside disease/herb sections
SUB_KEYS = [
    "SYMPTOMS", "CAUSES", "TREATMENT", "TREATMENTS", "REMEDIES",
    "DIET", "HYDROTHERAPY", "USES", "PREPARATION", "PREPARATIONS",
    "CAUTIONS", "WARNING", "NOTES", "OVERVIEW", "PREVENTION", "PROGNOSIS"
]
SUB_RE = re.compile(rf"^\s*({'|'.join(map(re.escape, SUB_KEYS))})\s*[:\-–—]?\s*$", re.I)

# Helpers to avoid false headings like "SECTION", "PART", etc.
NOISE_HEAD_RE = re.compile(r"^(SECTION|PART|CHAPTER|BASIC PRINCIPLES|THE MOST IMPORTANT HERBS)\b", re.I)

def clean_text(s: str) -> str:
    if not s: return ""
    s = s.replace("\u00ad", "")         # soft hyphen
    s = s.replace("-\n", "")            # hyphenated break
    s = s.replace("•", "• ")            # normalize bullets
    s = re.sub(r"[ \t]+\n", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    s = re.sub(r"[ \t]{2,}", " ", s)
    return s.strip()

def get_page_span(pdf: pdfplumber.PDF, span: Tuple[int, Optional[int]]) -> Tuple[int, int]:
    start, end = span
    n = len(pdf.pages)
    end = n if end is None else end
    start = max(1, start); end = min(n, end)
    return (start-1, end-1)  # zero-based inclusive

def page_text(pdf: pdfplumber.PDF, idx: int) -> str:
    page = pdf.pages[idx]
    txt = page.extract_text() or ""
    if not txt.strip():
        txt = page.extract_text(x_tolerance=1.5) or ""
    return clean_text(txt)

def collect_text(pdf, zspan: Tuple[int,int]) -> str:
    s, e = zspan
    return clean_text("\n\n".join(page_text(pdf, i) for i in range(s, e+1)))

def is_all_caps_heading(line: str) -> bool:
    t = line.strip()
    if not t or len(t) > 120: return False
    if NOISE_HEAD_RE.match(t): return False
    letters = re.sub(r"[^A-Za-z]", "", t)
    if len(letters) < 4: return False
    caps = sum(c.isupper() for c in letters)
    return caps / max(1, len(letters)) > 0.80

def normalize_bullets(block: str) -> str:
    # Convert • bullets to "- " lines; keep numbering like "1 -" intact.
    lines = []
    for ln in block.splitlines():
        l = ln.strip()
        if l.startswith("•"):
            l = "- " + l.lstrip("•").strip()
        lines.append(l)
    return "\n".join(lines)

# ------------------------------ DATA MODEL ------------------------------
@dataclass
class Item:
    id: str
    type: str                 # 'principle' | 'herb' | 'condition'
    title: str
    fields: Dict[str, str] = field(default_factory=dict)
    page_range: Tuple[int,int] = (0,0)
    source: str = SOURCE_NAME

def item_to_chunks(it: Item) -> List[Dict]:
    base = {
        "source": it.source,
        "page_range": list(it.page_range),
        "lang_original": "en",
        "translation_status": "original",
        "tags": [it.type],
        "section": it.type
    }
    chunks = []
    # Overview first if present
    if it.fields.get("overview"):
        chunks.append({
            "id": f"{it.type}:{it.title}#overview",
            "type": "chunk",
            "title": f"{it.title} — Overview",
            "facet": "overview",
            "content_en": it.fields["overview"],
            **base
        })
    # Then every other field
    for k, v in it.fields.items():
        if k == "overview" or not v: continue
        chunks.append({
            "id": f"{it.type}:{it.title}#{k.lower()}",
            "type": "chunk",
            "title": f"{it.title} — {k.capitalize()}",
            "facet": k.lower(),
            "content_en": v,
            **base
        })
    # Length filter & gentle shorten
    filtered = []
    seen = set()
    for c in chunks:
        txt = (c.get("content_en") or "").strip()
        if len(txt) < MIN_PAR_LEN: 
            continue
        if c["id"] in seen: 
            continue
        seen.add(c["id"])
        c["content_en"] = textwrap.shorten(txt, width=WRAP_WIDTH, placeholder=" …")
        filtered.append(c)
    return filtered

# ------------------------------ PARSERS ------------------------------
def parse_principles(text: str, human_pages: Tuple[int,int]) -> List[Item]:
    """
    Look for numbered lines like:
      1 - Regularity in meals. ...
      2 - Moderation. ...
    Capture each list item (including wrapped lines).
    """
    items: List[Item] = []

    # Keep only the block starting at "BASIC PRINCIPLES OF HEALTH" if present
    anchor = re.search(r"BASIC PRINCIPLES OF HEALTH", text, re.I)
    if anchor:
        text = text[anchor.start():]

    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    cur_num, cur_buf = None, []

    num_pat = re.compile(r"^(\d{1,3})\s*[-–—]\s*(.+)$")

    def flush():
        nonlocal cur_num, cur_buf
        if cur_num is None or not cur_buf: 
            return
        block = normalize_bullets("\n".join(cur_buf)).strip()
        # Title: first sentence (short)
        title = re.split(r"[.!?]", block, 1)[0].strip()
        items.append(Item(
            id=f"principle:{cur_num}",
            type="principle",
            title=title,
            fields={"overview": block},
            page_range=human_pages
        ))
        cur_num, cur_buf = None, []

    for ln in lines:
        m = num_pat.match(ln)
        if m:
            flush()
            cur_num = m.group(1)
            cur_buf = [m.group(2)]
        else:
            if cur_num is not None:
                cur_buf.append(ln)
    flush()
    return items

def parse_herbs(text: str, human_pages: Tuple[int,int]) -> List[Item]:
    """
    Herbs appear as enumerated entries like:
      1 - CHARCOAL—This is not an herb, yet...
      2 - CAYENNE—Dr. Christopher...
    We treat the all-caps token before the em-dash as the herb name.
    """
    items: List[Item] = []
    # Move to the "THE MOST IMPORTANT HERBS" anchor if present
    anchor = re.search(r"THE MOST IMPORTANT HERBS", text, re.I)
    if anchor:
        text = text[anchor.start():]

    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    entry_pat = re.compile(r"^(\d{1,3})\s*[-–—]\s*([A-Z][A-Z \-'/()]+?)\s*[—\-–]\s*(.*)$")
    cur_name, cur_buf = None, []

    def flush():
        nonlocal cur_name, cur_buf
        if not cur_name or not cur_buf: 
            return
        block = normalize_bullets("\n".join(cur_buf)).strip()
        # Split by simple cues if present
        subs: Dict[str,str] = {}
        # Greedy subsection slicing
        segs = []
        buf, label = [], "overview"
        for raw in block.splitlines():
            m = SUB_RE.match(raw.strip())
            if m:
                if buf:
                    segs.append((label.lower(), "\n".join(buf).strip()))
                label = m.group(1).upper()
                buf = []
            else:
                buf.append(raw)
        if buf:
            segs.append((label.lower(), "\n".join(buf).strip()))
        for k,v in segs:
            k = {"preparations":"preparation","treatments":"treatment","remedies":"treatment"}.get(k,k)
            if k in subs: subs[k] = subs[k] + "\n\n" + v
            else: subs[k] = v
        # Ensure common fields exist
        fields = {
            "overview": subs.pop("overview","") or block,
            "uses": subs.pop("uses",""),
            "preparation": subs.pop("preparation",""),
            "safety": subs.pop("cautions","") or subs.pop("warning",""),
        }
        fields.update(subs)  # keep extras (diet, notes, etc.)
        items.append(Item(
            id=f"herb:{cur_name.title()}",
            type="herb",
            title=cur_name.title(),
            fields=fields,
            page_range=human_pages
        ))
        cur_name, cur_buf = None, []

    for ln in lines:
        m = entry_pat.match(ln)
        if m:
            flush()
            cur_name = m.group(2).strip(" -")
            first = m.group(3).strip()
            cur_buf = [first] if first else []
        else:
            if cur_name:
                cur_buf.append(ln)
    flush()
    return items

def parse_conditions(text: str, human_pages: Tuple[int,int]) -> List[Item]:
    """
    Conditions look like:
      DEBILITY (Weak, Debilitated Conditions)
      SYMPTOMS—...
      CAUSES—...
      TREATMENT—...
    """
    items: List[Item] = []
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    cur_title, cur_sections = None, {}  # label -> text buf
    cur_label = "overview"
    buf: List[str] = []

    def flush_condition():
        nonlocal cur_title, cur_sections, buf, cur_label
        if not cur_title: 
            return
        if buf:
            cur_sections.setdefault(cur_label, []).append("\n".join(buf).strip())
        # Merge sections
        fields: Dict[str,str] = {}
        for k, chunks in cur_sections.items():
            fields[k] = normalize_bullets("\n\n".join(x for x in chunks if x).strip())
        # Normalize keys
        norm_fields = {
            "overview": fields.get("overview",""),
            "symptoms": fields.get("symptoms",""),
            "causes": fields.get("causes",""),
            "treatment": fields.get("treatment","") or fields.get("remedies",""),
            "diet": fields.get("diet",""),
            "hydrotherapy": fields.get("hydrotherapy",""),
            "notes": fields.get("notes",""),
        }
        # Keep any extras
        for k,v in fields.items():
            k2 = {"treatments":"treatment","remedies":"treatment"}.get(k,k)
            if k2 not in norm_fields or not norm_fields[k2]:
                norm_fields[k2] = v
        items.append(Item(
            id=f"condition:{cur_title.title()}",
            type="condition",
            title=cur_title.title(),
            fields=norm_fields,
            page_range=human_pages
        ))
        # reset
        cur_title, cur_sections, cur_label, buf = None, {}, "overview", []

    for ln in lines:
        # New condition?
        if is_all_caps_heading(ln):
            # avoid section/part noise
            if NOISE_HEAD_RE.match(ln): 
                continue
            flush_condition()
            cur_title = re.sub(r"\s+", " ", ln)
            cur_sections, cur_label, buf = {}, "overview", []
            continue
        # New subsection?
        m = SUB_RE.match(ln)
        if m and cur_title:
            if buf:
                cur_sections.setdefault(cur_label, []).append("\n".join(buf).strip())
            lbl = m.group(1).upper()
            lbl = {"TREATMENTS":"TREATMENT","REMEDIES":"TREATMENT","PREPARATIONS":"PREPARATION"}.get(lbl, lbl)
            cur_label = lbl.lower()
            buf = []
            continue
        # Normal content line
        if cur_title:
            buf.append(ln)

    flush_condition()
    return items

# ------------------------------ MAIN ------------------------------
def main():
    assert PDF_PATH.exists(), f"PDF not found: {PDF_PATH}"

    with pdfplumber.open(str(PDF_PATH)) as pdf:
        p_span = get_page_span(pdf, PRINCIPLES_PAGES)
        h_span = get_page_span(pdf, HERBS_PAGES)
        d_span = get_page_span(pdf, DISEASES_PAGES)

        print("Extracting Principles:", p_span[0]+1, "→", p_span[1]+1)
        principles_txt = collect_text(pdf, p_span)
        principles = parse_principles(principles_txt, (p_span[0]+1, p_span[1]+1))

        print("Extracting Herbs:", h_span[0]+1, "→", h_span[1]+1)
        herbs_txt = collect_text(pdf, h_span)
        herbs = parse_herbs(herbs_txt, (h_span[0]+1, h_span[1]+1))

        print("Extracting Conditions:", d_span[0]+1, "→", d_span[1]+1)
        cond_txt = collect_text(pdf, d_span)
        conditions = parse_conditions(cond_txt, (d_span[0]+1, d_span[1]+1))

    items: List[Item] = [*principles, *herbs, *conditions]

    # Write hierarchical
    structured = [asdict(it) for it in items if any(it.fields.values())]
    OUT_STRUCT.write_text(json.dumps(structured, ensure_ascii=False, indent=2), encoding="utf-8")

    # Write chunks
    chunks: List[Dict] = []
    for it in items:
        chunks.extend(item_to_chunks(it))

    # Dedup by id, enforce min length
    seen, curated = set(), []
    for c in chunks:
        txt = (c.get("content_en") or "").strip()
        if len(txt) < MIN_PAR_LEN: 
            continue
        if c["id"] in seen: 
            continue
        seen.add(c["id"])
        curated.append(c)

    OUT_CHUNKS.write_text(json.dumps(curated, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Wrote {len(structured)} items → {OUT_STRUCT}")
    print(f"Wrote {len(curated)} curated chunks → {OUT_CHUNKS}")

if __name__ == "__main__":
    main()
