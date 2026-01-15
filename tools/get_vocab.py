# tools/get_vocab.py
import os, shutil
from sentence_transformers import SentenceTransformer

MODEL = "sentence-transformers/all-MiniLM-L6-v2"
DEST_DIR = os.path.join("assets", "models")
DEST = os.path.join(DEST_DIR, "vocab.txt")

m = SentenceTransformer(MODEL)
vf = getattr(m.tokenizer, "vocab_file", None)

os.makedirs(DEST_DIR, exist_ok=True)

if vf and os.path.exists(vf):
    shutil.copyfile(vf, DEST)
    print("Copied:", vf, "->", DEST)
else:
    # Fallback: save full tokenizer if vocab_file missing
    tok_dir = os.path.join(DEST_DIR, "tokenizer")
    m.tokenizer.save_pretrained(tok_dir)
    print("No vocab_file attribute. Saved tokenizer files to:", tok_dir)
    print("Use tokenizer.json (and vocab.txt if present) from that folder.")
