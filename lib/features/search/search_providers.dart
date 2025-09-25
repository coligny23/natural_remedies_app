// lib/features/search/search_providers.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/models/content_item.dart';
import '../content/data/content_repository_assets.dart';
import 'search_index.dart'; // <-- you created this in lib/features/search/search_index.dart

/// App language (en/sw)
final languageCodeProvider = StateProvider<String>((_) => 'en');

/// Concrete assets repo (auto-discovers assets/corpus/<lang>/*.json)
final contentRepositoryProvider = Provider<AssetsContentRepository>(
  (_) => const AssetsContentRepository(),
);

/// Load all content for the current language
final contentListProvider = FutureProvider<List<ContentItem>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final lang = ref.watch(languageCodeProvider);
  return repo.getAll(lang: lang);
});

/// Search UI state
final searchQueryProvider = StateProvider<String>((_) => '');

/// ---------- Day 16: Indexing & fast search ----------

/// Build a tiny inverted index in a background isolate whenever content/lang changes.
final searchIndexProvider = FutureProvider<SearchIndex>((ref) async {
  final items = await ref.watch(contentListProvider.future);
  final lang = ref.watch(languageCodeProvider);

  return compute<_BuildArgs, SearchIndex>(
    _buildIndexIsolate,
    _BuildArgs(items, lang),
  );
});

class _BuildArgs {
  final List<ContentItem> items;
  final String lang;
  const _BuildArgs(this.items, this.lang);
}

SearchIndex _buildIndexIsolate(_BuildArgs a) {
  return SearchIndex.build(items: a.items, lang: a.lang);
}

/// (Optional) Expand query into terms (hook for synonyms, splitting, normalization).
final expandedQueryProvider = Provider.family<List<String>, String>((ref, raw) {
  final q = raw.trim().toLowerCase();
  if (q.isEmpty) return const <String>[];
  // Simple tokenizer (space-split); your repo-level synonyms still apply elsewhere.
  return q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
});

/// Fast search using the index for candidate shortlist, then a lightweight rank.
final fastSearchProvider =
    FutureProvider.family<List<ContentItem>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return <ContentItem>[];

  final lang = ref.watch(languageCodeProvider);
  final index = await ref.watch(searchIndexProvider.future);
  final allItems = await ref.watch(contentListProvider.future);

  final terms = ref.read(expandedQueryProvider(q));
  final candidateIds = index.lookupAny(terms);
  if (candidateIds.isEmpty) return <ContentItem>[];

  // Materialize candidates
  final byId = {for (final it in allItems) it.id: it};
  final candidates = <ContentItem>[
    for (final id in candidateIds)
      if (byId[id] != null) byId[id]!,
  ];

  // Lightweight scoring (title stronger than body)
  int score(ContentItem it) {
    final title = it.title.toLowerCase();
    final body = (lang == 'sw')
        ? (it.contentSw ?? it.contentEn ?? '')
        : (it.contentEn ?? it.contentSw ?? '');
    final b = body.toLowerCase();

    var s = 0;
    for (final t in terms) {
      if (title.contains(t)) s += 3;
      if (b.contains(t)) s += 1;
    }
    return s;
  }

  candidates.removeWhere((it) => score(it) == 0);
  candidates.sort((a, b) {
    final byScore = score(b).compareTo(score(a));
    if (byScore != 0) return byScore;
    return a.title.compareTo(b.title);
  });

  return candidates;
});
