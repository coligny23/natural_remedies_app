---
license: mit
---

# Model Card for Model ID

<!-- Provide a quick summary of what the model is/does. -->

This is a pre-trained language translation model that aims to create a translation system for English and Swahili lanuages. It is a fine-tuned version of Helsinki-NLP/opus-mt-en-swc on an unknown dataset. 

## Model Details

- Transformer architecture used
- Trained on a 210000 corpus pairs
- Pre-trained Helsinki-NLP/opus-mt-en-swc
- 2 models to enforce biderectional translation
### Model Description

<!-- Provide a longer summary of what this model is. -->



- **Developed by:** Peter Rogendo, Frederick Kioko
- **Model type:** Transformer
- **Language(s) (NLP):** Transformer, Pandas, Numpy
- **License:** Distributed under the MIT License
- **Finetuned from model [Helsinki-NLP/opus-mt-en-swc]:** [This pre-trained model was re-trained on a swahili-english sentence pairs that were collected across Kenya. Swahili is the national language and is among the top three of the most spoken language in Africa. The sentences that were used to train this model were 210000 in total.]

### Model Sources [optional]

<!-- Provide the basic links for the model. -->

- **Repository:** [https://github.com/Rogendo/Eng-Swa-Translator]
- **Paper [optional]:** 
- **Demo [optional]:** 

## Uses

<!-- Address questions around how the model is intended to be used, including the foreseeable users of the model and those affected by the model. -->
This translation model is intended to be used in many cases, from language translators, screen assistants, to even in official cases such as translating legal documents.

### Direct Use

<!-- This section is for the model use without fine-tuning or plugging into a larger ecosystem/app. -->

# Use a pipeline as a high-level helper

        from transformers import pipeline
        
        pipe = pipeline("text2text-generation", model="Rogendo/sw-en")

# Load model directly

        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        
        tokenizer = AutoTokenizer.from_pretrained("Rogendo/sw-en")
        model = AutoModelForSeq2SeqLM.from_pretrained("Rogendo/sw-en")

### Downstream Use [optional]

<!-- This section is for the model use when fine-tuned for a task, or when plugged into a larger ecosystem/app -->

[More Information Needed]

### Out-of-Scope Use

<!-- This section addresses misuse, malicious use, and uses that the model will not work well for. -->

[More Information Needed]

## Bias, Risks, and Limitations

<!-- This section is meant to convey both technical and sociotechnical limitations. -->

[More Information Needed]

### Recommendations

<!-- This section is meant to convey recommendations with respect to the bias, risk, and technical limitations. -->

Users (both direct and downstream) should be made aware of the risks, biases and limitations of the model. More information needed for further recommendations.

## How to Get Started with the Model

# Use a pipeline as a high-level helper

        from transformers import pipeline
        
        pipe = pipeline("text2text-generation", model="Rogendo/sw-en")

# Load model directly

        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        
        tokenizer = AutoTokenizer.from_pretrained("Rogendo/sw-en")
        model = AutoModelForSeq2SeqLM.from_pretrained("Rogendo/sw-en")



## Training Details

### Training Data

<!-- This should link to a Dataset Card, perhaps with a short stub of information on what the training data is all about as well as documentation related to data pre-processing or additional filtering. -->
curl -X GET \
     "https://datasets-server.huggingface.co/rows?dataset=Rogendo%2FEnglish-Swahili-Sentence-Pairs&config=default&split=train&offset=0&length=100"
     
View More
      https://huggingface.co/datasets/Rogendo/English-Swahili-Sentence-Pairs



### Training Procedure

<!-- This relates heavily to the Technical Specifications. Content here should link to that section when it is relevant to the training procedure. -->

#### Preprocessing [optional]

[More Information Needed]


#### Training Hyperparameters

- **Training regime:** [More Information Needed] <!--fp32, fp16 mixed precision, bf16 mixed precision, bf16 non-mixed precision, fp16 non-mixed precision, fp8 mixed precision -->

#### Speeds, Sizes, Times [optional]

<!-- This section provides information about throughput, start/end time, checkpoint size if relevant, etc. -->

[More Information Needed]

## Evaluation

<!-- This section describes the evaluation protocols and provides the results. -->

### Testing Data, Factors & Metrics

#### Testing Data

<!-- This should link to a Dataset Card if possible. -->

[More Information Needed]

#### Factors

<!-- These are the things the evaluation is disaggregating by, e.g., subpopulations or domains. -->

[More Information Needed]

#### Metrics

<!-- These are the evaluation metrics being used, ideally with a description of why. -->

[More Information Needed]

### Results

[More Information Needed]

#### Summary



## Model Examination [optional]

<!-- Relevant interpretability work for the model goes here -->

[More Information Needed]

## Environmental Impact

<!-- Total emissions (in grams of CO2eq) and additional considerations, such as electricity usage, go here. Edit the suggested text below accordingly -->

Carbon emissions can be estimated using the [Machine Learning Impact calculator](https://mlco2.github.io/impact#compute) presented in [Lacoste et al. (2019)](https://arxiv.org/abs/1910.09700).

- **Hardware Type:** [More Information Needed]
- **Hours used:** [More Information Needed]
- **Cloud Provider:** [More Information Needed]
- **Compute Region:** [More Information Needed]
- **Carbon Emitted:** [More Information Needed]

## Technical Specifications [optional]

### Model Architecture and Objective

[More Information Needed]

### Compute Infrastructure

[More Information Needed]

#### Hardware

[More Information Needed]

#### Software

[More Information Needed]

## Citation [optional]

<!-- If there is a paper or blog post introducing the model, the APA and Bibtex information for that should go in this section. -->

**BibTeX:**

[More Information Needed]

**APA:**

[More Information Needed]

## Glossary [optional]

<!-- If relevant, include terms and calculations in this section that can help readers understand the model or model card. -->


## Model Card Authors [optional]

Peter Rogendo
## Model Card Contact

progendo@kabarak.ac.ke