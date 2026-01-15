# tools/export_minilm_onnx_static.py
import torch, onnx, onnxruntime as ort, numpy as np, os
from sentence_transformers import SentenceTransformer
from typing import Dict

MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
ONNX_OUT = "assets/models/minilm_l6_v2_static.onnx"
OPSET = 17

os.makedirs(os.path.dirname(ONNX_OUT), exist_ok=True)

class STEncoder(torch.nn.Module):
    def __init__(self, st_model: SentenceTransformer):
        super().__init__()
        self.st = st_model

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor):
        return self.st({"input_ids": input_ids, "attention_mask": attention_mask})

def main():
    device = "cpu"
    st = SentenceTransformer(MODEL_ID, device=device).eval()
    model = STEncoder(st).to(device).eval()

    # --- STATIC SHAPES ---
    B, T = 1, 128
    dummy_ids  = torch.ones((B, T), dtype=torch.long, device=device)
    dummy_mask = torch.ones((B, T), dtype=torch.long, device=device)

    with torch.no_grad():
        torch.onnx.export(
            model,
            (dummy_ids, dummy_mask),
            ONNX_OUT,
            input_names=["input_ids", "attention_mask"],
            output_names=["embeddings"],
            dynamic_axes=None,                # <- static !
            do_constant_folding=True,
            opset_version=OPSET,
        )

    m = onnx.load(ONNX_OUT); onnx.checker.check_model(m)
    print(f"Exported OK → {ONNX_OUT}")

    sess = ort.InferenceSession(ONNX_OUT, providers=["CPUExecutionProvider"])
    feeds: Dict[str, np.ndarray] = {
        "input_ids": np.ones((B, T), dtype=np.int64),
        "attention_mask": np.ones((B, T), dtype=np.int64),
    }
    out = sess.run(["embeddings"], feeds)[0]
    print("ORT output:", out.shape, "norms:", np.linalg.norm(out, axis=1))

if __name__ == "__main__":
    main()
