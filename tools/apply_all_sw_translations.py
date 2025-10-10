# tools/apply_all_sw_translations.py
import json, csv
from pathlib import Path

CLEAN_DIR = Path("content_json/cleaned")
OUT_DIR   = CLEAN_DIR / "localized"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# For every "<name>_translation.csv", find "<name>.cleaned.json"
for csv_path in CLEAN_DIR.glob("*_translation.csv"):
    stem = csv_path.stem.replace("_translation", "")
    json_in  = CLEAN_DIR / f"{stem}.cleaned.json"
    json_out = OUT_DIR / f"{stem}.localized.json"

    if not json_in.exists():
        print(f"⚠ Skipping {csv_path.name} (no matching {json_in.name})")
        continue

    # id -> contentSw
    sw_map = {}
    with csv_path.open("r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            sw_map[str(row.get("id",""))] = row.get("contentSw","")

    with json_in.open("r", encoding="utf-8") as f:
        data = json.load(f)

    # apply
    for item in data:
        _id = str(item.get("id",""))
        if _id in sw_map and sw_map[_id] is not None:
            item["contentSw"] = sw_map[_id]

    with json_out.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✔ {csv_path.name} → {json_out.name}")
