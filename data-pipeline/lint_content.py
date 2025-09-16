from pathlib import Path
import json, re, sys
ROOT = Path(__file__).resolve().parents[1]  # project root
errors = 0
for p in (ROOT / "assets/corpus/en").glob("*.json"):
  data = json.loads(p.read_text(encoding="utf-8"))
  for i, it in enumerate(data):
    id_ = it.get("id") or ""
    title = it.get("title") or ""
    en = it.get("content_en", it.get("contentEn"))
    if not re.fullmatch(r"[a-z0-9-]+", id_):
      print(f"{p.name}:{i} invalid id: {id_}"); errors += 1
    if not title.strip():
      print(f"{p.name}:{i} missing title"); errors += 1
    if not (isinstance(en, str) and en.strip()):
      print(f"{p.name}:{i} missing/empty content_en"); errors += 1
print("OK" if errors == 0 else f"Found {errors} issues"); sys.exit(1 if errors else 0)
