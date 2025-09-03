# translate_sw_hf_resumable.py
# EN -> SW with batching, progress, checkpoints, resume, and SAFE token-chunking for long inputs.

import os, json, argparse, time, math
from pathlib import Path
from typing import List, Dict, Tuple, Iterable, DefaultDict
from collections import defaultdict
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, pipeline

def batched(seq: List, n: int) -> Iterable[Tuple[int, List]]:
    for i in range(0, len(seq), n):
        yield i, seq[i:i+n]

def load_pipe(model_dir: Path):
    tok = AutoTokenizer.from_pretrained(model_dir, local_files_only=True)
    mdl = AutoModelForSeq2SeqLM.from_pretrained(model_dir, local_files_only=True)
    return pipeline("text2text-generation", model=mdl, tokenizer=tok, device=-1, framework="pt"), tok, mdl

def token_windows(text: str, tok, max_tokens: int) -> List[str]:
    """Split text into token windows <= max_tokens, preserving order."""
    # encode without specials so we control window size cleanly
    ids = tok.encode(text, add_special_tokens=False)
    if len(ids) <= max_tokens:
        return [text]
    chunks = []
    for i in range(0, len(ids), max_tokens):
        window_ids = ids[i:i+max_tokens]
        # decode back to text; skip_special_tokens=True keeps it clean
        chunk_txt = tok.decode(window_ids, skip_special_tokens=True)
        chunks.append(chunk_txt)
    return chunks

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", default="en_chunks_curated.json")
    ap.add_argument("--out", dest="out_path", default="en_sw_chunks_curated.json")
    ap.add_argument("--model", dest="model_dir", default="models/Rogendo/en-sw")
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--max-new", dest="max_new", type=int, default=160, help="Max new tokens to generate per segment")
    ap.add_argument("--src-max", dest="src_max", type=int, default=480, help="Max source tokens per segment (<=512 for Marian)")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--checkpoint-every", type=int, default=200)
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--truncate", action="store_true", help="Hard truncate at src-max instead of chunking")
    args = ap.parse_args()

    in_path  = Path(args.in_path)
    out_path = Path(args.out_path)
    model_dir = Path(args.model_dir)

    assert in_path.exists(), f"Missing input: {in_path}"
    assert model_dir.exists(), f"Missing model dir: {model_dir}"

    # Encourage multithreaded math libs on CPU
    os.environ.setdefault("OMP_NUM_THREADS", str(os.cpu_count()))
    os.environ.setdefault("MKL_NUM_THREADS", str(os.cpu_count()))

    data: List[Dict] = json.loads(in_path.read_text(encoding="utf-8"))

    # Worklist: only items lacking content_sw
    indices = [i for i, it in enumerate(data) if (it.get("content_en") and not it.get("content_sw"))]
    if args.limit:
        indices = indices[:args.limit]

    # Resume: merge any previous translations from out_path
    if args.resume and out_path.exists():
        try:
            prev = json.loads(out_path.read_text(encoding="utf-8"))
            prev_by_id = {it["id"]: it for it in prev}
            restored = 0
            for i in list(indices):
                old = prev_by_id.get(data[i]["id"])
                if old and old.get("content_sw"):
                    data[i]["content_sw"] = old["content_sw"]
                    if data[i].get("translation_status") == "original":
                        data[i]["translation_status"] = old.get("translation_status", "machine")
                    restored += 1
            indices = [i for i in indices if not data[i].get("content_sw")]
            print(f"Resume restored {restored} items from {out_path.name}")
        except Exception:
            pass

    pipe, tok, mdl = load_pipe(model_dir)

    # Safety cap: Marian usually has 512 max source positions
    model_cap = getattr(tok, "model_max_length", 512) or 512
    src_cap = min(args.src_max, model_cap, 512)
    print(f"Device: CPU | Pending: {len(indices)} | src-max={src_cap} | max-new={args.max_new} | batch={args.batch}")

    if not indices:
        out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Nothing to do. Wrote {out_path}")
        return

    done = 0
    t0 = time.time()

    # Process in batches
    for _, batch_idx in batched(indices, args.batch):
        # Build per-item segments respecting src token limit
        seg_texts: List[str] = []
        seg_map: List[Tuple[int, int]] = []  # (item_index, segment_index)
        for i in batch_idx:
            src = data[i]["content_en"][:6000]  # guardrail
            if args.truncate:
                # Hard truncate to src_cap tokens
                ids = tok.encode(src, add_special_tokens=False)[:src_cap]
                segs = [tok.decode(ids, skip_special_tokens=True)]
            else:
                segs = token_windows(src, tok, src_cap)
            for j, s in enumerate(segs):
                seg_texts.append(s)
                seg_map.append((i, j))

        # Translate all segments for this batch at once
        preds = pipe(
            seg_texts,
            num_beams=4,
            max_new_tokens=args.max_new,   # generation length
            truncation=True                # extra safety
        )

        # Normalize outputs list (pipeline may return list[dict] or list[list[dict]])
        outs = []
        for p in preds:
            outs.append(p[0]["generated_text"] if isinstance(p, list) else p["generated_text"])

        # Stitch segments back to items
        combined: DefaultDict[int, List[str]] = defaultdict(list)
        for (i, _segk), sw in zip(seg_map, outs):
            combined[i].append(sw)

        for i in batch_idx:
            if i in combined:
                full_sw = "\n".join(combined[i]).strip()
                data[i]["content_sw"] = full_sw
                if data[i].get("translation_status") == "original":
                    data[i]["translation_status"] = "machine"

        done += len(batch_idx)
        dt = int(time.time() - t0)
        print(f"[{done}/{len(indices)}] batch done in {dt}s")

        if done % args.checkpoint_every == 0:
            out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"Checkpoint → {out_path}")

    # Final write
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"DONE → {out_path}")
    
if __name__ == "__main__":
    main()
