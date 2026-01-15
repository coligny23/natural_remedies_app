# tools/onnx_to_tflite.py
import os, shutil
import onnx
from onnx_tf.backend import prepare
import tensorflow as tf

# --- paths (update to match your project layout) ---
ONNX_PATH   = "assets/models/minilm_l6_v2.onnx"   # ← exported in the previous step
SM_DIR_RAW  = "tools/saved_minilm_raw"           # temporary SavedModel from onnx-tf
SM_DIR_WRAP = "tools/saved_minilm_wrap"          # wrapper SavedModel (int32 inputs)
TFLITE_OUT  = "assets/models/encoder.tflite"     # final TFLite encoder

def export_onnx_to_savedmodel():
    print(f"[1/3] Loading ONNX: {ONNX_PATH}")
    onnx_model = onnx.load(ONNX_PATH)
    print("[1/3] Converting ONNX → TF (SavedModel) via onnx-tf...")
    tf_rep = prepare(onnx_model)  # onnx-tf must support your opset (17+ ideal)

    if os.path.exists(SM_DIR_RAW):
        shutil.rmtree(SM_DIR_RAW)
    tf_rep.export_graph(SM_DIR_RAW)
    print(f"[1/3] Saved TF model → {SM_DIR_RAW}")

def build_int32_wrapper():
    """
    Wrap the SavedModel so inputs are int32 (good for TFLite) but we cast to int64
    before calling the original model function.
    """
    print("[2/3] Wrapping SavedModel with int32 input signature...")
    raw = tf.saved_model.load(SM_DIR_RAW)

    # Try to find a callable signature
    # Many onnx-tf exports expose 'serving_default'.
    # You can inspect raw.signatures.keys() if needed.
    if 'serving_default' not in raw.signatures:
        # Fallback: if your export used a different concrete function name,
        # print available keys:
        print("Available signatures:", list(raw.signatures.keys()))
        raise RuntimeError("Could not find 'serving_default' in SavedModel signatures.")
    f = raw.signatures['serving_default']

    class Wrapper(tf.Module):
        def __init__(self, fn):
            super().__init__()
            self.fn = fn

        @tf.function(input_signature=[
            tf.TensorSpec([None, None], tf.int32, name="input_ids"),
            tf.TensorSpec([None, None], tf.int32, name="attention_mask"),
        ])
        def __call__(self, input_ids, attention_mask):
            # cast int32 → int64 for the original function
            outs = self.fn(
                input_ids=tf.cast(input_ids, tf.int64),
                attention_mask=tf.cast(attention_mask, tf.int64)
            )
            # Standardize output key; many exports use 'embeddings' already
            # If your key differs, print(outs.keys()) and adjust here.
            if isinstance(outs, dict):
                # pick the first key deterministically if unknown
                key = next(iter(outs.keys()))
                y = tf.cast(outs[key], tf.float32)
                return {"embeddings": y}
            else:
                y = tf.cast(outs, tf.float32)
                return {"embeddings": y}

    wrap = Wrapper(f)

    if os.path.exists(SM_DIR_WRAP):
        shutil.rmtree(SM_DIR_WRAP)
    tf.saved_model.save(wrap, SM_DIR_WRAP)
    print(f"[2/3] Saved wrapper SavedModel → {SM_DIR_WRAP}")

def convert_savedmodel_to_tflite():
    print("[3/3] Converting SavedModel → TFLite (dynamic-range quant)...")
    conv = tf.lite.TFLiteConverter.from_saved_model(SM_DIR_WRAP)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]

    # Allow TF fallback ops if needed (common for transformer graphs)
    conv.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]

    tfl = conv.convert()
    os.makedirs(os.path.dirname(TFLITE_OUT), exist_ok=True)
    with open(TFLITE_OUT, "wb") as f:
        f.write(tfl)
    kb = os.path.getsize(TFLITE_OUT) / 1024.0
    print(f"[3/3] Wrote {TFLITE_OUT} ({kb:.1f} KB)")

if __name__ == "__main__":
    export_onnx_to_savedmodel()
    build_int32_wrapper()
    convert_savedmodel_to_tflite()
    print("Done.")
