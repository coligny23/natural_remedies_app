// lib/shared/ml/ml_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'index_loader.dart';          // loadIndex(), EmbeddingIndex, IndexRow
import 'vector_math.dart';           // cosineF32, topKCosineF32
import 'profile_repository.dart';    // ProfileRepo
import '../../features/settings/feature_flags.dart'; // useTfliteProvider
import '../../features/search/search_providers.dart'; // languageCodeProvider (if you localize later)

// ✅ Use the real embedder (with internal fallback) from minilm_embedder.dart
import '../../shared/ml/embedder/minilm_embedder.dart' as embed;

/// Load the embeddings index (vectors + meta) from assets.
/// You can optionally gate this behind the feature flag if you want.
final embeddingIndexProvider = FutureProvider<EmbeddingIndex>((ref) async {
  // final useTfl = ref.watch(useTfliteProvider);
  // if (!useTfl) throw 'Semantic index disabled (toggle in Settings)';
  return loadIndex();
});

/// Main: semantic search over the loaded index. Returns the top-K meta rows.
/// Gated by your "Use experimental ML engine (TFLite)" toggle for predictable UX.
final semanticSearchProvider =
    FutureProvider.family<List<IndexRow>, String>((ref, query) async {
  final useTfl = ref.watch(useTfliteProvider);
  if (!useTfl) return const <IndexRow>[];

  final q = query.trim();
  if (q.isEmpty) return const <IndexRow>[];

  final idx = await ref.watch(embeddingIndexProvider.future);

  // Embed the query (minilm_embedder has a safe stub fallback until interpreter is ready)
  final qv = ref.read(embed.embedTextProvider(q));

  final top = topKCosineF32(qv, idx.vecs, k: 10);
  return [for (final i in top) idx.meta[i]];
});

/// Profile vector (EMA style) — loaded from Hive. (Updated by ContentDetailScreen)
final profileRepoProvider = Provider((_) => ProfileRepo());

final profileVecProvider = FutureProvider<List<double>?>((ref) async {
  final repo = ref.read(profileRepoProvider);
  await repo.init();
  return repo.readVec();
});

/// Return semantic scores as a map {id -> cosine [0..1]} for the given query.
/// Gated by the feature flag.
final semanticScoresProvider =
    FutureProvider.family<Map<String, double>, String>((ref, query) async {
  final useTfl = ref.watch(useTfliteProvider);
  if (!useTfl) return const {};

  final q = query.trim();
  if (q.isEmpty) return const {};

  final idx = await ref.watch(embeddingIndexProvider.future);
  final qv = ref.read(embed.embedTextProvider(q));

  // Compute cosine scores (brute force) — cap to top 200 to keep merge small
  final scores = <String, double>{};
  for (var i = 0; i < idx.n; i++) {
    final cos = cosineF32(qv, idx.vecs[i]).clamp(0.0, 1.0);
    scores[idx.meta[i].id] = cos;
  }

  final entries = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final capped = entries.take(200);
  return {for (final e in capped) e.key: e.value};
});

/// "For You" IDs derived from profile vector (EMA-updated elsewhere).
/// Returns top N IDs by cosine(profile, item).
final forYouIdsProvider = FutureProvider<List<String>>((ref) async {
  final useTfl = ref.watch(useTfliteProvider);
  if (!useTfl) return const <String>[];

  final profile = await ref.watch(profileVecProvider.future);
  if (profile == null || profile.isEmpty) return const <String>[];

  final idx = await ref.watch(embeddingIndexProvider.future);

  // Use Dart 3 named records for clarity
  final scored = <({int i, double s})>[];
  for (var i = 0; i < idx.n; i++) {
    final s = cosineF32(profile, idx.vecs[i]);
    scored.add((i: i, s: s));
  }
  scored.sort((a, b) => b.s.compareTo(a.s));

  // Top 8 → IDs
  final top = scored.take(8).map((t) => idx.meta[t.i].id).toList();
  return top;
});
