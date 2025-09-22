# 🌿 Natural Remedies — Offline Mobile Learning Tool

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-7F52FF.svg)](https://riverpod.dev)
[![Offline-first](https://img.shields.io/badge/Architecture-Offline--first-2ea44f.svg)](#architecture)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20Web-lightgrey.svg)](#run)
[![License](https://img.shields.io/badge/License-Choose%20one-informational.svg)](#license)

An **offline-first** learning app that helps users **search** and **learn** about natural remedies in **English** and **Swahili**. Content is embedded in the app as JSON and will later be complemented by an **on-device ML (TFLite)** model for semantic QA.

> ⚠️ **Disclaimer:** Educational resource only. Not medical advice. Always consult a qualified health professional.

---

## ✨ Features

* 🔍 **Instant offline search**
* 📚 Curated **Principles**, **Herbs**, and **Conditions** content
* 🇬🇧/🇹🇿 **Bilingual** (EN / SW) with graceful fallback
* 💾 **Local assets** + future Hive caching for bookmarks
* 🧭 **Tabbed UI** with GoRouter deep links (`/?tab=2` → Search)
* 🧠 **Pipeline** to convert PDFs → curated JSON → (optional) SW translations

---

## 🧱 Architecture

```
Flutter (Material3 + Cupertino)
 ├─ GoRouter tabs: Home | Learn | Search | Saved | Settings
 ├─ Riverpod state: language, content, search
 ├─ Assets: /assets/corpus/{en,sw}/sample.json
 └─ (Planned) TFLite on-device reasoning via tflite_flutter

Data Pipeline (Python, local)
 ├─ PDF → curated extraction (principles/herbs/conditions)
 ├─ EN JSON → SW JSON (local HF translation models)
 └─ Emits en_chunks_curated.json → app asset packs
```

---

## 📁 Project Structure (key parts)

```
natural_remedies_app/
├─ lib/
│  ├─ app/
│  │  ├─ routing/app_router.dart
│  │  └─ theme/app_theme.dart
│  ├─ features/
│  │  ├─ home/home_screen.dart
│  │  ├─ learn/learn_screen.dart
│  │  ├─ search/
│  │  │  ├─ search_page.dart
│  │  │  └─ search_providers.dart
│  │  ├─ saved/saved_screen.dart
│  │  ├─ settings/settings_screen.dart
│  │  └─ content/
│  │     ├─ models/content_item.dart
│  │     └─ data/
│  │        ├─ content_repository.dart
│  │        └─ content_repository_assets.dart
├─ assets/
│  └─ corpus/
│     ├─ en/sample.json
│     └─ sw/sample.json
└─ data-pipeline/  (local only; not committed)
   ├─ extract_curated_v2.py
   ├─ translate_sw_hf_resumable.py
   ├─ NaturalRemediesEncyclopedia.pdf
   └─ .venv/  (ignored)
```

---

## 🚀 Quick Start

### Prerequisites

* **Flutter 3.x** (Android toolchain set up)
* **Android Studio** (SDK + cmdline tools) or Chrome for Web
* (Optional) **Python 3.11+** if you’ll run the data pipeline locally

### 1) Clone & install

```bash
git clone https://github.com/coligny23/natural_remedies_app.git
cd natural_remedies_app
flutter pub get
```

### 2) Assets

Place your curated samples here (keep them small for dev):

```
assets/corpus/en/sample.json
assets/corpus/sw/sample.json   # optional
```

Ensure `pubspec.yaml` includes:

```yaml
flutter:
  assets:
    - assets/corpus/
```

### 3) Run <a id="run"></a>

**Android emulator:**

```bash
flutter run
```

**Web (Chrome):**

```bash
flutter run -d chrome
```

> If Chrome/OS is in dark mode and your app looks unreadable, force light in `main.dart` via `themeMode: ThemeMode.light` or add a theme toggle in Settings.

---

## 🔎 Day 4: Offline Search (what’s in place)

* **Search UI**: `features/search/search_page.dart`
* **State**: `search_providers.dart` with `contentListProvider`, `searchQueryProvider`, `searchResultsProvider`
* **Repo**: `AssetsContentRepository` loads JSON from assets and serves basic string-match filtering
* **DoD**: Searching for **“ginger”** returns results instantly, offline

---

## 🧪 Sample Content Schema

Each item is a compact “card” used for search and display:

```json
{
  "id": "herb:Ginger#uses",
  "type": "chunk",
  "section": "herb",
  "facet": "uses",
  "title": "Ginger — Uses",
  "content_en": "Ginger is used for ...",
  "content_sw": "Tangawizi hutumika kwa ...",
  "lang_original": "en",
  "translation_status": "machine",
  "tags": ["herb"],
  "page_range": [45, 46],
  "source": "Natural Remedies Encyclopedia (PDF)"
}
```

> Use **EN** only to begin; add **SW** later (the app gracefully falls back to English).

---

## 🛠 Data Pipeline (Optional, local only)

> Keep these outputs **out of Git** (`.gitignore` includes `.venv`, models, and PDFs).

1. Create a virtual environment and install packages:

```bash
cd data-pipeline
python -m venv .venv
# Windows PowerShell:
.\.venv\Scripts\Activate
pip install -U pip
pip install pdfplumber transformers torch
```

2. **Extract curated** content from the PDF:

```bash
# Ensure NaturalRemediesEncyclopedia.pdf is in data-pipeline/
python extract_curated_v2.py
# emits structured_extracted.json and en_chunks_curated.json
```

3. **Translate to Swahili** (if you added local HF models):

```bash
python translate_sw_hf_resumable.py --in en_chunks_curated.json --out en_sw_chunks_curated.json --resume
```

4. Copy a **small subset** of the JSON into:

```
assets/corpus/en/sample.json
assets/corpus/sw/sample.json
```

---

## 🌐 Routing & Tabs

* **Root Tabs**: `/?tab=0..4` for Home | Learn | Search | Saved | Settings
* **Deep links**:

  * `/search` → `/?tab=2`
  * `/article/:id` → Article detail (stub)

Configured in `lib/app/routing/app_router.dart`.

---

## 🧩 Tech Stack

* **Flutter** (Material 3 + Cupertino)
* **Riverpod** for state
* **GoRouter** for navigation
* **Hive** (planned) for bookmarks & local cache
* **tflite\_flutter** (planned) for on-device model inference
* **Python** data-pipeline (pdfplumber, transformers)

---

## 🗺️ Roadmap

* [x] App shell + tabs + theming
* [x] Offline search over local assets (Day 4)
* [ ] Detail views for Herbs & Conditions with collapsible subsections
* [ ] Bookmarks (Hive)
* [ ] Highlight search matches
* [ ] TFLite model for semantic Q\&A (offline)
* [ ] Evaluation & instrumentation for learning outcomes
* [ ] Content packs & simple update mechanism

---

## 🤝 Contributing

1. Fork and create a feature branch.
2. Keep commits focused and small.
3. Run `flutter analyze` & ensure the app builds for Android/Web.
4. Open a PR with a clear description.

**Please do not** commit:

* `data-pipeline/.venv/`, PDFs, or model binaries
* Any files over 50MB

---

## 📜 License
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)


MIT License

Copyright (c) 2025 George Odongo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


---

## 🙏 Acknowledgements

* **Natural Remedies Encyclopedia** (as the primary content source for curation)
* Open-source communities behind Flutter, Riverpod, GoRouter, pdfplumber, and Hugging Face models

---

