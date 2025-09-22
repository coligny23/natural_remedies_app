import 'dart:math';

import 'tokenizers/bert_vocab.dart';
import 'tokenizers/wordpiece.dart';

class QaFeature {
  final List<int> inputIds;
  final List<int> inputMask;
  final List<int> segmentIds;
  final int contextStart;    // char offset in original context for this window
  final List<int> tokToChar; // map from token index to char offset
  QaFeature(this.inputIds, this.inputMask, this.segmentIds, this.contextStart, this.tokToChar);
}

class BertQaPreprocessor {
  final WordPieceTokenizer tok;
  final int maxSeqLen;
  final int docStride;
  final int maxQueryTok;

  final int clsId, sepId, padId;

  BertQaPreprocessor(this.tok, BertVocab vocab,
      {this.maxSeqLen=384, this.docStride=128, this.maxQueryTok=64})
    : clsId = vocab.idOf('[CLS]') ?? 101,
      sepId = vocab.idOf('[SEP]') ?? 102,
      padId = vocab.idOf('[PAD]') ?? 0;

  List<QaFeature> build(String question, String context) {
    final qIds = tok.tokenizeToIds(question);
    final q = qIds.length > maxQueryTok ? qIds.sublist(0, maxQueryTok) : qIds;

    // tokenize context and keep rough char map (approximate; good enough for plain text)
    final ctxTokens = _whitespaceSplit(context); // coarse split for char offsets
    final tokIds = <int>[];
    final tokToChar = <int>[];
    var charPos = 0;
    for (final t in ctxTokens) {
      final start = context.indexOf(t, charPos);
      charPos = start < 0 ? charPos : start;
      final ids = tok.tokenizeToIds(t);
      tokIds.addAll(ids);
      // map each produced sub-token to the start char of the word (approx.)
      for (var i = 0; i < ids.length; i++) {
        tokToChar.add(max(0, charPos));
      }
      charPos += t.length;
    }

    final maxCtx = maxSeqLen - q.length - 3; // [CLS] q [SEP] ctx [SEP]
    final feats = <QaFeature>[];
    var start = 0;
    while (start < tokIds.length) {
      final end = min(start + maxCtx, tokIds.length);
      final ctxSpan = tokIds.sublist(start, end);
      final ids = <int>[clsId, ...q, sepId, ...ctxSpan, sepId];
      final seg = <int>[0, ...List.filled(q.length, 0), 0, ...List.filled(ctxSpan.length, 1), 1];
      final mask = List<int>.filled(ids.length, 1);

      // pad
      while (ids.length < maxSeqLen) { ids.add(padId); seg.add(0); mask.add(0); }

      final ctxTokToChar = tokToChar.sublist(start, end);
      final ctxCharStart = ctxTokToChar.isEmpty ? 0 : ctxTokToChar.first;
      feats.add(QaFeature(ids, mask, seg, ctxCharStart, ctxTokToChar));

      if (end == tokIds.length) break;
      start = start + docStride;
    }
    return feats;
  }

  List<String> _whitespaceSplit(String s) {
    final parts = s.split(RegExp(r'(\s+)'));
    return parts.where((p) => p.trim().isNotEmpty).toList();
  }
}
