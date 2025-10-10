# Natural Remedies (Afya Bomba)

A bilingual (English/Swahili), offline-first Flutter app that helps users explore natural remedies and wellness tips — fast search, clean UI, and concise, trustworthy content.

## ✨ Features
- 🔎 Smart search for symptoms & topics (EN + SW)
- 🌓 Light/Dark theme support
- 📦 Offline content bundled with the app
- 🌍 Fully localized content (English & Swahili)
- 🔒 No sign-in, no tracking, no ads

## 📸 Screenshots
_Add your screenshots here: `screenshots/01.png` …_

## 🛠️ Tech
- Flutter, Dart
- JSON content (offline assets)
- Android release builds with Gradle

## 🌐 Localization
- Article fields stored as bilingual JSON: { "en": "...", "sw": "..." }

- See /tools/ scripts to export/import content for review

## ⚠️ Disclaimer
This app is informational only and not a substitute for professional medical advice. Always consult a qualified healthcare provider.

## 📜 License
Copyright (c) 2025 [George Odongo / NM-AIST]

All rights reserved.

This software and its source code are proprietary and confidential.
You may download, install, and use the application solely for personal
evaluation and testing purposes as authorized by the developer.

Except as expressly permitted in writing, you may not copy, modify,
merge, publish, distribute, sublicense, sell, or create derivative
works of this software or any part thereof.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

For commercial use or production deployment, a separate written license
agreement with the developer is required.

## 🚀 Build
```bash
flutter clean
flutter pub get
flutter run
# Release APKs:
flutter build apk --release --split-per-abi
# or Gradle:
cd android && .\gradlew assembleRelease

