# tools/export_minilm_onnx.py
import torch
import onnx
import onnxruntime as ort
from sentence_transformers import SentenceTransformer
import numpy as np
from typing import Dict

MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
ONNX_OUT = "assets/models/minilm_l6_v2.onnx"
OPSET = 17  # ← fix: needs >=14; 17 is a safe modern target

# Optional: ensure export path exists
import os
os.makedirs(os.path.dirname(ONNX_OUT), exist_ok=True)

# A tiny wrapper that exposes the tensor inputs explicitly
class STEncoder(torch.nn.Module):
    def __init__(self, st_model: SentenceTransformer):
        super().__init__()
        # SentenceTransformer internally holds a transformer + pooling
        self.st = st_model

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor):
        # Returns the final sentence embedding (pooled, L2-normalized)
        out = self.st({"input_ids": input_ids, "attention_mask": attention_mask})
        # out shape: [batch, dim]
        return out

def main():
    device = "cpu"
    st = SentenceTransformer(MODEL_ID, device=device)
    st.eval()

    # Build a dummy batch
    B, T = 2, 8
    dummy_input_ids = torch.ones((B, T), dtype=torch.long, device=device)
    dummy_attn = torch.ones((B, T), dtype=torch.long, device=device)

    model = STEncoder(st).to(device).eval()

    # Disable grad for export
    with torch.no_grad():
        torch.onnx.export(
            model,
            (dummy_input_ids, dummy_attn),
            ONNX_OUT,
            input_names=["input_ids", "attention_mask"],
            output_names=["embeddings"],
            dynamic_axes={
                "input_ids": {0: "batch_size", 1: "seq_len"},
                "attention_mask": {0: "batch_size", 1: "seq_len"},
                "embeddings": {0: "batch_size"},
            },
            do_constant_folding=True,
            opset_version=OPSET,  # ← the key change
        )

    # Quick structural check
    onnx_model = onnx.load(ONNX_OUT)
    onnx.checker.check_model(onnx_model)
    print(f"Exported OK → {ONNX_OUT}")

    # Sanity run with onnxruntime (CPU)
    sess = ort.InferenceSession(ONNX_OUT, providers=["CPUExecutionProvider"])
    # Fake tokenized inputs (same shapes as dummy)
    feeds: Dict[str, np.ndarray] = {
        "input_ids": np.ones((B, T), dtype=np.int64),
        "attention_mask": np.ones((B, T), dtype=np.int64),
    }
    out = sess.run(["embeddings"], feeds)[0]
    print("ORT output shape:", out.shape)
    # L2 norm ~1.0 if SentenceTransformer returns normalized vectors
    norms = np.linalg.norm(out, axis=1)
    print("Sample norms:", norms)

if __name__ == "__main__":
    main()
