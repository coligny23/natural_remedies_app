import 'package:flutter/foundation.dart' show kIsWeb;

import '../ml/local_qa_engine.dart';
import '../ml/local_qa_stub.dart';
import '../../features/content/models/content_item.dart';

/// Placeholder TFLite-backed engine. For now it delegates to the stub,
/// but keeps a separate class so swapping internals later is easy.
class LocalQaTflite implements LocalQaEngine {
  final LocalQaStub _fallback = LocalQaStub();

  @override
  Future<void> init({required List<ContentItem> corpus, required String lang}) async {
    // Guard web builds (no tflite there)
    if (kIsWeb) {
      await _fallback.init(corpus: corpus, lang: lang);
      return;
    }
    // TODO (Day 11/12): load assets/ml/model.tflite, tokenizer, build index
    await _fallback.init(corpus: corpus, lang: lang);
  }

  @override
  Future<QaAnswer> answer(String query) async {
    // TODO: run real TFLite inference later; for now delegate
    return _fallback.answer(query);
  }
}
