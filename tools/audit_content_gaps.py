import json, csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_DIR = ROOT / "content_json" / "cleaned" / "json_sw_with_images"
OUT_CSV  = ROOT / "content_json" / "quality" / "content_gaps_report.csv"
OUT_CSV.parent.mkdir(parents=True, exist_ok=True)

def norm(s): 
    return (s or "").strip()

def load_items(path: Path):
    raw = json.loads(path.read_text(encoding="utf-8"))
    items = raw.get("items") if isinstance(raw, dict) else raw
    return items if isinstance(items, list) else []

def has_section(text: str, *keys):
    t = (text or "").lower()
    return any(k in t for k in keys)

def main():
    rows = []
    for jf in sorted(JSON_DIR.glob("*.json")):
        for it in load_items(jf):
            id_ = it.get("id","")
            title = norm(it.get("title"))
            en = norm(it.get("contentEn"))
            sw = norm(it.get("contentSw"))
            img = norm(it.get("image"))

            # basic presence checks
            missing = []
            if not title: missing.append("title")
            if not en and not sw: missing.append("content")  # neither language present
            if not img: missing.append("image")

            # section-level checks (from either language)
            body = sw or en
            has_treat = has_section(body, "treatment", "matibabu", "tiba")
            has_causes = has_section(body, "cause", "sababu", "visababishi", "vyanzo")
            has_sympt  = has_section(body, "symptom", "dalili", "ishara", "viashiria")

            if not has_treat:  missing.append("section:treatment")
            if not has_causes: missing.append("section:causes")
            if not has_sympt:  missing.append("section:symptoms")

            # soft heuristics for herbs
            if id_.startswith("herb-"):
                if not has_section(body, "how to use", "usage", "jinsi ya kutumia", "matumizi"):
                    missing.append("section:usage")
                if not has_section(body, "where found", "habitat", "inapatikana", "hukua"):
                    missing.append("section:habitat")

            if missing:
                rows.append({
                    "file": jf.name,
                    "id": id_,
                    "title": title,
                    "missing": ";".join(missing)
                })

    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["file","id","title","missing"])
        w.writeheader()
        for r in rows: w.writerow(r)

    print(f"Report → {OUT_CSV} ({len(rows)} rows)")
    if rows:
        print("Top 10:")
        for r in rows[:10]:
            print("  -", r)

if __name__ == "__main__":
    main()
