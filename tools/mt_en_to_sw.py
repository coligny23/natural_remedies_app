# tools/mt_en_to_sw.py
import csv, sys, os, re, time
from pathlib import Path
from transformers import MarianMTModel, MarianTokenizer, pipeline
import torch

# ------------- CONFIGURATION -------------
IN_CSV  = Path("tools/out/en_corpus.csv")       # from export_corpus.dart
OUT_CSV = Path("tools/in/sw_translations.csv")  # output (resumable)
MODEL_NAME = "Helsinki-NLP/opus-mt-en-sw"       # EN→SW model
MAX_LEN = 512
BATCH_SIZE = 6
CPU_THREADS = 2
# -----------------------------------------

torch.set_num_threads(CPU_THREADS)

def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

def split_paragraphs(text):
    paras = [p.strip() for p in text.replace('\r\n', '\n').split('\n\n') if p.strip()]
    out = []
    for p in paras:
        sents = re.split(r'(?<=[.!?])\s+', p)
        buf, cur = [], ""
        for s in sents:
            s = s.strip()
            if not s:
                continue
            if len(cur) + len(s) < 300:
                cur = (cur + " " + s).strip()
            else:
                if cur:
                    buf.append(cur)
                cur = s
        if cur:
            buf.append(cur)
        out.append(buf)
    return out  # list[list[str]]

def join_paragraphs(paras_translated):
    joined = []
    for sent_list in paras_translated:
        joined.append(" ".join(sent_list))
    return "\n\n".join(joined)

def load_input_rows():
    if not IN_CSV.exists():
        print(f"❌ Input CSV not found: {IN_CSV}", file=sys.stderr)
        sys.exit(1)
    rows = []
    with open(IN_CSV, newline='', encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            _id   = (r.get("id") or "").strip()
            title = (r.get("title") or "").strip()
            body  = (r.get("contentEn") or "").strip()
            if _id and body:
                rows.append((_id, title, body))
    return rows

def main():
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)

    # Load model
    print(f"🧠 Loading model: {MODEL_NAME}")
    tok = MarianTokenizer.from_pretrained(MODEL_NAME)
    mdl = MarianMTModel.from_pretrained(MODEL_NAME)
    translator = pipeline(
        "translation",
        model=mdl,
        tokenizer=tok,
        src_lang="en",
        tgt_lang="sw",
        max_length=MAX_LEN,
        batch_size=4
    )

    rows = load_input_rows()
    total = len(rows)
    print(f"📘 Found {total} English rows to translate")

    # Resume support: skip already-translated ids
    done_ids = set()
    write_header = not OUT_CSV.exists()
    if OUT_CSV.exists():
        with open(OUT_CSV, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                done_ids.add(r["id"])
        print(f"⏩ Skipping {len(done_ids)} rows already done")

    f_out = open(OUT_CSV, "a", newline="", encoding="utf-8")
    w = csv.writer(f_out)
    if write_header:
        w.writerow(["id", "contentSw", "titleSw"])

    start_time = time.time()

    for i, (_id, title, body) in enumerate(rows, 1):
        if _id in done_ids:
            continue
        print(f"[{i}/{total}] {_id}")

        try:
            title_sw = translator(title)[0]["translation_text"] if title else _id
        except Exception as e:
            print(f"⚠️ Title translation failed for {_id}: {e}")
            title_sw = title

        paras = split_paragraphs(body)
        paras_sw = []
        for sent_list in paras:
            batch_sw = []
            for batch in chunks(sent_list, BATCH_SIZE):
                try:
                    res = translator(batch)
                    batch_sw.extend([o["translation_text"] for o in res])
                except Exception as e:
                    print(f"⚠️ Body translation batch failed for {_id}: {e}")
                    batch_sw.extend(batch)  # fallback to original
            paras_sw.append(batch_sw)

        body_sw = join_paragraphs(paras_sw)

        w.writerow([_id, body_sw, title_sw])
        f_out.flush()

    f_out.close()
    mins = (time.time() - start_time) / 60
    print(f"✅ Done. Wrote {OUT_CSV}  ({mins:.1f} min total)")

if __name__ == "__main__":
    main()
