import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/content_item.dart'; // or ../model/content_item.dart
import 'content_repository.dart';

class AssetsContentRepository implements ContentRepository {
  const AssetsContentRepository({this.basePath = 'assets/corpus'});

  final String basePath;

  // naive in-memory cache per language
  static final Map<String, List<ContentItem>> _cache = {};

  Future<List<ContentItem>> _loadLang(String lang) async {
    // Try requested lang first, then fall back to EN.
    final candidates = <String>[
      '$basePath/$lang/sample.json',
      '$basePath/en/sample.json',
    ];

    for (final path in candidates) {
      try {
        if (kDebugMode) debugPrint('Trying asset → $path');
        final jsonStr = await rootBundle.loadString(path);
        final list = ContentItem.listFromJsonString(jsonStr);
        if (kDebugMode) debugPrint('Loaded ${list.length} items from $path');
        return list;
      } catch (e) {
        if (kDebugMode) debugPrint('Asset miss for $path → $e');
      }
    }
    return <ContentItem>[];
  }

  Future<List<ContentItem>> _getOrLoad(String lang) async {
    if (_cache.containsKey(lang)) return _cache[lang]!;
    final items = await _loadLang(lang);
    _cache[lang] = items;
    return items;
  }

  @override
  Future<List<ContentItem>> getAll({required String lang}) async {
    final items = await _getOrLoad(lang);
    // Return an unmodifiable copy to avoid accidental mutations.
    return List<ContentItem>.unmodifiable(items);
  }

  @override
  Future<List<ContentItem>> search(String query, {required String lang}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <ContentItem>[];

    final items = await _getOrLoad(lang);
    return items.where((it) {
      final t = it.title.toLowerCase();
      final en = (it.contentEn ?? '').toLowerCase();
      final sw = (it.contentSw ?? '').toLowerCase();
      return t.contains(q) || en.contains(q) || sw.contains(q);
    }).toList(growable: false);
  }
}
