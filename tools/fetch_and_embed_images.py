#!/usr/bin/env python3
import argparse, json, time, os, csv, re, shutil, random
from pathlib import Path
from typing import Dict, Tuple, Optional, List
import requests
import yaml

# ----------------------------
# Defaults you can override via CLI
# ----------------------------
UA = "NaturalRemediesBot/1.0 (contact: odongo46@gmail.com)"
WIKI_API = "https://commons.wikimedia.org/w/api.php"

def slugify(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9\-_\.]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or "item"

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def load_json_items(fp: Path):
    data = json.loads(fp.read_text(encoding="utf-8"))
    if isinstance(data, dict) and "items" in data:
        return data, data["items"], True
    elif isinstance(data, list):
        return data, data, False
    else:
        # normalize to dict with items
        return {"items": data}, data, True

def save_json(fp: Path, data):
    fp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def build_query(title: str, category: Optional[str], tags: Optional[List[str]]) -> str:
    core = title
    # Nudge the search for better results
    extras = []
    if category:
        c = category.lower()
        if "herb" in c or c in ("herbs","plants"):
            extras.append("herb plant")
        elif any(k in c for k in ["disease", "condition", "symptom"]):
            extras.append("medical illustration")
    if tags:
        # cherry-pick a couple short tags
        kept = [t for t in tags if len(t) <= 20][:2]
        extras.extend(kept)
    q = " ".join([core, *extras]).strip()
    return q

# ----------------------------
# Wikimedia Commons Search
# ----------------------------
def wikimedia_search_images(query: str, min_width: int = 600, max_results: int = 5) -> List[Dict]:
    """
    Returns a list of candidate images with keys:
    url, width, height, page, author, license, title
    """
    params = {
        "action": "query",
        "format": "json",
        "prop": "imageinfo",
        "generator": "search",
        "gsrsearch": f'{query} filetype:bitmap',   # bias to photos/bitmaps
        "gsrlimit": max_results,
        "gsrnamespace": 6,                         # File namespace
        "iiprop": "url|extmetadata|user|size",
        "origin": "*",
    }
    headers = {"User-Agent": UA}
    r = requests.get(WIKI_API, params=params, headers=headers, timeout=20)
    r.raise_for_status()
    data = r.json()
    pages = (data.get("query") or {}).get("pages") or {}
    results = []
    for _, page in pages.items():
        ii = page.get("imageinfo", [])
        if not ii:
            continue
        info = ii[0]
        width = info.get("width") or 0
        height = info.get("height") or 0
        if width < min_width:
            continue
        ext = info.get("extmetadata") or {}
        license_short = (ext.get("LicenseShortName") or {}).get("value") or ""
        artist = (ext.get("Artist") or {}).get("value") or ""
        # strip HTML from 'Artist' if present
        artist = re.sub(r"<.*?>", "", artist).strip()
        results.append({
            "url": info.get("url"),
            "width": width,
            "height": height,
            "page": f'https://commons.wikimedia.org/?curid={page.get("pageid")}',
            "author": artist or info.get("user") or "",
            "license": license_short,
            "title": page.get("title") or "",
        })
    # Prefer wider images, then those with explicit licenses, then as-is
    results.sort(key=lambda x: (-(x["width"] or 0), 0 if x["license"] else 1))
    return results

