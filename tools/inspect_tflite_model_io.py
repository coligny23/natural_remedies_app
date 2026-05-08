#!/usr/bin/env python3
"""
inspect_tflite_model_io.py

Prints TFLite input/output names, shapes, and dtypes.
Run:
  python tools/inspect_tflite_model_io.py
"""

from pathlib import Path


def load_interpreter(model_path):
    try:
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
    except Exception:
        from tflite_runtime.interpreter import Interpreter
        interpreter = Interpreter(model_path=str(model_path))

    interpreter.allocate_tensors()
    return interpreter


def main():
    model_path = Path("assets/models/encoder.tflite")

    if not model_path.exists():
        raise FileNotFoundError(f"Missing model: {model_path}")

    interpreter = load_interpreter(model_path)

    print("\nTFLite Model IO")
    print("---------------")
    print(f"Model: {model_path}")
    print(f"Size: {model_path.stat().st_size:,} bytes")

    print("\nInputs:")
    for i, inp in enumerate(interpreter.get_input_details()):
        print(f"{i}: name={inp['name']} shape={inp['shape']} dtype={inp['dtype']} index={inp['index']}")

    print("\nOutputs:")
    for i, out in enumerate(interpreter.get_output_details()):
        print(f"{i}: name={out['name']} shape={out['shape']} dtype={out['dtype']} index={out['index']}")


if __name__ == "__main__":
    main()
