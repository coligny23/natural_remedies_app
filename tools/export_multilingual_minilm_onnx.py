import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModel


MODEL_ID = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
OUT_DIR = Path("assets/models_multilingual")
ONNX_OUT = OUT_DIR / "multilingual_minilm_l12_v2.onnx"
MAX_LEN = 128


class MeanPoolingEncoder(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        token_embeddings = outputs.last_hidden_state

        mask = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        summed = torch.sum(token_embeddings * mask, dim=1)
        counts = torch.clamp(mask.sum(dim=1), min=1e-9)

        embeddings = summed / counts
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)

        return embeddings


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading tokenizer and model: {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModel.from_pretrained(MODEL_ID)
    model.eval()

    wrapped = MeanPoolingEncoder(model)
    wrapped.eval()

    sample = tokenizer(
        "This is a multilingual semantic search test.",
        padding="max_length",
        truncation=True,
        max_length=MAX_LEN,
        return_tensors="pt",
    )

    input_ids = sample["input_ids"].to(torch.long)
    attention_mask = sample["attention_mask"].to(torch.long)

    print(f"Exporting ONNX to: {ONNX_OUT}")

    torch.onnx.export(
        wrapped,
        (input_ids, attention_mask),
        str(ONNX_OUT),
        input_names=["input_ids", "attention_mask"],
        output_names=["embeddings"],
        dynamic_axes=None,
        opset_version=17,
    )

    tokenizer.save_pretrained(OUT_DIR)

    print("Done.")
    print(f"ONNX model: {ONNX_OUT}")
    print(f"Tokenizer files saved to: {OUT_DIR}")


if __name__ == "__main__":
    main()