def download_file(url: str, out_path: Path):
    headers = {"User-Agent": UA, "Referer": "https://commons.wikimedia.org"}
    with requests.get(url, headers=headers, timeout=60, stream=True) as r:
        r.raise_for_status()
        with out_path.open("wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 14):
                if chunk:
                    f.write(chunk)

def guess_ext_from_url(url: str) -> str:
    m = re.search(r"\.(jpg|jpeg|png|webp)$", url, re.I)
    return f".{m.group(1).lower()}" if m else ".jpg"

# ----------------------------
# Manual map (id -> URL or local file)
# ----------------------------
def load_id_map(fp: Optional[Path]) -> Dict[str, str]:
    if not fp or not fp.exists():
        return {}
    m = {}
    with fp.open("r", encoding="utf-8-sig", newline="") as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            _id = (r.get("id") or "").strip()
            img = (r.get("image") or "").strip()
            if _id and img:
                m[_id] = img
    return m

# ----------------------------
# Main embedding routine
# ----------------------------
def main():
    ap = argparse.ArgumentParser(description="Download & embed images into JSON items.")
    ap.add_argument("--json-in", required=True, help="Directory of input JSON files (merged SW).")
    ap.add_argument("--json-out", required=True, help="Directory to write updated JSON files.")
    ap.add_argument("--images-dir", required=True, help="Directory where images will be stored (e.g., assets/images/articles)")
    ap.add_argument("--category-fallbacks", default="", help="YAML file mapping category->fallback asset path.")
    ap.add_argument("--id-map", default="", help="CSV file mapping id->(image URL or local file path).")
    ap.add_argument("--min-width", type=int, default=600, help="Minimum image width to accept from Wikimedia.")
    ap.add_argument("--per-item", type=int, default=1, help="Max images to fetch per item (usually 1).")
    ap.add_argument("--dry-run", action="store_true", help="Scan and plan without downloading or writing JSON.")
    ap.add_argument("--skip-if-has-image", action="store_true", help="Skip items that already have an 'image' key.")
    args = ap.parse_args()

    json_in = Path(args.json_in)
    json_out = Path(args.json_out)
    images_dir = Path(args.images_dir)
    ensure_dir(json_out)
    ensure_dir(images_dir)

    # Load fallbacks + manual map
    category_fallbacks = {}
    if args.category_fallbacks:
        p = Path(args.category_fallbacks)
        if p.exists():
            category_fallbacks = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    id_map = load_id_map(Path(args.id_map) if args.id_map else None)

    # Build an index of existing local images by stem to allow re-runs
    existing_by_stem = {p.stem: p for p in images_dir.glob("*.*")}

    # Logs
    missing, used_fallback, used_manual, used_search, skipped = [], [], [], [], []

    for jf in sorted(json_in.glob("*.json")):
        data, items, had_items_wrapper = load_json_items(jf)
        changed = False

        for it in items:
            _id = it.get("id")
            title = (it.get("title") or "").strip()
            if not _id or not title:
                continue

            if args.skip_if_has_image and it.get("image"):
                skipped.append((_id, jf.name, "has_image_key"))
                continue

            # 0) If file with same stem already exists in images_dir, use it
            if _id in existing_by_stem:
                rel = f"{images_dir.as_posix().split('assets/')[-1]}"
                it["image"] = f"assets/{rel}/{existing_by_stem[_id].name}" if "assets/" not in images_dir.as_posix() \
                              else f"{images_dir.as_posix()}/{existing_by_stem[_id].name}"
                changed = True
                skipped.append((_id, jf.name, "found_local_existing"))
                continue

            # 1) Manual override (id_map)
            override = id_map.get(_id)
            if override:
                try:
                    if re.match(r"^https?://", override, re.I):
                        ext = guess_ext_from_url(override)
                        fname = slugify(_id) + ext
                        dest = images_dir / fname
                        if not args.dry_run:
                            download_file(override, dest)
                        it["image"] = f"{'assets/' if 'assets/' not in images_dir.as_posix() else ''}{images_dir.as_posix().split('assets/')[-1]}/{fname}"
                        # best-effort meta
                        it["imageMeta"] = {
                            "source": "manual",
                            "source_url": override,
                        }
                        changed = True
                        used_manual.append((_id, jf.name))
                    else:
                        # local file path copy
                        src = Path(override)
                        if src.exists():
                            dest = images_dir / f"{slugify(_id)}{src.suffix.lower() or '.jpg'}"
                            if not args.dry_run:
                                shutil.copy2(src, dest)
                            it["image"] = f"{'assets/' if 'assets/' not in images_dir.as_posix() else ''}{images_dir.as_posix().split('assets/')[-1]}/{dest.name}"
                            it["imageMeta"] = {"source": "local"}
                            changed = True
                            used_manual.append((_id, jf.name))
                        else:
                            raise FileNotFoundError(f"Local file not found: {src}")
                    continue
                except Exception as e:
                    print(f"[WARN] Manual map failed for {_id}: {e}")

            # 2) Wikimedia search
            query = build_query(title, it.get("category"), it.get("tags"))
            try:
                cand = wikimedia_search_images(query, min_width=args.min_width, max_results=max(5, args.per_item*3))
            except Exception as e:
                print(f"[WARN] Wikimedia search failed for {_id} ({title}): {e}")
                cand = []

            if cand:
                top = cand[0]
                ext = guess_ext_from_url(top["url"])
                fname = slugify(_id) + ext
                dest = images_dir / fname
                if not args.dry_run:
                    download_file(top["url"], dest)
                    # be polite
                    time.sleep(0.5 + random.random() * 0.6)

                # Compute a proper relative asset path for Flutter
                asset_prefix = "assets/"
                if "assets/" in images_dir.as_posix():
                    rel_assets = images_dir.as_posix().split("assets/")[-1]
                    asset_path = f"assets/{rel_assets}/{fname}"
                else:
                    # If user passed a non-assets path, still make it "assets/..." in JSON (Flutter expects under assets/)
                    # Adjust if your build copies elsewhere.
                    rel_from_assets = images_dir.as_posix().lstrip("/")
                    asset_path = f"assets/{rel_from_assets}/{fname}"

                it["image"] = asset_path
                it["imageMeta"] = {
                    "source": "Wikimedia Commons",
                    "source_url": top["page"],
                    "author": top["author"],
                    "license": top["license"],
                    "title": top["title"],
                    "width": top["width"],
                    "height": top["height"],
                    "credit": f"{top['title']} — {top['author']} ({top['license']}) via Wikimedia Commons"
                }
                used_search.append((_id, jf.name))
                changed = True
                continue

            # 3) Category fallback
            cat = (it.get("category") or "").strip().lower()
            fb = category_fallbacks.get(cat) or category_fallbacks.get("general")
            if fb:
                it["image"] = fb
                it.setdefault("imageMeta", {})["source"] = "fallback"
                used_fallback.append((_id, jf.name))
                changed = True
            else:
                missing.append((_id, jf.name))

        # Write file if changed (or always if you prefer)
        out_fp = (Path(args.json_out) / jf.name)
        if not args.dry_run:
            save_json(out_fp, data)
        print(f"Processed {jf.name}  (changed={changed})")

    # Write a small report
    report = [
        f"USED_SEARCH={len(used_search)}",
        f"USED_MANUAL={len(used_manual)}",
        f"USED_FALLBACK={len(used_fallback)}",
        f"SKIPPED={len(skipped)}",
        f"MISSING={len(missing)}"
    ]
    rep_dir = Path(args.json_out)
    rep_dir.mkdir(parents=True, exist_ok=True)
    (rep_dir / "_image_embed_report.txt").write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))
    if missing:
        (rep_dir / "_missing_images.tsv").write_text(
            "\n".join([f"{i}\t{f}" for i, f in missing]), encoding="utf-8"
        )
        print(f"Missing images list saved to {rep_dir / '_missing_images.tsv'}")

if __name__ == "__main__":
    main()
