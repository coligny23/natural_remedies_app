import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_qa_engine.dart';
import 'local_qa_stub.dart';
import 'local_qa_tflite.dart';                 // <-- add
import '../../features/search/search_providers.dart';
import '../../features/settings/feature_flags.dart'; // <-- add

/// Engine selector — defaults to Stub; switchable in Settings.
final qaEngineProvider = Provider<LocalQaEngine>((ref) {
  final useTflite = ref.watch(useTfliteProvider);
  return useTflite ? LocalQaTflite() : LocalQaStub();
});

/// Initialize engine when content/language are ready
final qaInitProvider = FutureProvider<void>((ref) async {
  final items = await ref.watch(contentListProvider.future);
  final lang = ref.watch(languageCodeProvider);
  final engine = ref.read(qaEngineProvider);
  await engine.init(corpus: items, lang: lang);
});

/// Ask a question; waits for init first
final qaAnswerProvider = FutureProvider.family<QaAnswer, String>((ref, query) async {
  await ref.watch(qaInitProvider.future);
  final engine = ref.read(qaEngineProvider);
  return engine.answer(query);
});
