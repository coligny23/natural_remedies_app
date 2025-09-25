import 'dart:collection';
import '../content/models/content_item.dart';

/// Tiny inverted index: term -> set of itemIds
class SearchIndex {
  final Map<String, Set<String>> _index = HashMap(); // term -> ids
  final Map<String, ContentItem> _byId; // quick lookup

  SearchIndex._(this._byId);

  /// Build from items. Tokenizes title + content (current language).
  static SearchIndex build({
    required List<ContentItem> items,
    required String lang,
  }) {
    final byId = {for (final it in items) it.id: it};
    final idx = SearchIndex._(byId);

    for (final it in items) {
      final title = it.title.toLowerCase();
      final body = (lang == 'sw')
          ? (it.contentSw ?? it.contentEn ?? '')
          : (it.contentEn ?? it.contentSw ?? '');

      final text = '$title\n$body'.toLowerCase();
      final words = _tokenize(text);
      for (final w in words) {
        (idx._index[w] ??= <String>{}).add(it.id);
      }
    }
    return idx;
  }

  static final _re = RegExp(r'[a-z0-9]{2,}'); // drop 1-char tokens
  static Iterable<String> _tokenize(String s) =>
      _re.allMatches(s).map((m) => m.group(0)!).toSet(); // unique

  /// Return candidate item ids that contain any of the given terms.
  Set<String> lookupAny(Iterable<String> terms) {
    final out = <String>{};
    for (final t in terms) {
      final hit = _index[t];
      if (hit != null) out.addAll(hit);
    }
    return out;
  }

  ContentItem? byId(String id) => _byId[id];
}
