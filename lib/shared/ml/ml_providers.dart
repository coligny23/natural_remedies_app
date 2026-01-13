// lib/shared/ml/ml_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'index_loader.dart';
import 'vector_math.dart';
import 'profile_repository.dart';
import '../../features/settings/feature_flags.dart'; // useTfliteProvider (your existing flag)
import '../../features/search/search_providers.dart'; // languageCodeProvider (if you want to localize later)

/// Load the embeddings index (vectors + meta) from assets.
final embeddingIndexProvider = FutureProvider<EmbeddingIndex>((ref) async {
  // If you want to gate loading behind the flag, you can:
  // final useTfl = ref.watch(useTfliteProvider);
  // if (!useTfl) throw 'Semantic index disabled (toggle in Settings)';
  return loadIndex();
});

/// DAY-3 TEMP: a stub text embedder so UI can be wired before the real model lands.
/// Very fast "bag-of-chars % dim" projection + L2 normalize.
final _dimProvider = Provider<int>((_) => 384);

List<double> _stubEmbed(String text, int dim) {
  final v = List<double>.filled(dim, 0.0, growable: false);
  final len = text.length;
  for (var i = 0; i < len; i++) {
    // Simple folding of characters into bins
    v[i % dim] += (text.codeUnitAt(i) % 31) / 31.0;
  }
  // L2 normalize
  final norm = l2F32(v);
  final inv = 1.0 / (norm + 1e-9);
  for (var i = 0; i < dim; i++) {
    v[i] *= inv;
  }
  return v;
}

/// Public provider to embed a piece of text (stub today; TFLite tomorrow).
final embedTextProvider = Provider.family<List<double>, String>((ref, text) {
  final d = ref.watch(_dimProvider);
  return _stubEmbed(text, d);
});

/// Main: semantic search over the loaded index. Returns the top-K meta rows.
/// Gated by your "Use experimental ML engine (TFLite)" toggle for safety UX.
final semanticSearchProvider = FutureProvider.family<List<IndexRow>, String>((ref, query) async {
  final useTfl = ref.watch(useTfliteProvider);
  if (!useTfl) return []; // switch off → no results (keeps UX predictable)

  final q = query.trim();
  if (q.isEmpty) return [];

  final idx = await ref.watch(embeddingIndexProvider.future);
  final qv = ref.read(embedTextProvider(q));

  final top = topKCosineF32(qv, idx.vecs, k: 10);
  return [for (final i in top) idx.meta[i]];
});

/// Profile vector (EMA style) — loaded from Hive. Day 4/5 will update this.
final profileRepoProvider = Provider((_) => ProfileRepo());

final profileVecProvider = FutureProvider<List<double>?>((ref) async {
  final repo = ref.read(profileRepoProvider);
  await repo.init();
  return repo.readVec();
});
