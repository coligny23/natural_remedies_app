import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:natural_remedies_app/features/content/data/content_providers.dart';

import 'e5_assets.dart';
import 'e5_search_result.dart';
import 'e5_semantic_search_engine.dart';
import '../search_providers.dart' show languageCodeProvider;



final e5SearchEngineProvider =
    FutureProvider.autoDispose<E5SemanticSearchEngine>((ref) async {
  final lang = ref.watch(languageCodeProvider);

  final engine = E5SemanticSearchEngine();

  await engine.init(
    modelPath: E5Assets.model,
    indexPath: lang == 'sw' ? E5Assets.indexSw : E5Assets.indexEn,
    metaPath: lang == 'sw' ? E5Assets.metaSw : E5Assets.metaEn,
  );

  ref.onDispose(engine.close);

  return engine;
});

final e5SearchResultsProvider =
    FutureProvider.autoDispose.family<List<E5SearchResult>, String>(
  (ref, query) async {
    final lang = ref.watch(languageCodeProvider);
    final engine = await ref.watch(e5SearchEngineProvider.future);

    return engine.search(
      query,
      topK: 10,
      topN: 50,
      lexicalWeight: lang == 'sw' ? 0.08 : 0.0,
    );
  },
);
