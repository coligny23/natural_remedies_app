from pathlib import Path
import numpy as np
import onnxruntime as ort
import tensorflow as tf
from transformers import AutoTokenizer


MODEL_DIR = Path("assets/models_e5small")
ONNX_PATH = MODEL_DIR / "encoder_e5small.onnx"
TFLITE_PATH = MODEL_DIR / "encoder_e5small_dynamic_quant.tflite"


def cosine(a, b):
    a = a.reshape(-1).astype(np.float32)
    b = b.reshape(-1).astype(np.float32)
    return float(np.dot(a, b) / ((np.linalg.norm(a) * np.linalg.norm(b)) + 1e-9))


def run_onnx(encoded):
    session = ort.InferenceSession(str(ONNX_PATH), providers=["CPUExecutionProvider"])
    inputs = {
        "input_ids": encoded["input_ids"].astype(np.int64),
        "attention_mask": encoded["attention_mask"].astype(np.int64),
    }
    return session.run(None, inputs)[0]


def run_tflite(encoded):
    interpreter = tf.lite.Interpreter(model_path=str(TFLITE_PATH))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    for i, inp in enumerate(input_details):
        name = inp["name"].lower()

        if "input_ids" in name or i == 0:
            value = encoded["input_ids"]
        elif "attention_mask" in name or "mask" in name or i == 1:
            value = encoded["attention_mask"]
        else:
            raise RuntimeError(f"Unknown input: {inp['name']}")

        interpreter.set_tensor(inp["index"], value.astype(inp["dtype"]))

    interpreter.invoke()
    return interpreter.get_tensor(output_details[0]["index"])


def main():
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)

    queries = [
        "query: dawa ya kikohozi",
        "query: maumivu ya tumbo na gesi",
        "query: natural remedy for fever",
        "query: kidney problems",
    ]

    for q in queries:
        encoded = tokenizer(
            q,
            padding="max_length",
            truncation=True,
            max_length=128,
            return_tensors="np",
        )

        onnx_out = run_onnx(encoded)
        tflite_out = run_tflite(encoded)

        sim = cosine(onnx_out, tflite_out)

        print("\nQuery:", q)
        print("ONNX shape:", onnx_out.shape)
        print("TFLite shape:", tflite_out.shape)
        print("Cosine similarity:", sim)


if __name__ == "__main__":
    main()