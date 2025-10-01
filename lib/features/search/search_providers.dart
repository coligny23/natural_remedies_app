// lib/features/search/search_providers.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/models/content_item.dart';
import '../content/data/content_repository_assets.dart';
import 'search_index.dart';

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

/// (Optional) Expand query into terms (basic tokenizer).
final expandedQueryProvider = Provider.family<List<String>, String>((ref, raw) {
  final q = raw.trim().toLowerCase();
  if (q.isEmpty) return const <String>[];
  return q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
});

/// --- Day 22: synonyms support ---

/// Load synonyms map for the current language (falls back inside repo).
final synonymsMapProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final lang = ref.watch(languageCodeProvider);
  try {
    final m = await repo.getSynonyms(lang: lang);
    // normalize to lowercase
    return {
      for (final e in m.entries)
        e.key.toLowerCase(): e.value.map((x) => x.toLowerCase()).toList()
    };
  } catch (_) {
    return <String, List<String>>{};
  }
});

List<String> _tokens(String q) =>
    q.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((s) => s.isNotEmpty).toList();

/// Expanded set of terms = originals ∪ synonyms(originals)
final expandedTermsProvider = Provider.family<Set<String>, String>((ref, raw) {
  final toks = _tokens(raw);
  if (toks.isEmpty) return <String>{};
  final synsAsync = ref.watch(synonymsMapProvider);
  return synsAsync.maybeWhen(
    data: (syns) {
      final out = <String>{...toks};
      for (final t in toks) {
        final alts = syns[t] ?? const <String>[];
        out.addAll(alts);
      }
      return out;
    },
    orElse: () => toks.toSet(),
  );
});

/// Fast search using the index for candidate shortlist, then a lightweight rank.
/// Now synonym-aware: originals get higher weight than synonyms.
final fastSearchProvider =
    FutureProvider.family<List<ContentItem>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return <ContentItem>[];

  final lang = ref.watch(languageCodeProvider);
  final index = await ref.watch(searchIndexProvider.future);
  final allItems = await ref.watch(contentListProvider.future);

  // originals (typed terms) + expanded (synonyms too)
  final originals = _tokens(q).toSet();
  final expanded = ref.watch(expandedTermsProvider(q));

  // shortlist via index using expanded terms (wider net)
  final candidateIds = index.lookupAny(expanded.toList());
  if (candidateIds.isEmpty) return <ContentItem>[];

  // materialize candidates
  final byId = {for (final it in allItems) it.id: it};
  final candidates = <ContentItem>[
    for (final id in candidateIds)
      if (byId[id] != null) byId[id]!,
  ];

  double score(ContentItem it) {
    final title = it.title.toLowerCase();
    final body = (lang == 'sw')
        ? (it.contentSw ?? it.contentEn ?? '')
        : (it.contentEn ?? it.contentSw ?? '');
    final b = body.toLowerCase();

    double s = 0;
    for (final term in expanded) {
      final isOriginal = originals.contains(term);
      if (title.contains(term)) s += isOriginal ? 3.0 : 2.0; // title weight
      if (b.contains(term))    s += isOriginal ? 1.0 : 0.5;  // body weight
    }
    return s;
  }

  candidates.removeWhere((it) => score(it) <= 0);
  candidates.sort((a, b) {
    final sa = score(a), sb = score(b);
    final byScore = sb.compareTo(sa);
    if (byScore != 0) return byScore;
    return a.title.compareTo(b.title);
  });

  return candidates;
});
