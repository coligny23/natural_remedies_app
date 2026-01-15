import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Minimal WordPiece tokenizer for BERT-like models (uncased).
/// Supports: lowercasing, basic punctuation split, and '##' subword matching.
class WordPieceTokenizer {
  final Map<String, int> _vocab;
  final int unkId;
  final int clsId;
  final int sepId;
  final bool doLowerCase;

  WordPieceTokenizer._(this._vocab, this.unkId, this.clsId, this.sepId, this.doLowerCase);

  static Future<WordPieceTokenizer> fromAsset(
    String vocabAsset, {
    bool doLowerCase = true,
    String unkToken = "[UNK]",
    String clsToken = "[CLS]",
    String sepToken = "[SEP]",
  }) async {
    final raw = await rootBundle.loadString(vocabAsset);
    final lines = const LineSplitter().convert(raw);
    final map = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      map[lines[i].trim()] = i;
    }
    return WordPieceTokenizer._(
      map,
      map[unkToken] ?? 100,
      map[clsToken] ?? 101,
      map[sepToken] ?? 102,
      doLowerCase,
    );
  }

  List<int> encode(String text, {int maxLen = 128}) {
    // 1) Basic tokenization
    var tokens = _basicTokenize(text);
    // 2) WordPiece
    final wordpieceIds = <int>[];
    for (final tok in tokens) {
      final wp = _wordpiece(tok);
      wordpieceIds.addAll(wp);
      if (wordpieceIds.length >= maxLen - 2) break; // reserve [CLS],[SEP]
    }
    // 3) Add [CLS] and [SEP], pad/truncate
    final out = <int>[clsId, ...wordpieceIds.take(maxLen - 2), sepId];
    if (out.length < maxLen) {
      out.addAll(List<int>.filled(maxLen - out.length, 0)); // [PAD]=0 in BERT
    }
    return out;
  }

  List<int> attentionMaskFor(List<int> inputIds) {
    // mask 1 for non-padding
    return [for (final id in inputIds) id == 0 ? 0 : 1];
  }

  List<String> _basicTokenize(String text) {
    var s = text;
    if (doLowerCase) s = s.toLowerCase();
    // split on whitespace & punctuation
    final buf = StringBuffer();
    final out = <String>[];
    bool isSpace(int c) => c <= 32;
    bool isPunct(int c) {
      const punct = r"""!()-[]{};:'"\,<>./?@#$%^&*_~`+=|""";
      return punct.codeUnits.contains(c);
    }
    void flush() {
      if (buf.isNotEmpty) { out.add(buf.toString()); buf.clear(); }
    }

    for (final c in s.codeUnits) {
      if (isSpace(c) || isPunct(c)) { flush(); }
      else { buf.writeCharCode(c); }
    }
    flush();
    return out.where((t) => t.isNotEmpty).toList(growable: false);
  }

  List<int> _wordpiece(String token) {
    // Greedy longest-match-first with '##' continuation
    final ids = <int>[];
    final runes = token.runes.toList();
    var start = 0;
    while (start < runes.length) {
      var end = runes.length;
      int? curId;
      while (start < end) {
        final sub = String.fromCharCodes(runes.getRange(start, end));
        final piece = start == 0 ? sub : '##$sub';
        final id = _vocab[piece];
        if (id != null) { curId = id; break; }
        end -= 1;
      }
      if (curId == null) { return [unkId]; } // fallback as a whole [UNK]
      ids.add(curId);
      start = end;
    }
    return ids;
  }
}
