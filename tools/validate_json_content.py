import json, sys
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]  # repo root
SCHEMA = ROOT / "tools" / "schemas" / "content_item.schema.json"

def iter_items(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    # your files are either [ ... ] or { "items": [ ... ] }
    items = data.get("items") if isinstance(data, dict) else data
    if not isinstance(items, list):
        raise ValueError(f"{path}: not an array of items")
    for idx, it in enumerate(items):
        yield idx, it

def main():
    validator = Draft202012Validator(json.loads(SCHEMA.read_text(encoding="utf-8")))
    json_dir = ROOT / "content_json" / "cleaned" / "json_sw_with_images"

    bad = 0
    for jf in sorted(json_dir.glob("*.json")):
        for idx, it in iter_items(jf):
            errs = sorted(validator.iter_errors(it), key=lambda e: e.path)
            if errs:
                bad += 1
                print(f"[SCHEMA] {jf.name} item#{idx} id={it.get('id')}:")
                for e in errs:
                    print("   -", e.message)
    if bad:
        print(f"\nFAILED: {bad} item(s) violate schema")
        sys.exit(1)
    print("OK: all items conform to schema")

if __name__ == "__main__":
    main()
