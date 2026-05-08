from pathlib import Path
import onnx
from onnx_tf.backend import prepare


ONNX_PATH = Path("assets/models_e5small/encoder_e5small.onnx")
TF_OUT = Path("assets/models_e5small/tf_saved_model")


def main():
    if not ONNX_PATH.exists():
        raise FileNotFoundError(f"Missing ONNX model: {ONNX_PATH}")

    print(f"Loading ONNX model: {ONNX_PATH}")
    onnx_model = onnx.load(str(ONNX_PATH))

    print("Preparing TensorFlow representation...")
    tf_rep = prepare(onnx_model)

    TF_OUT.mkdir(parents=True, exist_ok=True)

    print(f"Exporting SavedModel to: {TF_OUT}")
    tf_rep.export_graph(str(TF_OUT))

    print("Done.")


if __name__ == "__main__":
    main()