import 'dart:math';

import 'bert_vocab.dart';

class WordPieceTokenizer {
  final BertVocab vocab;
  final String unkToken;
  final bool doLowerCase;

  WordPieceTokenizer(this.vocab, {this.unkToken='[UNK]', this.doLowerCase=true});

  List<int> tokenizeToIds(String text) {
    final toks = _basicTokenize(text);
    final out = <int>[];
    for (final t in toks) {
      out.addAll(_wordPiece(t));
    }
    return out;
  }

  List<String> _basicTokenize(String s) {
    // lowercase + split on whitespace/punct (very light)
    if (doLowerCase) s = s.toLowerCase();
    final buf = StringBuffer();
    final toks = <String>[];
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      if (_isWhitespace(ch) || _isPunct(ch)) {
        if (buf.isNotEmpty) { toks.add(buf.toString()); buf.clear(); }
        if (_isPunct(ch)) toks.add(ch);
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) toks.add(buf.toString());
    return toks.where((t) => t.trim().isNotEmpty).toList();
  }

  bool _isWhitespace(String c) => RegExp(r'^\s$').hasMatch(c);
  bool _isPunct(String c) => RegExp(r'[!-/:-@\[\\\]-`{-~]').hasMatch(c);

  List<int> _wordPiece(String token) {
    final maxLen = 100;
    if (token.length > maxLen) {
      return [vocab.idOf(unkToken) ?? 100];
    }
    final chars = token.split('');
    var start = 0;
    final out = <int>[];
    while (start < chars.length) {
      var end = chars.length;
      int? curId;
      String? curSub;
      while (start < end) {
        var substr = chars.sublist(start, end).join();
        if (start > 0) substr = '##$substr';
        final id = vocab.idOf(substr);
        if (id != null) {
          curId = id;
          curSub = substr;
          break;
        }
        end -= 1;
      }
      if (curId == null) {
        out.add(vocab.idOf(unkToken) ?? 100);
        break;
      }
      out.add(curId);
      start += curSub!.startsWith('##') ? curSub.length - 2 : curSub.length;
    }
    return out;
  }
}
