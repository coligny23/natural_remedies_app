import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_qa_engine.dart';
import 'local_qa_stub.dart';
// Conditional: web → *web stub*, IO → real tflite
import 'local_qa_tflite_web.dart'
    if (dart.library.io) 'local_qa_tflite_io.dart';

import '../../features/search/search_providers.dart';
import '../../features/settings/feature_flags.dart';
import '../../features/content/models/content_item.dart';

final qaEngineProvider = Provider<LocalQaEngine>((ref) {
  final useTflite = ref.watch(useTfliteProvider);
  if (kIsWeb) return LocalQaStub(); // double-safety for web
  return useTflite ? LocalQaTflite() : LocalQaStub();
});

final qaInitProvider = FutureProvider<void>((ref) async {
  final items = await ref.watch(contentListProvider.future);
  final lang  = ref.watch(languageCodeProvider);
  final engine = ref.read(qaEngineProvider);
  await engine.init(corpus: items, lang: lang);
});

final qaAnswerProvider = FutureProvider.family<QaAnswer, String>((ref, q) async {
  await ref.watch(qaInitProvider.future);
  final engine = ref.read(qaEngineProvider);

  final query = q.trim();
  if (query.isEmpty) return const QaAnswer(text: '');

  // Retrieve top-K best candidates via fastSearch
  const k = 3;
  final hits = await ref.read(fastSearchProvider(query).future);
  final shortlist = hits.take(k).toList(growable: false);

  return engine.answer(query, shortlist: shortlist);
});
