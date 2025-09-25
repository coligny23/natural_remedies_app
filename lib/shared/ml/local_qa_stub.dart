import 'dart:math';
import 'package:natural_remedies_app/features/content/models/content_item.dart';
import 'local_qa_engine.dart';

/// Very small, fast keyword-matching engine:
/// - builds a lowercase bag-of-words for each content item
/// - scores by term frequency and a small title boost
class LocalQaStub implements LocalQaEngine {
  late String _lang;
  late List<_IndexedItem> _items;

  @override
  Future<void> init({required List<ContentItem> corpus, required String lang}) async {
    _lang = lang;
    _items = corpus.map((c) => _IndexedItem.from(c)).toList(growable: false);
  }

  @override
  Future<QaAnswer> answer(String query, {List<ContentItem>? shortlist}) async {
    final q = _tokenize(query);
    if (q.isEmpty || _items.isEmpty) {
      return const QaAnswer(text: "Nisamehe, siwezi kupata jibu kwa sasa."); // short default
    }

    // Score each item
    final scored = <(_IndexedItem, double)>[];
    for (final it in _items) {
      final s = it.score(q);
      if (s > 0) scored.add((it, s));
    }
    if (scored.isEmpty) {
      return const QaAnswer(text: "Hakuna linganifu lililopatikana.");
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final best = scored.first.$1;

    // Build a short answer: title + top snippet around the first matched token
    final firstHit = q.firstWhere((t) => best.tokensBody.containsKey(t) || best.titleLc.contains(t), orElse: () => '');
    final snippet = best.snippetAround(firstHit, maxLen: 200);

    final text = snippet?.isNotEmpty == true
        ? snippet!
        : (best.item.contentEn ?? best.item.contentSw ?? best.item.title);

    // Top 3 matches as related reading
    final topRefs = scored.take(min(3, scored.length)).map((e) => e.$1.item).toList();

    return QaAnswer(text: text, source: best.item, topMatches: topRefs);
  }

  // --- helpers ---

  static final _wordRe = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9']+");

  List<String> _tokenize(String s) =>
      _wordRe.allMatches(s.toLowerCase()).map((m) => m.group(0)!).toList();
}

class _IndexedItem {
  final ContentItem item;
  final String titleLc;
  final String bodyLc;
  final Map<String, int> tokensBody;

  _IndexedItem({required this.item, required this.titleLc, required this.bodyLc, required this.tokensBody});

  factory _IndexedItem.from(ContentItem c) {
    final title = c.title.toLowerCase();
    final body = (c.contentEn ?? c.contentSw ?? '').toLowerCase();
    final tokens = <String, int>{};
    for (final m in LocalQaStub._wordRe.allMatches(body)) {
      final t = m.group(0)!;
      tokens[t] = (tokens[t] ?? 0) + 1;
    }
    return _IndexedItem(item: c, titleLc: title, bodyLc: body, tokensBody: tokens);
  }

  double score(List<String> qTokens) {
    // Simple frequency score + small title boost if token appears in title
    double s = 0;
    for (final t in qTokens) {
      s += (tokensBody[t] ?? 0).toDouble();
      if (titleLc.contains(t)) s += 0.75;
    }
    return s;
  }

  String? snippetAround(String term, {int maxLen = 200}) {
    if (term.isEmpty) return null;
    final idx = bodyLc.indexOf(term);
    if (idx < 0) return null;
    final start = (idx - maxLen ~/ 2).clamp(0, bodyLc.length);
    final end = (idx + maxLen ~/ 2).clamp(0, bodyLc.length);
    final s = bodyLc.substring(start, end).replaceAll('\n', ' ');
    if (start > 0 && end < bodyLc.length) return '… $s …';
    if (start > 0) return '… $s';
    if (end < bodyLc.length) return '$s …';
    return s;
  }
}
