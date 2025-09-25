// lib/shared/ml/bert_tokenizer.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Minimal WordPiece tokenizer for MobileBERT-style QA (lowercase).
/// Special tokens are fixed: [CLS], [SEP], [PAD], [UNK].
class BertTokenizer {
  static const _unk = '[UNK]';
  static const _cls = '[CLS]';
  static const _sep = '[SEP]';
  static const _pad = '[PAD]';

  final Map<String, int> _vocab; // token -> id
  final int maxLen;

  BertTokenizer._(this._vocab, {this.maxLen = 384});

  /// Load vocab.txt from assets (one token per line, id = line index).
  static Future<BertTokenizer> fromAsset(
    String vocabAsset, {
    int maxLen = 384,
  }) async {
    final txt = await rootBundle.loadString(vocabAsset);
    final lines = const LineSplitter().convert(txt);
    final vocab = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      vocab[t] = i;
    }

    // Ensure required special tokens exist.
    for (final t in const [_unk, _cls, _sep, _pad]) {
      if (!vocab.containsKey(t)) {
        throw StateError('vocab.txt missing required token: $t');
      }
    }

    return BertTokenizer._(vocab, maxLen: maxLen);
  }

  /// Encodes question/context as:
  ///   [CLS] question_tokens [SEP] context_tokens [SEP]
  /// Truncates to maxLen; returns ids/masks/segments and contextStart index.
  EncodeResult encodePair(String question, String context) {
    final qTok = _tokenize(question);
    final cTok = _tokenize(context);

    // We need: 1 ([CLS]) + q + 1 ([SEP]) + c + 1 ([SEP]) <= maxLen
    final available = maxLen - 3;
    final qKeep = qTok.length.clamp(0, available ~/ 3); // a simple 1/3 budget to question
    final cKeep = (available - qKeep).clamp(0, cTok.length);

    final keptQ = qTok.take(qKeep).toList(growable: false);
    final keptC = cTok.take(cKeep).toList(growable: false);

    final tokens = <String>[
      _cls,
      ...keptQ,
      _sep,
      ...keptC,
      _sep,
    ];

    final inputIds = tokens.map(_idOf).toList(growable: true);
    final segmentIds = List<int>.filled(tokens.length, 0, growable: true);
    // segment 0 for [CLS]+question+[SEP], then 1 for context+[SEP]
    final ctxStart = 1 + keptQ.length + 1; // after first [SEP]
    for (var i = ctxStart; i < tokens.length; i++) {
      segmentIds[i] = 1;
    }

    final inputMask = List<int>.filled(tokens.length, 1, growable: true);

    // Pad to maxLen
    while (inputIds.length < maxLen) {
      inputIds.add(_idOf(_pad));
      inputMask.add(0);
      segmentIds.add(0);
      tokens.add(_pad);
    }

    return EncodeResult(
      tokens: tokens,
      inputIds: inputIds,
      inputMask: inputMask,
      segmentIds: segmentIds,
      contextStart: ctxStart,
    );
  }

  /// Very small BasicTokenizer + WordPiece (greedy, lowercase).
  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final basic = lower
      .replaceAll(RegExp(r'[\t\r\n]'), ' ')
      .replaceAllMapped(RegExp(r'([!-/:-@\[\\\]^_`{|}~])'),
        (m) => ' ${m.group(1)} ',
          )
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();

    final out = <String>[];
    for (final word in basic) {
      if (_vocab.containsKey(word)) {
        out.add(word);
        continue;
      }
      // WordPiece greedy longest-match-first
      var start = 0;
      final chars = word.codeUnits;
      final subTokens = <String>[];
      while (start < chars.length) {
        var end = chars.length;
        String? cur;
        while (start < end) {
          var substr = String.fromCharCodes(chars.sublist(start, end));
          if (start > 0) substr = '##$substr';
          if (_vocab.containsKey(substr)) {
            cur = substr;
            break;
          }
          end -= 1;
        }
        if (cur == null) {
          subTokens.add(_unk);
          break;
        }
        subTokens.add(cur);
        start = end;
      }
      out.addAll(subTokens);
    }
    return out;
  }

  int _idOf(String token) => _vocab[token] ?? _vocab[_unk]!;

  /// Joins WordPiece tokens into readable text.
  String detokenize(List<String> tokens) {
    final buf = StringBuffer();
    for (final t in tokens) {
      if (t == _cls || t == _sep || t == _pad) continue;
      if (t.startsWith('##')) {
        buf.write(t.substring(2));
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
    }
    return buf.toString();
  }
}

class EncodeResult {
  final List<String> tokens;
  final List<int> inputIds;
  final List<int> inputMask;
  final List<int> segmentIds;
  final int contextStart;
  EncodeResult({
    required this.tokens,
    required this.inputIds,
    required this.inputMask,
    required this.segmentIds,
    required this.contextStart,
  });
}
