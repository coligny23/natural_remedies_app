from pathlib import Path
import numpy as np
import tensorflow as tf
from transformers import AutoTokenizer


MODEL_DIR = Path("assets/models_e5small")
TFLITE_PATH = MODEL_DIR / "encoder_e5small_dynamic_quant.tflite"


def l2_normalize(x, eps=1e-9):
    x = np.asarray(x, dtype=np.float32)
    return x / (np.linalg.norm(x) + eps)


def main():
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)

    encoded = tokenizer(
        "query: dawa ya kikohozi",
        padding="max_length",
        truncation=True,
        max_length=128,
        return_tensors="np",
    )

    interpreter = tf.lite.Interpreter(model_path=str(TFLITE_PATH))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("Inputs:")
    for i, inp in enumerate(input_details):
        print(i, inp["name"], inp["shape"], inp["dtype"])

    print("\nOutputs:")
    for i, out in enumerate(output_details):
        print(i, out["name"], out["shape"], out["dtype"])

    for i, inp in enumerate(input_details):
        name = inp["name"].lower()

        if "input_ids" in name or i == 0:
            value = encoded["input_ids"]
        elif "attention_mask" in name or "mask" in name or i == 1:
            value = encoded["attention_mask"]
        else:
            raise RuntimeError(f"Unknown input: {inp['name']}")

        value = value.astype(inp["dtype"])
        interpreter.set_tensor(inp["index"], value)

    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]["index"])
    print("\nOutput shape:", output.shape)
    print("Output dtype:", output.dtype)
    print("First 10 values:", output.reshape(-1)[:10])

    if output.shape == (1, 384):
        print("SUCCESS: TFLite model outputs a 384-dimensional embedding.")
    else:
        print("WARNING: Unexpected output shape.")

    norm = np.linalg.norm(output.reshape(-1))
    print("Embedding norm:", norm)


if __name__ == "__main__":
    main()