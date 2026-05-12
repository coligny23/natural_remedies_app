import argparse
import json
import re
from pathlib import Path

TOKEN_RE = re.compile(r"[a-zA-ZÀ-ÿ0-9']+")

def tokenize(text):
    return [t.lower() for t in TOKEN_RE.findall(text or "") if len(t) > 1]

def load_corpus(corpus_dir):
    items = []
    for path in sorted(Path(corpus_dir).glob("*.json")):
        if path.name in {"synonyms.json", "sw_import.json"}:
            continue

        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            continue

        for item in data:
            if "id" in item and "title" in item:
                item["_source_file"] = path.name
                items.append(item)

    return items

def item_text(item, lang):
    title = item.get("title", "")
    title_sw = item.get("titleSw", "")
    aliases_sw = " ".join(item.get("aliasesSw", []) or [])
    content_en = item.get("contentEn") or item.get("content_en") or ""
    content_sw = item.get("contentSw") or item.get("content_sw") or ""
    tags = " ".join(item.get("tags", []) or [])

    if lang == "sw":
        return f"{title_sw} {title} {aliases_sw} {content_sw} {content_en} {tags}"
    return f"{title} {content_en} {content_sw} {tags}"

def score_item(query, item, lang):
    q_tokens = set(tokenize(query))
    if not q_tokens:
        return 0.0

    title_tokens = set(tokenize(item.get("title", "")))
    title_sw_tokens = set(tokenize(item.get("titleSw", "")))
    id_tokens = set(tokenize(item.get("id", "").replace("-", " ")))
    body_tokens = set(tokenize(item_text(item, lang)))

    aliases = item.get("aliasesSw", []) or []
    alias_tokens = set(tokenize(" ".join(aliases)))

    score = 0.0
    score += 3.0 * len(q_tokens & title_tokens)
    score += 3.0 * len(q_tokens & title_sw_tokens)
    score += 3.0 * len(q_tokens & alias_tokens)
    score += 1.5 * len(q_tokens & id_tokens)
    score += 1.0 * len(q_tokens & body_tokens)

    return score / max(1, len(q_tokens))

def search(query, items, lang, k=5):
    scored = []

    for item in items:
        s = score_item(query, item, lang)
        if s > 0:
            scored.append((s, item))

    scored.sort(key=lambda x: (-x[0], x[1].get("title", "")))

    return [
        {
            "rank": i + 1,
            "id": item["id"],
            "title": item.get("title", ""),
            "titleSw": item.get("titleSw", ""),
            "score": float(score),
        }
        for i, (score, item) in enumerate(scored[:k])
    ]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=["en", "sw"], required=True)
    parser.add_argument("--corpus-dir", required=True)
    parser.add_argument("--queries", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    items = load_corpus(args.corpus_dir)
    queries = json.loads(Path(args.queries).read_text(encoding="utf-8"))

    top1 = top3 = top5 = 0
    details = []

    for q in queries:
        query = q["query"]
        expected_id = q["expected_id"]

        results = search(query, items, args.lang, k=5)
        ids = [r["id"] for r in results]

        h1 = expected_id in ids[:1]
        h3 = expected_id in ids[:3]
        h5 = expected_id in ids[:5]

        top1 += int(h1)
        top3 += int(h3)
        top5 += int(h5)

        details.append({
            "query": query,
            "expected_id": expected_id,
            "top_5_results": results,
            "hit_top_1": h1,
            "hit_top_3": h3,
            "hit_top_5": h5,
        })

    total = len(queries)

    report = {
        "method": "keyword_lexical_baseline",
        "lang": args.lang,
        "corpus_dir": args.corpus_dir,
        "queries": args.queries,
        "total_queries": total,
        "top_1_hits": top1,
        "top_3_hits": top3,
        "top_5_hits": top5,
        "top_1_accuracy": top1 / total if total else 0,
        "top_3_accuracy": top3 / total if total else 0,
        "top_5_accuracy": top5 / total if total else 0,
        "details": details,
    }

    Path(args.output).write_text(
        json.dumps(report, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print("\nKeyword evaluation complete")
    print("---------------------------")
    print(f"Total queries: {total}")
    print(f"Top-1 Accuracy: {top1}/{total} = {report['top_1_accuracy']:.2%}")
    print(f"Top-3 Accuracy: {top3}/{total} = {report['top_3_accuracy']:.2%}")
    print(f"Top-5 Accuracy: {top5}/{total} = {report['top_5_accuracy']:.2%}")
    print(f"Report saved to: {args.output}")

if __name__ == "__main__":
    main()