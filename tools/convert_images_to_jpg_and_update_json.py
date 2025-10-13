#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageFile, UnidentifiedImageError, ImageOps
import json, re

# ---- CONFIG ----
SRC_IMG_DIR = Path("assets/images/articles_optimized")  # where your images are now (webp/png/jpg)
DST_IMG_DIR = Path("assets/images/articles_jpg")        # new JPEG output folder
JSON_DIR    = Path("content_json/cleaned/json_sw_with_images")  # JSONs to rewrite
MAX_W       = 1024     # resize if wider than this (800–1200 is sensible)
QUALITY     = 72       # JPEG quality (60–80 typical sweet spot)
PROGRESSIVE = True     # smaller on average, better perceived load
BG_COLOR    = (255, 255, 255)  # background for images with transparency
# -----------------

Image.MAX_IMAGE_PIXELS = 200_000_000
ImageFile.LOAD_TRUNCATED_IMAGES = True

DST_IMG_DIR.mkdir(parents=True, exist_ok=True)

def to_jpg(src: Path, dst_dir: Path) -> Path | None:
    try:
        im = Image.open(src)
        # Normalize EXIF orientation
        try:
            im = ImageOps.exif_transpose(im)
        except Exception:
            pass

        # Resize down if needed (memory-lean)
        w, h = im.size
        if w > MAX_W:
            nh = int(h * (MAX_W / float(w)))
            im = im.resize((MAX_W, nh), Image.LANCZOS)

        # Handle transparency: composite over white (JPEG has no alpha)
        if im.mode in ("RGBA", "LA") or ("A" in im.getbands()):
            bg = Image.new("RGB", im.size, BG_COLOR)
            # Use alpha as mask; if mode doesn't have alpha, mask=None
            alpha = im.split()[-1] if "A" in im.getbands() else None
            bg.paste(im.convert("RGBA"), mask=alpha)
            im = bg
        elif im.mode not in ("RGB", "L"):
            im = im.convert("RGB")

        out = dst_dir / (src.stem + ".jpg")
        im.save(out, "JPEG", quality=QUALITY, optimize=True, progressive=PROGRESSIVE)
        return out

    except UnidentifiedImageError:
        print(f"[SKIP] Unrecognized image: {src.name}")
        return None
    except Exception as e:
        print(f"[SKIP] {src.name}: {e}")
        return None

def main():
    # 1) Convert all source images
    name_map = {}  # stem -> new asset path
    exts = {".webp", ".jpg", ".jpeg", ".png"}
    for p in sorted(SRC_IMG_DIR.glob("*.*")):
        if p.suffix.lower() not in exts:
            continue
        newp = to_jpg(p, DST_IMG_DIR)
        if newp:
            name_map[p.stem] = f"assets/images/articles_jpg/{newp.name}"

    print(f"Converted {len(name_map)} images → {DST_IMG_DIR}")

    # 2) Rewrite JSON image paths to the new .jpg
    pat = re.compile(r'/([^/]+)\.(webp|jpg|jpeg|png)$', re.I)
    changed_files = 0

    for jf in sorted(JSON_DIR.glob("*.json")):
        data = json.loads(jf.read_text(encoding="utf-8"))
        items = data["items"] if isinstance(data, dict) and "items" in data else data

        changed = False
        for it in items:
            img = (it.get("image") or "").strip()
            if not img: 
                continue
            m = pat.search(img)
            if not m:
                continue
            stem = m.group(1)
            new = name_map.get(stem)
            if new and new != img:
                it["image"] = new
                changed = True

        if changed:
            jf.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            changed_files += 1
            print(f"Updated {jf.name}")

    print(f"Done. JSONs updated: {changed_files}")

if __name__ == "__main__":
    main()
