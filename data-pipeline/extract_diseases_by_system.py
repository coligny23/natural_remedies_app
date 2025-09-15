from pathlib import Path
import re, pdfplumber
from collections import defaultdict
from utils_extract import clean_lines, join_paragraphs, slugify, write_items

PDF = Path("NaturalRemediesEncyclopedia.pdf")
OUT_DIR = Path("../assets/corpus/en")

START_PAGE = 180
END_PAGE   = None  # to end of book

# Headings we expect inside each disease entry
SYMPT = re.compile(r"^\s*SYMPTOMS\s*[:\u2014-]?\s*$", re.IGNORECASE)
CAUSE = re.compile(r"^\s*CAUSES?\s*[:\u2014-]?\s*$", re.IGNORECASE)
TREAT = re.compile(r"^\s*TREATMENT(S)?\s*[:\u2014-]?\s*$", re.IGNORECASE)

# Disease title: line in caps or title case without trailing punctuation
TITLE_RE = re.compile(r"^[A-Z][A-Za-z0-9\s\-'/()]+$")

# Very simple classifier by keywords in title
SYSTEM_RULES = [
    ("head",         r"headache|migraine|eye|ear|nose|throat|sinus|tooth|diz(z)?iness|concussion|vision|hearing"),
    ("respiratory",  r"asthma|bronch|pneumonia|cough|influenza|flu|cold|tuberculosis"),
    ("digestive",    r"stomach|gastr|ulcer|indigestion|constipation|diarrhea|liver|hepat|gall|appendi|colon|bowel"),
    ("musculoskeletal", r"back|arthritis|joint|muscle|sprain|strain|bone|fracture|gout|rheumat"),
    ("skin",         r"acne|eczema|psoriasis|rash|boil|wart|burn|bite|sting|dermat"),
    ("urinary",      r"kidney|renal|urinary|bladder|uti|cystitis"),
    ("reproductive", r"menstru|pregnan|uter|prostat|ovary|test|breast|labor|delivery|fertil"),
    ("general",      r"fever|fatigue|anemia|allergy|diabetes|obesity|cancer|infection|poison|shock"),
]

def detect_system(title: str) -> str:
    t = title.lower()
    for system, pattern in SYSTEM_RULES:
        if re.search(pattern, t):
            return system
    return "general"

def chunk_diseases(lines: list[str]):
    entries = []
    cur = {"title": None, "sym": [], "cause": [], "treat": [], "buf": []}
    section = None

    def flush():
        if cur["title"] and (cur["sym"] or cur["cause"] or cur["treat"] or cur["buf"]):
            # combine sections into formatted content text
            parts = []
            if cur["sym"]:
                parts.append("SYMPTOMS\n" + "\n".join(cur["sym"]))
            if cur["cause"]:
                parts.append("CAUSES\n" + "\n".join(cur["cause"]))
            if cur["treat"]:
                parts.append("TREATMENT\n" + "\n".join(cur["treat"]))
            # any leftover goes at end
            if cur["buf"]:
                parts.append("\n".join(cur["buf"]))
            content = "\n\n".join(parts).strip()
            entries.append({"title": cur["title"].title(), "contentEn": content})
        cur["title"], cur["sym"], cur["cause"], cur["treat"], cur["buf"] = None, [], [], [], []

    for ln in lines:
        # new disease title
        if TITLE_RE.match(ln) and ln.isupper() and len(ln) <= 50:
            # avoid catching generic section headers by requiring a previous title or known prefix lines seen in that part of the book
            flush()
            cur["title"] = ln.strip()
            section = None
            continue

        if cur["title"]:
            # sectional switches
            if SYMPT.match(ln):
                section = "sym"; continue
            if CAUSE.match(ln):
                section = "cause"; continue
            if TREAT.match(ln):
                section = "treat"; continue

            # accumulate into current section or buffer
            if re.match(r"^[•\-\u2022]\s", ln):
                line = ln
            else:
                line = ln

            if section == "sym":
                cur["sym"].append(line)
            elif section == "cause":
                cur["cause"].append(line)
            elif section == "treat":
                cur["treat"].append(line)
            else:
                cur["buf"].append(line)

    flush()
    return entries

def main():
    with pdfplumber.open(PDF) as pdf:
        start_idx = START_PAGE - 1
        pages = pdf.pages[start_idx : (END_PAGE-1 if END_PAGE else None)]
        text = "\n".join(p.extract_text(x_tolerance=2, y_tolerance=2) or "" for p in pages)

    lines = clean_lines(text)
    entries = chunk_diseases(lines)

    # classify and build per-system lists
    buckets = defaultdict(list)
    for e in entries:
        system = detect_system(e["title"])
        e_id = f"disease-{system}-{slugify(e['title'])}"
        buckets[system].append({
            "id": e_id,
            "title": e["title"],
            "contentEn": e["contentEn"]
        })

    # write each bucket
    for system, items in buckets.items():
        out = OUT_DIR / f"diseases_{system}.json"
        write_items(items, out)
        print(f"{system:16s} → {len(items):3d} items → {out}")

if __name__ == "__main__":
    main()
