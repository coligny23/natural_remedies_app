import json, re, time, random, argparse, os
from pathlib import Path
from typing import List, Dict, Any

try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator
except Exception:
    raise SystemExit("Please install deep-translator: pip install deep-translator")

try:
    from tqdm import tqdm
except Exception:
    tqdm = lambda x, **kw: x  # no-op if tqdm not installed

# --------- config / paths ----------
ROOT = Path(__file__).resolve().parents[1]
SRC  = ROOT / "assets" / "content_normalized"   # input folder (your normalized files)
OUT  = ROOT / "assets" / "content_sw_filled"    # output folder
OUT.mkdir(parents=True, exist_ok=True)

GLOSSARY_PATH = ROOT / "tools" / "sw_glossary.json"
GLOSSARY = {}
if GLOSSARY_PATH.exists():
    try:
        GLOSSARY = json.loads(GLOSSARY_PATH.read_text(encoding="utf-8"))
    except Exception:
        print("[warn] glossary JSON invalid, ignoring:", GLOSSARY_PATH)

# --------- helpers ----------
CACHE: Dict[str, str] = {}

def gfix(sw: str) -> str:
    """Apply glossary & quick cleanups."""
    t = sw or ""
    for en, sw_term in GLOSSARY.items():
        t = re.sub(rf"\b{re.escape(en)}\b", sw_term, t, flags=re.IGNORECASE)
    # normalize whitespace
    t = re.sub(r"\s+\n", "\n", t)
    return t.strip()

def translate_batch(lines: List[str], sleep=0.15, batch_size=20) -> List[str]:
    """Google batch -> Google single -> MyMemory single -> fallback."""
    out = [None] * len(lines)
    idxs = [i for i, s in enumerate(lines) if s and not s.isspace()]
    if not idxs:
        return lines[:]

    # 1) Google batch
    try:
        gt = GoogleTranslator(source="en", target="sw")
        # clamp length to stay safe
        safe = [lines[i][:4500] for i in idxs]
        res = gt.translate_batch(safe)
        for i, r in zip(idxs, res):
            out[i] = r
    except Exception:
        pass

    # 2) Google single
    for i in idxs:
        if out[i] is not None:
            continue
        try:
            out[i] = GoogleTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass

    # 3) MyMemory single
    for i in idxs:
        if out[i] is not None:
            continue
        try:
            out[i] = MyMemoryTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass

    # 4) fallback to original
    for i in idxs:
        if out[i] is None:
            out[i] = lines[i]

    # fill blanks for empty inputs and cache
    for i, s in enumerate(lines):
        if out[i] is None:
            out[i] = s
        CACHE[s] = out[i]

    time.sleep(sleep)
    return out

def translate_block(text: str, batch_size=20) -> str:
    """Paragraph-aware translation with caching and bullet preservation."""
    if not (text or "").strip():
        return text
    paragraphs = (text or "").split("\n\n")
    out_paras = []

    for p in paragraphs:
        lines = p.split("\n")
        to_tx, idxs = [], []
        for i, ln in enumerate(lines):
            # skip bare bullets/numbering; keep in EN (structure only)
            if re.match(r"^\s*([#>\-\*\d\.\)]+)\s*$", ln or ""):
                continue
            if ln in CACHE:
                continue
            to_tx.append(ln)
            idxs.append(i)

        # send in chunks with simple backoff
        for k in range(0, len(to_tx), batch_size):
            chunk = to_tx[k:k+batch_size]
            if not chunk:
                continue
            backoff = 0
            while True:
                try:
                    res = translate_batch(chunk, batch_size=batch_size)
                    for j, tr in enumerate(res):
                        CACHE[chunk[j]] = tr
                    break
                except Exception:
                    backoff = max(0.5, min(8, backoff*2 if backoff else 0.5))
                    time.sleep(backoff + random.uniform(0, 0.3))

        # rebuild paragraph
        out_lines = []
        for ln in lines:
            if re.match(r"^\s*([#>\-\*\d\.\)]+)\s*$", ln or ""):
                out_lines.append(ln)  # keep structure-only line
            else:
                out_lines.append(CACHE.get(ln, ln))
        out_paras.append("\n".join(out_lines))
    return "\n\n".join(out_paras)

def reconstruct_content_from_sections(sections: List[Dict[str, str]]) -> str:
    """Create a single string from sections with headings, for your current UI."""
    blocks = []
    for s in sections:
        t = (s.get("title") or "").strip()
        b = (s.get("body")  or "").strip()
        blocks.append(f"{t}\n\n{b}".strip() if t else b)
    return "\n\n".join([x for x in blocks if x])

def fill_item_sw(item: Dict[str, Any], batch_size=20) -> Dict[str, Any]:
    it = dict(item)

    # 1) translate contentSw if missing
    if not (it.get("contentSw") or "").strip():
        it["contentSw"] = translate_block(it.get("contentEn",""), batch_size=batch_size)

    # 2) if there are sections, also build sectionsSw for cleaner headings
    secs = it.get("sections")
    if isinstance(secs, list) and secs:
        new_sw = []
        for s in secs:
            title_en = (s.get("title") or "").strip()
            body_en  = (s.get("body")  or "").strip()
            title_sw = translate_block(title_en, batch_size=batch_size) if title_en else ""
            body_sw  = translate_block(body_en,  batch_size=batch_size) if body_en  else ""
            new_sw.append({"title": gfix(title_sw), "body": gfix(body_sw)})
        it["sectionsSw"] = new_sw
        # rebuild contentSw from translated sections (better for the accordion splitter)
        rebuilt = reconstruct_content_from_sections(new_sw)
        if rebuilt.strip():
            it["contentSw"] = rebuilt

    # 3) glossary pass on contentSw
    it["contentSw"] = gfix(it.get("contentSw",""))

    # 4) mark as reviewed if both sides exist
    if (it.get("contentEn","").strip() and it.get("contentSw","").strip()):
        it["needsReview"] = False

    return it

def process_file(basename: str, batch_size=20):
    src = SRC / basename
    if not src.exists():
        print(f"[warn] missing {src}, skipping")
        return
    data = json.loads(src.read_text(encoding="utf-8"))
    items = data.get("items") if isinstance(data, dict) else data
    if not isinstance(items, list):
        print(f"[warn] unexpected JSON shape in {basename}, skipping")
        return

    out_items = []
    for it in tqdm(items, desc=f"Filling {basename}"):
        out_items.append(fill_item_sw(it, batch_size=batch_size))

    (OUT / basename).write_text(json.dumps(out_items, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[done] wrote {OUT/basename} ({len(out_items)} items)")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch-size", type=int, default=20)
    ap.add_argument("--sleep", type=float, default=0.15)  # kept for compatibility, used inside translate_batch
    args = ap.parse_args()

    # Prime a quick test to verify connectivity early (optional)
    try:
        GoogleTranslator(source="en", target="sw").translate("Test")
    except Exception as e:
        print("[warn] Google translator not reachable right now, will try fallbacks too:", e)

    process_file("herbs.json", batch_size=args.batch_size)
    process_file("principles.json", batch_size=args.batch_size)
    print("[fill] all done ✓")

if __name__ == "__main__":
    main()
