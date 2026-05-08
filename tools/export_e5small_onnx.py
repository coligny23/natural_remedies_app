import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModel


MODEL_ID = "intfloat/multilingual-e5-small"
OUT_DIR = Path("assets/models_e5small")
ONNX_OUT = OUT_DIR / "encoder_e5small.onnx"
MAX_LEN = 128


class E5Encoder(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def average_pool(self, last_hidden_states, attention_mask):
        last_hidden = last_hidden_states.masked_fill(
            ~attention_mask[..., None].bool(),
            0.0
        )
        return last_hidden.sum(dim=1) / attention_mask.sum(dim=1)[..., None]

    def forward(self, input_ids, attention_mask):
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        embeddings = self.average_pool(outputs.last_hidden_state, attention_mask)
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        return embeddings


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading model: {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval()

    encoder = E5Encoder(model)
    encoder.eval()

    sample = tokenizer(
        "query: natural remedy for cough",
        padding="max_length",
        truncation=True,
        max_length=MAX_LEN,
        return_tensors="pt",
    )

    input_ids = sample["input_ids"].to(torch.long)
    attention_mask = sample["attention_mask"].to(torch.long)

    print(f"Exporting ONNX to: {ONNX_OUT}")

    torch.onnx.export(
        encoder,
        (input_ids, attention_mask),
        str(ONNX_OUT),
        input_names=["input_ids", "attention_mask"],
        output_names=["embeddings"],
        opset_version=17,
        dynamic_axes=None,
    )

    tokenizer.save_pretrained(OUT_DIR)

    print("Done.")
    print(f"ONNX model: {ONNX_OUT}")
    print(f"Tokenizer files saved to: {OUT_DIR}")


if __name__ == "__main__":
    main()