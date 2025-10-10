from __future__ import annotations
import argparse, csv, json, re, sys, time
from pathlib import Path
from typing import Dict, Any, Tuple

# ---------- name normalization helpers ----------
NON_ALNUM = re.compile(r"[^a-z0-9]+")
TRAILING_PARTS = (
    "cleaned", "translation", "translations",
    "sw", "swa", "sw-ke", "sw_tz", "sw-ke", "sw_KE", "sw_TZ"
)

def norm_key_from_filename(name: str) -> str:
    """
    Create a comparable key from a filename (without extension).
    - lowercase
    - replace non-alphanum with single underscore
    - remove trailing 'decorations' like cleaned/translation/sw/etc. repeatedly
    Examples:
      'diseases_digestive.cleaned_translation' -> 'diseases_digestive'
      'diseases-digestive_translation_sw'     -> 'diseases_digestive'
    """
    s = name.lower()
    s = NON_ALNUM.sub("_", s).strip("_")
    # peel trailing decorations repeatedly
    while True:
        changed = False
        for part in TRAILING_PARTS:
            if s.endswith("_" + part):
                s = s[: -(len(part) + 1)]
                s = s.strip("_")
                changed = True
        if not changed:
            break
    return s

def parse_args():
    p = argparse.ArgumentParser(description="Apply Swahili translations from CSVs into JSON (robust filename matching).")
    p.add_argument("--json-src", default="content_json/cleaned/json", help="Folder with source JSON files.")
    p.add_argument("--csv-src",  default="content_json/cleaned/auto_translated", help="Folder (scanned recursively) for CSVs.")
    p.add_argument("--dst",      default=None, help="Output folder for updated JSON. If omitted and --inplace not set, uses <json-src>_sw.")
    p.add_argument("--inplace",  action="store_true", help="Overwrite JSON files in-place.")
    p.add_argument("--force",    action="store_true", help="Overwrite existing non-empty contentSw in JSON.")
    p.add_argument("--indent",   type=int, default=2, help="JSON pretty-print indent.")
    p.add_argument("--verbose",  action="store_true", help="Print more matching diagnostics.")
    return p.parse_args()

def load_csv_map(csv_path: Path) -> Dict[str, str]:
    """Return {id -> contentSw} for rows with non-empty contentSw."""
    m: Dict[str, str] = {}
    with csv_path.open("r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        if not rdr.fieldnames:
            return m
        # tolerant header lookup
        fields_lower = {h.lower(): h for h in rdr.fieldnames}
        id_key = fields_lower.get("id") or "id"
        sw_key = fields_lower.get("contentsw") or fields_lower.get("content_sw") or "contentSw"
        for row in rdr:
            rid = (row.get(id_key) or "").strip()
            sw  = (row.get(sw_key) or "").strip()
            if rid and sw:
                m[rid] = sw
    return m

def preload_csv_maps(csv_root: Path, verbose: bool) -> Dict[str, Dict[str, str]]:
    """Scan for any .csv under csv_root; build maps keyed by normalized stem."""
    maps: Dict[str, Dict[str, str]] = {}
    files = sorted(csv_root.rglob("*.csv"))
    if verbose:
        print(f"Scanning CSVs under: {csv_root.resolve()}")
    for p in files:
        key = norm_key_from_filename(p.stem)
        mp = load_csv_map(p)
        if mp:
            # prefer the largest map if multiple files normalize to the same key
            if key not in maps or len(mp) > len(maps[key]):
                maps[key] = mp
            if verbose:
                print(f"  ✓ {p.name}  → key='{key}'  rows={len(mp)}")
        elif verbose:
            print(f"  • {p.name}  → key='{key}'  (no non-empty contentSw)")
    if verbose:
        print()
    return maps

def update_json_tree(node: Any, sw_map: Dict[str, str], force: bool) -> Tuple[int,int]:
    found = 0
    updated = 0
    if isinstance(node, dict):
        if "id" in node and "contentEn" in node:
            rid = node.get("id")
            if isinstance(rid, str):
                found += 1
                if rid in sw_map:
                    new_sw = sw_map[rid]
                    curr_sw = node.get("contentSw", "")
                    if force or not (isinstance(curr_sw, str) and curr_sw.strip()):
                        node["contentSw"] = new_sw
                        updated += 1
        for v in node.values():
            f, u = update_json_tree(v, sw_map, force)
            found += f; updated += u
    elif isinstance(node, list):
        for item in node:
            f, u = update_json_tree(item, sw_map, force)
            found += f; updated += u
    return found, updated

def safe_write_json(out_path: Path, obj: Any, indent: int):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=indent)
        f.write("\n")
    tmp.replace(out_path)

