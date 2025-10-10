# save as tools/clean_encouragement_and_export_csv.py and run with: python tools/clean_encouragement_and_export_csv.py
import json, re, csv
from pathlib import Path

CONTENT_DIR = Path("content_json")  # <-- change to your folder
OUT_DIR = CONTENT_DIR / "cleaned"
OUT_DIR.mkdir(parents=True, exist_ok=True)

def strip_encouragement(text: str) -> str:
    if not isinstance(text, str):
        return text
    cleaned = re.sub(r'\n?ENCOURAGEMENT—.*?(?:\n\s*\n|$)', '\n', text, flags=re.DOTALL)
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    return cleaned.strip()

for src in CONTENT_DIR.glob("*.json"):
    with src.open("r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        item["contentEn"] = strip_encouragement(item.get("contentEn"))
        if item.get("contentSw"):
            item["contentSw"] = strip_encouragement(item.get("contentSw"))

    # write cleaned json
    cleaned_path = OUT_DIR / (src.stem + ".cleaned.json")
    with cleaned_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    # write translation csv
    csv_path = OUT_DIR / (src.stem + "_translation.csv")
    with csv_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id","title","contentEn","contentSw","needs_translation"])
        writer.writeheader()
        for item in data:
            sw = item.get("contentSw") or ""
            writer.writerow({
                "id": item.get("id",""),
                "title": item.get("title",""),
                "contentEn": item.get("contentEn",""),
                "contentSw": sw,
                "needs_translation": "yes" if not sw.strip() else ""
            })

    print(f"✔ {src.name} → {cleaned_path.name}, {csv_path.name}")
