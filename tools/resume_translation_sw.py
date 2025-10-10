import csv, time, re, sys, argparse, random
from pathlib import Path

try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator
except Exception:
    print("Please install deep-translator: py -m pip install --upgrade deep-translator")
    sys.exit(1)

p = argparse.ArgumentParser(description="Resume Swahili translations by filling only blank contentSw cells.")
p.add_argument("--src", default="content_json/cleaned", help="Folder with *_translation.csv (originals)")
p.add_argument("--work", default=None, help="Folder with partial results (default: <src>/auto_translated if exists)")
p.add_argument("--sleep", type=float, default=0.15, help="Pause between batches")
p.add_argument("--batch-size", type=int, default=20, help="Batch size for provider")
args = p.parse_args()

SRC = Path(args.src)
WORK = Path(args.work) if args.work else (SRC / "auto_translated")
WORK.mkdir(parents=True, exist_ok=True)

def list_csvs(dirpath: Path):
    return sorted([p for p in dirpath.glob("*_translation.csv")])

src_csvs = list_csvs(SRC)
if not src_csvs:
    print(f"No *_translation.csv in {SRC.resolve()}")
    sys.exit(0)

CACHE = {}

def translate_batch(lines):
    # Try Google batch → Google single → MyMemory single → fallback to English
    out = [None]*len(lines)
    idxs = [i for i, t in enumerate(lines) if t and not t.isspace()]
    if not idxs:
        return lines[:]
    # 1) Google batch
    try:
        gt = GoogleTranslator(source="en", target="sw")
        safe = [lines[i][:4500] for i in idxs]
        res = gt.translate_batch(safe)
        for i, r in zip(idxs, res):
            out[i] = r
    except Exception:
        pass
    # 2) Google single
    for i in idxs:
        if out[i] is not None: continue
        try:
            out[i] = GoogleTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass
    # 3) MyMemory
    for i in idxs:
        if out[i] is not None: continue
        try:
            out[i] = MyMemoryTranslator(source="en", target="sw").translate(lines[i])
        except Exception:
            pass
    # 4) fallback
    for i in idxs:
        if out[i] is None:
            out[i] = lines[i]
    # fill blanks for empty inputs
    for i, t in enumerate(lines):
        if out[i] is None:
            out[i] = t
    return out

def translate_block(s: str) -> str:
    if not s.strip():
        return s
    paragraphs = s.split("\n\n")
    out_paras = []
    for p in paragraphs:
        lines = p.split("\n")
        to_translate, idxs = [], []
        for i, ln in enumerate(lines):
            if re.match(r'^\s*([#>\-\*\d\.\)]+)\s*$', ln or ""):
                continue
            if ln in CACHE: 
                continue
            to_translate.append(ln)
            idxs.append(i)
        # chunked batches
        for k in range(0, len(to_translate), args.batch_size):
            chunk = to_translate[k:k+args.batch_size]
            if not chunk: 
                continue
            backoff = 0
            while True:
                try:
                    res = translate_batch(chunk)
                    for j, tr in enumerate(res):
                        CACHE[chunk[j]] = tr
                    break
                except Exception:
                    backoff = max(0.5, min(8, backoff*2 if backoff else 0.5))
                    time.sleep(backoff + random.uniform(0, 0.3))
            time.sleep(args.sleep)
        # rebuild
        out_lines = []
        for ln in lines:
            if re.match(r'^\s*([#>\-\*\d\.\)]+)\s*$', ln or ""):
                out_lines.append(ln)
            else:
                out_lines.append(CACHE.get(ln, ln))
        out_paras.append("\n".join(out_lines))
    return "\n\n".join(out_paras)

def read_csv(path: Path):
    with path.open("r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        rows = list(rdr)
    return rdr.fieldnames, rows

def safe_write(path: Path, fieldnames, rows):
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    tmp.replace(path)

for src in src_csvs:
    # Decide output file path in WORK
    out = WORK / src.name
    # Load rows from SRC (authoritative schema/order)
    fieldnames, src_rows = read_csv(src)

    # If we already have partial/complete OUT, hydrate existing translations first
    existing = {}
    if out.exists():
        _, out_rows = read_csv(out)
        for r in out_rows:
            k = (r.get("id") or "").strip()
            if k and (r.get("contentSw") or "").strip():
                existing[k] = r["contentSw"]

    total = len(src_rows)
    done_rows = 0
    translated_cells = 0
    start = time.time()

    # Merge + translate blanks
    for r in src_rows:
        k = (r.get("id") or "").strip()
        en = r.get("contentEn","") or ""
        sw = (r.get("contentSw") or "").strip()
        if not sw and k in existing:
            sw = existing[k]
        if not sw and en.strip():
            sw = translate_block(en)
            translated_cells += 1
        r["contentSw"] = sw
        done_rows += 1
        if done_rows % 10 == 0 or done_rows == total:
            rate = done_rows / max(0.001, time.time() - start)
            print(f"{src.name}: {done_rows}/{total} rows (~{rate:.1f} rows/sec)")

    WORK.mkdir(parents=True, exist_ok=True)
    safe_write(out, fieldnames, src_rows)
    print(f"✔ {src.name} → {out} | newly translated: {translated_cells}")
