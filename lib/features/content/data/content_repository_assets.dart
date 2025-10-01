import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../models/content_item.dart';
import 'content_repository.dart';

class AssetsContentRepository implements ContentRepository {
  const AssetsContentRepository({this.basePath = 'assets/corpus'});

  final String basePath;

  static final Map<String, List<ContentItem>> _cache = {};
  static final Map<String, Map<String, List<String>>> _synCache =
      {}; // lang -> {term: [aliases]}

  Future<List<String>> _listJsonAssetsUnder(String prefix) async {
    // Scan AssetManifest.json for all JSON files under a language prefix
    final manifest =
        json.decode(await rootBundle.loadString('AssetManifest.json'))
            as Map<String, dynamic>;
    final keys =
        manifest.keys.where((k) => k.startsWith(prefix) && k.endsWith('.json'));
    return keys.toList()..sort();
  }

  Future<List<ContentItem>> _loadLangItems(String lang) async {
    final prefix = '$basePath/$lang/';
    final paths = await _listJsonAssetsUnder(prefix);

    final items = <ContentItem>[];
    for (final path in paths) {
  final base = p.basename(path);   // <-- “synonyms.json”
  if (base == 'synonyms.json') {   // <-- robust skip
    continue;
  }
  try {
    final s = await rootBundle.loadString(path);
    items.addAll(ContentItem.listFromJsonString(s));
  } catch (e) {
    if (kDebugMode) debugPrint('Content load fail $path → $e');
  }
}
    return items;
  }

  Future<Map<String, List<String>>> _loadLangSynonyms(String lang) async {
    final path = '$basePath/$lang/synonyms.json';
    try {
      final s = await rootBundle.loadString(path);
      final map =
          (json.decode(s) as Map<String, dynamic>).map((k, v) => MapEntry(
                k.toLowerCase().trim(),
                (v as List)
                    .map((e) => e.toString().toLowerCase().trim())
                    .toList(),
              ));
      return map;
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> _ensureLangLoaded(String lang) async {
    if (!_cache.containsKey(lang)) {
      _cache[lang] = await _loadLangItems(lang);
    }
    if (!_synCache.containsKey(lang)) {
      _synCache[lang] = await _loadLangSynonyms(lang);
    }
  }

  @override
  Future<List<ContentItem>> getAll({required String lang}) async {
    await _ensureLangLoaded(lang);
    return List<ContentItem>.unmodifiable(_cache[lang]!);
  }
/// Public accessor for the synonyms map used by search.
/// - Ensures the requested language is loaded
/// - Falls back to English if the requested language has no synonyms
  Future<Map<String, List<String>>> getSynonyms({required String lang}) async {
    // Load requested language caches if not already loaded
    await _ensureLangLoaded(lang);
    var map = _synCache[lang] ?? const <String, List<String>>{};

    // Fallback to English if empty and not already English
    if (map.isEmpty && lang != 'en') {
      await _ensureLangLoaded('en');
      map = _synCache['en'] ?? const <String, List<String>>{};
    }

    return map;
  }

  /// Expand a query with synonyms (EN or SW map depending on `lang`)
  List<String> _expandTerms(String lang, String q) {
    final base = q.toLowerCase().trim();
    final syn = _synCache[lang] ?? const {};
    final terms = <String>{base};
    if (syn.containsKey(base)) {
      terms.addAll(syn[base]!);
    }
    return terms.toList();
  }

  /// Score matches: title=+3, body=+1 per term occurrence (simple OR).
  /// (If you add `tags` to ContentItem later, re-enable tag weight here.)
  int _scoreItem(ContentItem it, List<String> terms, String lang) {
    final title = it.title.toLowerCase();
    final body = ((lang == 'sw')
            ? (it.contentSw ?? it.contentEn ?? '')
            : (it.contentEn ?? it.contentSw ?? ''))
        .toLowerCase();

    int score = 0;
    for (final t in terms) {
      if (title.contains(t)) score += 3;
      // Uncomment this block when `tags` exists on ContentItem:
      // final tags = it.tags.map((tg) => tg.toLowerCase());
      // if (tags.any((tg) => tg.contains(t))) score += 2;
      if (body.contains(t)) score += 1;
    }
    return score;
  }

  @override
  Future<List<ContentItem>> search(String query, {required String lang}) async {
    final q = query.trim();
    if (q.isEmpty) return <ContentItem>[];
    await _ensureLangLoaded(lang);

    final items = _cache[lang]!;
    final terms = _expandTerms(lang, q);

    // Pair each matching item with its score
    final scored = <MapEntry<ContentItem, int>>[];
    for (final it in items) {
      final s = _scoreItem(it, terms, lang);
      if (s > 0) scored.add(MapEntry(it, s));
    }

    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.title.compareTo(b.key.title);
    });

    return [for (final e in scored) e.key];
  }

  /// Related items without `tags`:
  /// - same family prefix (id before first '-'), plus
  /// - title word overlap (lowercased, alnum words)
  Future<List<ContentItem>> relatedTo(
    ContentItem it, {
    required String lang,
    int k = 3,
  }) async {
    await _ensureLangLoaded(lang);
    final items = _cache[lang]!;

    String familyPrefix(String id) =>
        id.split('-').first; // herb-*, disease-*, principle-*
    final family = familyPrefix(it.id);

    Set<String> wordsOf(String s) {
      final lower = s.toLowerCase();
      final re = RegExp(r'[a-z0-9]+');
      return re.allMatches(lower).map((m) => m.group(0)!).toSet();
    }

    final baseWords = wordsOf(it.title);

    final list = <MapEntry<ContentItem, int>>[];
    for (final other in items) {
      if (other.id == it.id) continue;

      int score = 0;
      if (familyPrefix(other.id) == family) score += 2;

      final wOverlap = baseWords.intersection(wordsOf(other.title)).length;
      if (wOverlap > 0) score += wOverlap; // each shared word +1

      if (score > 0) list.add(MapEntry(other, score));
    }

    list.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.title.compareTo(b.key.title);
    });

    return [for (final e in list.take(k)) e.key];
  }
}
