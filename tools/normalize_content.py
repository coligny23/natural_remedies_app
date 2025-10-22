import argparse
import sys
import json, re, pathlib, hashlib

ROOT = pathlib.Path(__file__).resolve().parents[1]  # repo root

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--src", default="assets/corpus/en",
                   help="Folder containing herbs.json and principles.json")
    p.add_argument("--out", default="assets/content_normalized",
                   help="Output folder for normalized json")
    return p.parse_args()

def slugify(s):
    s = re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
    return re.sub(r'-{2,}', '-', s)

def split_numbered_blocks(text):
    """Return list of (title, body) for lines like '13 - CATNIP— ...' up to the next number."""
    if not text:
        return []
    # Normalize dashes; capture: number, name (uppercase words), then body
    chunks = re.split(r'(?=\b\d+\s*[-–]\s*[A-Z][A-Z\s]+[—-])', text)
    out = []
    for ch in chunks:
        m = re.match(r'\b(\d+)\s*[-–]\s*([A-Z][A-Z\s]+)[—-]\s*(.*)', ch.strip(), re.S)
        if not m:
            # try the "1 - CHARCOAL —" variant without mandatory em-dash
            m2 = re.match(r'\b(\d+)\s*[-–]\s*([A-Z][A-Z\s]+)\s*[—-]?\s*(.*)', ch.strip(), re.S)
            if not m2:
                continue
            num, name, body = m2.groups()
        else:
            num, name, body = m.groups()
        name = " ".join(name.title().split())
        out.append((name, body.strip()))
    return out

def first_sentence(text, n=160):
    t = (text or "").replace("\n", " ").strip()
    if not t:
        return t
    m = re.search(r'[.!?]', t)
    k = m.end() if m else min(len(t), n)
    s = t[:k]
    return s + ("…" if len(s) < len(t) else "")

def normalize_herbs(data):
    out = []
    seen_ids = set()
    for item in data:
        # Detect the big list pages by id/title/content
        if item.get("id") in {"herb-the-most-important-herbs", "herb-most-important-herbs"} or \
           "MOST IMPORTANT HERBS" in (item.get("contentEn") or ""):
            parts = split_numbered_blocks(item.get("contentEn", ""))
            for name, body in parts:
                cid = f"herb-{slugify(name)}"
                if cid in seen_ids:
                    cid += "-" + hashlib.md5(name.encode()).hexdigest()[:6]
                seen_ids.add(cid)
                out.append({
                    "id": cid,
                    "title": name,
                    "contentEn": body,
                    "contentSw": "",
                    "sections": [{"title": "Overview", "body": body}],
                    "parentId": "herb-the-most-important-herbs",
                    "image": item.get("image"),
                    "imageMeta": item.get("imageMeta", {}),
                    "needsReview": False
                })
            # keep a short index page too
            idx = dict(item)
            idx["contentEn"] = first_sentence(item.get("contentEn", ""))
            out.append(idx)
        else:
            out.append(item)
    return out

def split_principles(data):
    out = []
    for item in data:
        title_lc = (item.get("title") or "").lower()
        content_lc = (item.get("contentEn") or "").lower()
        if "basic principles" in title_lc or "principles of health" in content_lc:
            # pattern: '1 - Regularity in meals. … 2 - Moderation. …'
            blocks = re.split(r'(?=\b\d+\s*[-–]\s*)', item.get("contentEn", ""))
            children = []
            for b in blocks:
                m = re.match(r'\b(\d+)\s*[-–]\s*(.+?)\.\s*(.*)', b.strip(), re.S)
                if not m:
                    continue
                num, t, body = m.groups()
                t = t.strip().capitalize()
                cid = f"principle-basic-{num.zfill(2)}-{slugify(t)}"
                child = {
                    "id": cid,
                    "title": t,
                    "contentEn": body.strip(),
                    "sections": [{"title": "Overview", "body": body.strip()}],
                    "parentId": item.get("id"),
                    "image": item.get("image"),
                    "imageMeta": item.get("imageMeta", {}),
                    "needsReview": False
                }
                children.append(child)
            if children:
                parent = dict(item)
                parent["children"] = [c["id"] for c in children]
                parent["contentEn"] = first_sentence(item.get("contentEn", ""))
                out.append(parent)
                out.extend(children)
            else:
                out.append(item)
        else:
            out.append(item)
    return out

def main():
    args = parse_args()
    src = (ROOT / args.src).resolve()
    out_dir = (ROOT / args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    herbs_path = src / "herbs.json"
    principles_path = src / "principles.json"

    print(f"[normalize] SRC   = {src}")
    print(f"[normalize] OUT   = {out_dir}")
    print(f"[normalize] herbs = {herbs_path}")
    print(f"[normalize] princ = {principles_path}")

    if not herbs_path.exists():
        sys.exit(f"ERROR: herbs.json not found at {herbs_path}")
    if not principles_path.exists():
        sys.exit(f"ERROR: principles.json not found at {principles_path}")

    # Load (supports array or {"items":[...]})
    def load_items(p: pathlib.Path):
        raw = json.loads(p.read_text(encoding="utf-8"))
        return raw.get("items") if isinstance(raw, dict) else raw

    herbs = load_items(herbs_path)
    principles = load_items(principles_path)

    herbs2 = normalize_herbs(herbs)
    principles2 = split_principles(principles)

    (out_dir / "herbs.json").write_text(json.dumps(herbs2, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "principles.json").write_text(json.dumps(principles2, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[normalize] Done.")

if __name__ == "__main__":
    main()
