import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/content_item.dart';

/// Loads all JSON content files under assets/corpus/<lang>/ automatically.
/// Example files:
///   assets/corpus/en/principles.json
///   assets/corpus/en/herbs.json
///   assets/corpus/en/diseases_a.json
///   assets/corpus/sw/principles.json (optional, can come later)
class AssetsContentRepository {
  const AssetsContentRepository({this.basePrefix = 'assets/corpus'});

  final String basePrefix;

  // simple in-memory cache keyed by language
  static final Map<String, List<ContentItem>> _cache = {};

  Future<List<ContentItem>> load(String lang) async {
    // use cache if present
    if (_cache.containsKey(lang)) return _cache[lang]!;

    // read the asset manifest (maps every asset path).
    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final manifest = (json.decode(manifestStr) as Map).keys.cast<String>();

    // candidate paths for the requested lang
    final candidates = manifest
        .where((p) =>
            p.startsWith('$basePrefix/$lang/') &&
            p.toLowerCase().endsWith('.json'))
        .toList();

    // If none for requested lang, try English as fallback
    final paths = candidates.isNotEmpty
        ? candidates
        : manifest
            .where((p) =>
                p.startsWith('$basePrefix/en/') &&
                p.toLowerCase().endsWith('.json'))
            .toList();

    if (kDebugMode) {
      debugPrint('AssetsContentRepository: loading ${paths.length} file(s) for lang=$lang');
      if (paths.isEmpty) debugPrint('⚠️ No content assets found. Did you include assets/corpus/ in pubspec.yaml?');
    }

    final items = <ContentItem>[];
    for (final path in paths) {
      try {
        final s = await rootBundle.loadString(path);
        items.addAll(ContentItem.listFromJsonString(s));
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to parse $path → $e');
      }
    }

    // de-duplicate by id (keep first occurrence)
    final byId = <String, ContentItem>{};
    for (final it in items) {
      byId.putIfAbsent(it.id, () => it);
    }
    final result = byId.values.toList(growable: false);

    _cache[lang] = result;
    return result;
  }
}
