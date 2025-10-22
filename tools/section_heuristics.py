import re

SECTION_KEYS = {
    "treatment": ["treatment","treatments","management","therapy","care","remedy","remedies","matibabu","tiba","huduma","utunzaji"],
    "causes":    ["cause","causes","etiology","risk factor","risk factors","visababishi","kisababishi","sababu","vyanzo"],
    "symptoms":  ["symptom","symptoms","sign","signs","presentation","dalili","viashiria","ishara"],
    "usage":     ["how to use","usage","matumizi","jinsi ya kutumia"],
    "habitat":   ["where found","habitat","inapatikana","hukua"]
}

def find_blocks(text: str):
    """Return dict(section -> list[str]) by scanning headings present in the text."""
    text = (text or "").replace("\r\n","\n")
    lines = text.split("\n")
    def _is_heading(line, syns):
        l = line.strip().lower()
        stripped = re.sub(r'^(?:\d+[\).\s-]+|[-–—•]\s*)','', l)
        for s in syns:
            if re.fullmatch(fr"{re.escape(s)}\s*[:\-–—]?", stripped): return True
            if re.match(fr"{re.escape(s)}\s*[:\-–—]", stripped): return True
        return False

    cur = "overview"
    out = {k:[] for k in ["overview","treatment","causes","symptoms","usage","habitat"]}
    buf = []
    def flush():
        t = "\n".join(buf).strip()
        if t: out[cur].append(t)
        buf.clear()

    for ln in lines:
        maybe = None
        for key, syns in SECTION_KEYS.items():
            if _is_heading(ln, syns):
                maybe = key
                break
        if maybe:
            flush()
            cur = maybe
            # keep inline text after colon
            m = re.search(r'[:\-–—]\s*(.+)$', ln.strip())
            if m: buf.append(m.group(1))
        else:
            buf.append(ln)
    flush()
    # drop empty lists
    return {k:v for k,v in out.items() if v}
