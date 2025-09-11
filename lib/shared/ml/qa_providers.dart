// lib/shared/ml/qa_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_qa_engine.dart';
import 'local_qa_stub.dart';                          // <-- use the stub
import '../../features/search/search_providers.dart'; // contentListProvider, languageCodeProvider

/// Engine selector — swap to LocalQaTflite later when ready.
final qaEngineProvider = Provider<LocalQaEngine>((_) => LocalQaStub());

/// Initialize the engine when content/language are ready.
final qaInitProvider = FutureProvider<void>((ref) async {
  final items = await ref.watch(contentListProvider.future);
  final lang = ref.watch(languageCodeProvider);
  final engine = ref.read(qaEngineProvider);
  await engine.init(corpus: items, lang: lang);
});

/// Ask a question; waits for init first.
final qaAnswerProvider = FutureProvider.family<QaAnswer, String>((ref, query) async {
  await ref.watch(qaInitProvider.future);
  final engine = ref.read(qaEngineProvider);
  return engine.answer(query);
});
