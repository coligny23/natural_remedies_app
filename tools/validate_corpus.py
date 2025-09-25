import json, re, sys, glob, os

ID_RE = re.compile(r'^[a-z0-9-]+$')

def load(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f'[ERR] {path}: JSON parse error at line {e.lineno} col {e.colno}: {e.msg}')
        raise

def is_synonyms_file(path: str) -> bool:
    return os.path.basename(path).lower() == 'synonyms.json'

def validate_synonyms(path: str) -> bool:
    ok = True
    data = load(path)
    if not isinstance(data, dict):
        print(f'[ERR] {path}: synonyms must be an object (map of term -> list of strings)')
        return False
    for k, vs in data.items():
        if not isinstance(vs, list) or not all(isinstance(x, str) for x in vs):
            print(f'[ERR] {path}: synonyms["{k}"] must be a list of strings')
            ok = False
    return ok

def get_content_fields(item):
    """Return (en, sw) accepting either camelCase or snake_case."""
    en = item.get('contentEn', item.get('content_en', ''))
    sw = item.get('contentSw', item.get('content_sw', ''))
    return en, sw

def validate_items_file(path: str, all_ids: dict) -> bool:
    ok = True
    data = load(path)
    if not isinstance(data, list):
        print(f'[ERR] {path}: top-level must be a list (array of content items)')
        return False
    for i, item in enumerate(data):
        where = f'{path}#{i}'
        for field in ('id', 'title'):
            if field not in item or not item[field]:
                print(f'[ERR] {where}: missing {field}')
                ok = False
        _id = item.get('id', '')
        if not ID_RE.match(_id):
            print(f'[ERR] {where}: id "{_id}" must match ^[a-z0-9-]+$')
            ok = False

        en, sw = get_content_fields(item)
        if not en and not sw:
            print(f'[ERR] {where}: at least one of contentEn/contentSw (or content_en/content_sw) is required')
            ok = False

        if _id in all_ids:
            print(f'[ERR] {_id} duplicated in {where} and {all_ids[_id]}')
            ok = False
        else:
            all_ids[_id] = where
    return ok

def main():
    ok = True
    all_ids = {}

    for lang in ('en', 'sw'):
        paths = glob.glob(f'assets/corpus/{lang}/*.json')
        # Debug print so you see exactly what’s being validated:
        print(f'[INFO] {lang} files:', ', '.join(os.path.basename(p) for p in paths) or '(none)')
        for path in sorted(paths):
            if is_synonyms_file(path):
                ok &= validate_synonyms(path)
            else:
                ok &= validate_items_file(path, all_ids)

    if ok:
        print('OK: corpus looks valid.')
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
