import csv, time, re, sys, argparse, math, random
from pathlib import Path

try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator
except Exception:
    print("Please install deep-translator: py -m pip install --upgrade deep-translator")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Fast auto-fill Swahili translations into *_translation.csv")
parser.add_argument("--src", default="content_json/cleaned", help="Folder containing *_translation.csv")
parser.add_argument("--dst", default=None, help="Output folder (default: <src>/auto_translated)")
parser.add_argument("--glossary", default="tools/glossary_sw.csv", help="Glossary CSV (en,sw,preserve)")
parser.add_argument("--batch-size", type=int, default=20, help="Batch size for translation")
parser.add_argument("--sleep", type=float, default=0.15, help="Sleep between batches to reduce throttling")
parser.add_argument("--dry-run", action="store_true", help="Do not write files; just print what would happen")
args = parser.parse_args()

SRC_DIR = Path(args.src)
DST_DIR = Path(args.dst) if args.dst else (SRC_DIR / "auto_translated")
DST_DIR.mkdir(parents=True, exist_ok=True)

print(f"Working dir: {Path.cwd()}")
print(f"SRC_DIR: {SRC_DIR.resolve()}")
print(f"DST_DIR: {DST_DIR.resolve()}")
csv_files = sorted(SRC_DIR.glob("*_translation.csv"))
print(f"Found {len(csv_files)} CSV file(s).")
if not csv_files:
    sys.exit(0)

# --- Glossary ---
preserve_terms, map_terms = [], []
GLOSS = Path(args.glossary)
if GLOSS.exists():
    with GLOSS.open("r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            en = (row.get("en") or "").strip()
            sw = (row.get("sw") or "").strip()
            preserve = (row.get("preserve") or "").strip().lower() in ("yes","true","1")
            if not en: 
                continue
            if preserve and en not in preserve_terms:
                preserve_terms.append(en)
            if sw:
                map_terms.append((en, sw))
print(f"Glossary: preserve={len(preserve_terms)}; mapped={len(map_terms)}")

def protect_terms(text: str):
    placeholders = {}
    i = 0
    for term in preserve_terms:
        pattern = re.compile(re.escape(term), re.IGNORECASE)
        def _repl(m):
            nonlocal i
            token = f"[[T{i}]]"
            placeholders[token] = m.group(0)
            i += 1
            return token
        text = pattern.sub(_repl, text)
    return text, placeholders

def unprotect_terms(text: str, placeholders: dict):
    for token, original in placeholders.items():
        text = text.replace(token, original)
    return text

def apply_map_terms(text: str):
    for en, sw in map_terms:
        text = re.sub(re.escape(en), sw, text, flags=re.IGNORECASE)
    return text

# Caches to avoid re-translating identical lines
CACHE = {}

def provider_translate_batch(lines):
    """Try Google batch; fallback to line-by-line; finally to MyMemory; last resort: return input."""
    lines_out = [None]*len(lines)
    to_do_idx = [i for i, ln in enumerate(lines) if ln and not ln.isspace()]

    if not to_do_idx:
        return [ln for ln in lines]  # all blank

    # 1) try Google batch
    try:
        gt = GoogleTranslator(source="en", target="sw")
        # Some providers choke on very long strings; trim batch by length
        safe_lines = [lines[i] if len(lines[i]) < 4500 else lines[i][:4500] for i in to_do_idx]
        translated = gt.translate_batch(safe_lines)
        for i, t in zip(to_do_idx, translated):
            lines_out[i] = t
    except Exception:
        # fall back later
        pass

    # 2) any None → try Google single
    for i in to_do_idx:
        if lines_out[i] is not None:
            continue
        try:
            lines_out[i] = GoogleTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass

    # 3) any None → try MyMemory
    for i in to_do_idx:
        if lines_out[i] is not None:
            continue
        try:
            lines_out[i] = MyMemoryTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass

    # 4) last resort → keep English (so we never block)
    for i in to_do_idx:
        if lines_out[i] is None:
            lines_out[i] = lines[i]

    # Fill untouched slots (blank lines)
    for i, ln in enumerate(lines):
        if lines_out[i] is None:
            lines_out[i] = ln

    return lines_out

def translate_block(s: str) -> str:
    if not s.strip():
        return s

    # Split into lines but keep paragraph breaks intact
    paragraphs = s.split("\n\n")
    out_paras = []
    for p in paragraphs:
        p2, ph = protect_terms(p)
        lines = p2.split("\n")

        # Use cache for exact matches, collect unknowns
        batch, batch_idx = [], []
        for idx, ln in enumerate(lines):
            # leave pure bullet/symbol-only lines
            if re.match(r'^\s*([#>\-\*\d\.\)]+)\s*$', ln or ""):
                continue
            if ln in CACHE:
                continue
            batch.append(ln)
            batch_idx.append(idx)

        # Process in sub-batches to avoid throttling
        bs = max(1, args.batch_size)
        start_time = time.time()
        for k in range(0, len(batch), bs):
            chunk = batch[k:k+bs]
            if chunk:
                # translate chunk
                backoff = 0
                while True:
                    try:
                        res = provider_translate_batch(chunk)
                        for local_i, translated in enumerate(res):
                            orig_line = chunk[local_i]
                            CACHE[orig_line] = translated
                        break
                    except Exception:
                        # exponential backoff with jitter
                        backoff = max(0.5, min(8, (backoff*2) if backoff else 0.5))
                        time.sleep(backoff + random.uniform(0, 0.3))
                time.sleep(args.sleep)  # gentle rate limit

        # reconstruct lines
        t_lines = []
        for ln in lines:
            if re.match(r'^\s*([#>\-\*\d\.\)]+)\s*$', ln or ""):
                t_lines.append(ln)
                continue
            t = CACHE.get(ln, ln)
            t = unprotect_terms(t, ph)
            t = apply_map_terms(t)
            t_lines.append(t)

        out_paras.append("\n".join(t_lines))

        # small progress hint per paragraph
        elapsed = time.time() - start_time
        translated_lines = len(batch)
        if translated_lines:
            rate = translated_lines / max(0.001, elapsed)
            print(f"    paragraph: {translated_lines} line(s) ~ {rate:.1f} lines/sec")

    return "\n\n".join(out_paras)

for csv_path in csv_files:
    print(f"\n=== Processing {csv_path.name} ===")
    with csv_path.open("r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        fieldnames = rdr.fieldnames or ["id","title","contentEn","contentSw","needs_translation"]
        rows = list(rdr)

    if args.dry_run:
        print(f"(dry-run) Would translate {len(rows)} rows.")
        continue

    out_tmp = (DST_DIR / (csv_path.name + ".tmp")).open("w", encoding="utf-8", newline="")
    w = csv.DictWriter(out_tmp, fieldnames=fieldnames)
    w.writeheader()

    t0 = time.time()
    done = 0
    for row in rows:
        en = row.get("contentEn","") or ""
        sw = (row.get("contentSw") or "").strip()
        if not sw:
            sw = translate_block(en)
        row["contentSw"] = sw
        w.writerow(row)
        done += 1
        if done % 5 == 0 or done == len(rows):
            elapsed = time.time() - t0
            rate = done / max(0.001, elapsed)
            print(f"  → {csv_path.name}: {done}/{len(rows)} rows | ~{rate:.1f} rows/sec")

    out_tmp.close()
    Path(out_tmp.name).replace(DST_DIR / csv_path.name)
    print(f"✔ Wrote {csv_path.name}")
