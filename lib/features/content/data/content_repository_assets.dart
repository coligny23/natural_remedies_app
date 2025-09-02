import 'package:flutter/services.dart' show rootBundle;
import '../models/content_item.dart';
import 'content_repository.dart';

class AssetsContentRepository implements ContentRepository {
  List<ContentItem>? _en;
  List<ContentItem>? _sw;

  Future<void> _ensureLoaded() async {
    if (_en == null) {
      final enStr = await rootBundle.loadString('assets/corpus/en/sample.json');
      _en = ContentItem.listFromJsonString(enStr);
    }
    if (_sw == null) {
      try {
        final swStr = await rootBundle.loadString('assets/corpus/sw/sample.json');
        _sw = ContentItem.listFromJsonString(swStr);
      } catch (_) {
        _sw = const [];
      }
    }
  }

  @override
  Future<List<ContentItem>> getAll({String lang = 'en'}) async {
    await _ensureLoaded();
    // lang-first then fallback language appended
    return lang == 'sw' ? [...?_sw, ...?_en] : [...?_en, ...?_sw];
  }

  @override
Future<ContentItem?> getById(String id, {String lang = 'en'}) async {
  final all = await getAll(lang: lang);
  final idx = all.indexWhere((e) => e.id == id);
  return idx == -1 ? null : all[idx];
}


  @override
  Future<List<ContentItem>> search(String query, {String lang = 'en', int limit = 50}) async {
    final all = await getAll(lang: lang);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all.take(limit).toList();

    bool matches(ContentItem it) {
      final t = (it.textFor(lang) ?? '').toLowerCase();
      return it.title.toLowerCase().contains(q)
          || it.section.toLowerCase().contains(q)
          || t.contains(q)
          || it.tags.any((tag) => tag.toLowerCase().contains(q));
    }

    final res = all.where(matches).toList();
    // naive priority: title matches first
    res.sort((a,b) {
      final at = a.title.toLowerCase().contains(q) ? 0 : 1;
      final bt = b.title.toLowerCase().contains(q) ? 0 : 1;
      return at.compareTo(bt);
    });
    return res.take(limit).toList();
  }
}
