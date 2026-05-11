from pathlib import Path
import tensorflow as tf

SAVED_MODEL_DIR = Path("assets/models_e5small/tf_saved_model")
TFLITE_OUT = Path("assets/models_e5small/encoder_e5small.tflite")

def main():
    converter = tf.lite.TFLiteConverter.from_saved_model(str(SAVED_MODEL_DIR))

    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]

    converter.experimental_enable_resource_variables = True

    tflite_model = converter.convert()

    TFLITE_OUT.write_bytes(tflite_model)

    print("TFLite model written to:", TFLITE_OUT)
    print("Size:", TFLITE_OUT.stat().st_size, "bytes")

if __name__ == "__main__":
    main()