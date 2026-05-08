from pathlib import Path
import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer


MODEL_DIR = Path("assets/models_e5small")
ONNX_PATH = MODEL_DIR / "encoder_e5small.onnx"


def main():
    print(f"Loading ONNX model: {ONNX_PATH}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)

    session = ort.InferenceSession(str(ONNX_PATH), providers=["CPUExecutionProvider"])

    print("\nInputs:")
    for inp in session.get_inputs():
        print(inp.name, inp.shape, inp.type)

    print("\nOutputs:")
    for out in session.get_outputs():
        print(out.name, out.shape, out.type)

    encoded = tokenizer(
        "query: dawa ya kikohozi",
        padding="max_length",
        truncation=True,
        max_length=128,
        return_tensors="np",
    )

    inputs = {
        "input_ids": encoded["input_ids"].astype(np.int64),
        "attention_mask": encoded["attention_mask"].astype(np.int64),
    }

    outputs = session.run(None, inputs)

    print("\nOutput test:")
    for i, output in enumerate(outputs):
        print(f"Output {i}: shape={output.shape}, dtype={output.dtype}")

    embedding = outputs[0]
    print("\nEmbedding dimension:", embedding.shape)

    if embedding.shape == (1, 384):
        print("SUCCESS: ONNX model outputs a 384-dimensional embedding.")
    else:
        print("WARNING: Unexpected output shape.")


if __name__ == "__main__":
    main()