def main():
    args = parse_args()
    json_src = Path(args.json_src)
    csv_src  = Path(args.csv_src)

    if not json_src.exists():
        print(f"ERROR: json-src not found: {json_src.resolve()}"); sys.exit(1)
    if not csv_src.exists():
        print(f"ERROR: csv-src not found: {csv_src.resolve()}"); sys.exit(1)

    # destination
    if args.inplace:
        dst_root = json_src
    else:
        dst_root = Path(args.dst) if args.dst else Path(str(json_src) + "_sw")
        dst_root.mkdir(parents=True, exist_ok=True)

    # load CSV maps (robust)
    csv_maps = preload_csv_maps(csv_src, args.verbose)
    total_trans_rows = sum(len(mp) for mp in csv_maps.values())
    if total_trans_rows == 0:
        print("No translated rows found (contentSw). Nothing to apply.")
        sys.exit(0)

    # show quick index → helpful for debugging
    keys_preview = ", ".join(sorted(csv_maps.keys()))
    print(f"Found ~{total_trans_rows} translated rows across CSVs.")
    if args.verbose:
        print(f"CSV keys: {keys_preview}\n")

    start = time.time()
    processed_rows = 0
    applied_updates = 0

    # process JSON files
    for jf in sorted(json_src.glob("*.json")):
        json_key = norm_key_from_filename(jf.stem)
        print(f"• {jf.name}")
        sw_map = csv_maps.get(json_key)

        if not sw_map:
            print(f"  ↳ WARNING: no CSV matched json-key '{json_key}'.")
            # give a hint: closest 3 keys by simple prefix
            hints = [k for k in csv_maps.keys() if k.startswith(json_key.split("_")[0])]
            if hints:
                print(f"    try keys like: {', '.join(hints[:3])}")
            print()
            continue

        try:
            obj = json.loads(jf.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"  ↳ ERROR reading JSON: {e}\n")
            continue

        before = time.time()
        found, updated = update_json_tree(obj, sw_map, args.force)
        processed_rows += found
        applied_updates += updated

        out_path = dst_root / jf.name
        safe_write_json(out_path, obj, args.indent)

        elapsed = time.time() - start
        rate = (processed_rows / elapsed) if elapsed > 0 else 0.0
        remaining = max(0, total_trans_rows - processed_rows)
        eta = (remaining / rate) if rate > 0 else float("inf")
        took = time.time() - before
        avg = rate

        print(f"  ↳ matches in JSON: {found:,} | updated now: {updated:,} | saved → {out_path.name} ({took:.2f}s)")
        print(f"  ↳ overall: {processed_rows:,}/{total_trans_rows:,} rows | updates: {applied_updates:,} | rate: {rate:.1f} rows/s | ETA ~ {int(eta)}s | avg {avg:.1f} rows/s\n")

    total_s = time.time() - start
    avg_total = (processed_rows/total_s) if total_s > 0 else 0.0
    print("Done.")
    print(f"Applied updates: {applied_updates:,}")
    print(f"Processed rows (JSON matches): {processed_rows:,} / {total_trans_rows:,} translated rows in CSVs")
    print(f"Total time: {total_s:.1f}s  (avg {avg_total:.1f} rows/s)")
    if not args.inplace:
        print(f"Output JSON written to: {dst_root.resolve()}")

if __name__ == "__main__":
    main()
