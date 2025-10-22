import json
from pathlib import Path
from section_heuristics import find_blocks

ROOT = Path(__file__).resolve().parents[1]
IN_DIR  = ROOT / "content_json" / "cleaned" / "json_sw_with_images"
OUT_DIR = ROOT / "content_json" / "cleaned" / "json_sw_complete"
OUT_DIR.mkdir(parents=True, exist_ok=True)

CATEGORY_FALLBACKS = {
  "herb": "assets/images/fallbacks/herb.jpg",
  "disease": "assets/images/fallbacks/disease.jpg",
  "principle": "assets/images/fallbacks/principle.jpg"
}

def family_of(id_):
    return id_.split("-")[0] if "-" in id_ else "misc"

def ensure_sections(text: str) -> str:
    """If text has no recognizable headings, try to inject basic ones around detected blocks."""
    blocks = find_blocks(text)
    # if blocks only contain overview -> leave as is
    if set(blocks.keys()) <= {"overview"}:
        return text
    # rebuild in canonical order
    order = ["overview","treatment","causes","symptoms","usage","habitat"]
    parts = []
    for k in order:
      if k in blocks:
        title = {
          "overview": "Overview",
          "treatment": "Treatment",
          "causes": "Causes",
          "symptoms": "Symptoms",
          "usage": "How to use",
          "habitat": "Where found / Habitat"
        }[k]
        parts.append(title)
        parts.append("\n\n".join(blocks[k]))
    return "\n\n".join(parts).strip()

def main():
    for jf in sorted(IN_DIR.glob("*.json")):
        raw = json.loads(jf.read_text(encoding="utf-8"))
        items = raw.get("items") if isinstance(raw, dict) else raw
        changed = 0
        for it in items:
            id_ = it.get("id","")
            # 1) image fallback
            if not it.get("image"):
                fam = family_of(id_)
                it["image"] = CATEGORY_FALLBACKS.get(fam, CATEGORY_FALLBACKS["principle"])
                it.setdefault("imageMeta", {})["credit"] = "Fallback image"

            # 2) contentSw fallback to contentEn with marker
            if (not (it.get("contentSw") or "") .strip()) and (it.get("contentEn") or "").strip():
                it["contentSw"] = it["contentEn"]
                it["needsReview"] = True
                it.setdefault("missingFields", [])
                if "translation" not in it["missingFields"]:
                    it["missingFields"].append("translation")
                changed += 1

            # 3) normalize sections (both languages)
            for k in ("contentEn","contentSw"):
                val = (it.get(k) or "").strip()
                if not val: continue
                fixed = ensure_sections(val)
                if fixed != val:
                    it[k] = fixed
                    changed += 1

            # 4) if still very short, flag for editorial
            body = (it.get("contentSw") or it.get("contentEn") or "").strip()
            if len(body) < 140:
                it["needsReview"] = True
                it.setdefault("missingFields", [])
                if "too_short" not in it["missingFields"]:
                    it["missingFields"].append("too_short")

        outp = OUT_DIR / jf.name
        # keep same top-level shape
        if isinstance(raw, dict) and "items" in raw:
            raw["items"] = items
            outp.write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")
        else:
            outp.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"{jf.name}: {changed} change(s) → {outp.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
