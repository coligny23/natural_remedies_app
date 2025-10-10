from PIL import Image, ImageFile, UnidentifiedImageError
Image.MAX_IMAGE_PIXELS = 200_000_000  # raise the ceiling; or set to None to disable with caution
ImageFile.LOAD_TRUNCATED_IMAGES = True

#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import json, re

SRC_IMG_DIR = Path("assets/images/articles")
DST_IMG_DIR = Path("assets/images/articles_optimized")
JSON_DIR    = Path("content_json/cleaned/json_sw_with_images")  # your final JSONs
MAX_W       = 1024
QUALITY     = 70

DST_IMG_DIR.mkdir(parents=True, exist_ok=True)

def to_webp(src: Path, dst: Path):
    try:
        im = Image.open(src)
        # Fix EXIF orientation early (avoids gigantic intermediate)
        try:
            from PIL import ImageOps
            im = ImageOps.exif_transpose(im)
        except Exception:
            pass

        # Palette+transparency -> RGBA (fixes your warning)
        if im.mode in ("P", "PA"):
            im = im.convert("RGBA")

        # Choose mode: keep alpha if present, else RGB
        keep_alpha = ("A" in im.getbands())
        if not keep_alpha and im.mode not in ("RGB", "L"):
            im = im.convert("RGB")

        # Efficient downscale: thumbnail() preserves aspect and uses less memory
        w, h = im.size
        if w > MAX_W:
            target_h = int(h * (MAX_W / float(w)))
            im.thumbnail((MAX_W, target_h), Image.LANCZOS)

        dst = dst.with_suffix(".webp")
        save_kwargs = {"quality": QUALITY, "method": 6}
        if keep_alpha:
            # WebP supports alpha; don’t drop it
            save_kwargs["lossless"] = False  # set True if you want max quality + larger size
        im.save(dst, "WEBP", **save_kwargs)
        return dst
    except UnidentifiedImageError:
        print(f"[SKIP] Unrecognized image: {src.name}")
        return None


# 1) Convert all source images
print("Converting images...")
stem_map = {}  # stem -> new path (assets/... .webp)
for p in sorted(SRC_IMG_DIR.glob("*.*")):
    if p.suffix.lower() not in [".jpg", ".jpeg", ".png", ".webp"]:
        continue
    out = DST_IMG_DIR / p.name
    newp = to_webp(p, out)
    if not newp:
        continue
    stem_map[p.stem] = f"assets/images/articles_optimized/{newp.name}"

print(f"Optimized {len(stem_map)} images → {DST_IMG_DIR}")

# 2) Rewrite JSON image paths to use optimized .webp
print("Rewriting JSON...")
for jf in sorted(JSON_DIR.glob("*.json")):
    data = json.loads(jf.read_text(encoding="utf-8"))
    items = data["items"] if isinstance(data, dict) and "items" in data else data
    changed = False
    for it in items:
        img = it.get("image")
        if not img:
            continue
        # match by filename stem
        m = re.search(r'/([^/]+)\.(jpg|jpeg|png|webp)$', img, re.I)
        if not m:
            continue
        stem = m.group(1)
        new = stem_map.get(stem)
        if new and new != img:
            it["image"] = new
            changed = True
    if changed:
        jf.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Updated {jf.name}")

print("Done. Now point pubspec to the optimized folder.")
