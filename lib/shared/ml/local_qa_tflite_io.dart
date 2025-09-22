// lib/shared/ml/local_qa_tflite_io.dart
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'local_qa_engine.dart';
import '../../features/content/models/content_item.dart';
import 'qa_bert_preproc.dart';
import 'tokenizers/bert_vocab.dart';
import 'tokenizers/wordpiece.dart';

class LocalQaTflite implements LocalQaEngine {
  late final Interpreter _interpreter;
  late final BertVocab _vocab;
  late final WordPieceTokenizer _wp;
  late final BertQaPreprocessor _prep;

  late List<ContentItem> _corpus;
  late String _lang;
  bool _ready = false;

  @override
  Future<void> init({required List<ContentItem> corpus, required String lang}) async {
    _corpus = corpus; _lang = lang;

    _vocab = await BertVocab.fromAsset('assets/ml/vocab.txt');
    _wp = WordPieceTokenizer(_vocab, doLowerCase: true);
    _prep = BertQaPreprocessor(_wp, _vocab, maxSeqLen: 384, docStride: 128, maxQueryTok: 64);

    _interpreter = await Interpreter.fromAsset(
      'assets/ml/mobilebert_qa.tflite',
      options: InterpreterOptions()..threads = 2,
    );

    _ready = true;
  }

  @override
  Future<QaAnswer> answer(String query) async {
    if (!_ready) return QaAnswer(text: '', source: null);

    final candidates = _prefilter(query, topK: 8);
    String bestText = '';
    double bestScore = double.negativeInfinity;
    ContentItem? bestSource;

    for (final it in candidates) {
      final ctx = (_lang == 'sw') ? (it.contentSw ?? it.contentEn ?? '') : (it.contentEn ?? it.contentSw ?? '');
      if (ctx.isEmpty) continue;
      final feats = _prep.build(query, ctx);
      for (final f in feats) {
        final res = _runOne(f);
        if (res == null) continue;
        final (sIdx, eIdx, score) = res;

        final startChar = _safeAt(f.tokToChar, sIdx) ?? 0;
        final endChar   = _safeAt(f.tokToChar, eIdx) ?? startChar;
        final s = startChar - f.contextStart;
        final e = endChar   - f.contextStart;
        if (s >= 0 && e >= s && e < ctx.length) {
          final span = ctx.substring(s, e + 1).trim();
          if (span.isNotEmpty && score > bestScore) {
            bestScore = score; bestText = span; bestSource = it;
          }
        }
      }
    }
    return QaAnswer(text: bestText, source: bestSource);
  }

  (int,int,double)? _runOne(QaFeature f) {
    final L = f.inputIds.length;

    // Inputs (as Lists). If your model requires typed buffers, swap to Int32List/Float32List.
    final inputIds   = [ List<int>.from(f.inputIds)   ];
    final inputMask  = [ List<int>.from(f.inputMask)  ];
    final segmentIds = [ List<int>.from(f.segmentIds) ];

    final startLogits = [ List<double>.filled(L, 0) ];
    final endLogits   = [ List<double>.filled(L, 0) ];

    final inputs  = <Object>[ inputIds, inputMask, segmentIds ];
    final outputs = <int, Object>{ 0: startLogits, 1: endLogits };

    try {
      _interpreter.runForMultipleInputs(inputs, outputs);
    } catch (_) {
      return null;
    }

    var bestS = 0, bestE = 0;
    var best = double.negativeInfinity;
    var ctxStart = f.segmentIds.indexWhere((x) => x == 1);
    if (ctxStart < 0) ctxStart = 0;
    final ctxEnd = L - 1;

    for (var s = ctxStart; s < ctxEnd; s++) {
      if (f.inputMask[s] == 0) break;
      for (var e = s; e < (s + 30).clamp(0, ctxEnd); e++) {
        if (f.inputMask[e] == 0) break;
        final score = startLogits[0][s] + endLogits[0][e] - (e - s) * 0.1;
        if (score > best) { best = score; bestS = s; bestE = e; }
      }
    }
    return (bestS - ctxStart, bestE - ctxStart, best);
  }

  T? _safeAt<T>(List<T> xs, int i) => (i >= 0 && i < xs.length) ? xs[i] : null;

  List<ContentItem> _prefilter(String query, {int topK = 8}) {
    final q = query.toLowerCase();
    final scored = <(double, ContentItem)>[];
    for (final it in _corpus) {
      final body = (_lang == 'sw') ? (it.contentSw ?? it.contentEn ?? '') : (it.contentEn ?? it.contentSw ?? '');
      final text = '${it.title} $body'.toLowerCase();
      final tf = _count(text, q);
      if (tf == 0) continue;
      final score = tf + (it.title.toLowerCase().contains(q) ? 1.0 : 0.0);
      scored.add((score, it));
    }
    scored.sort((a,b) => b.$1.compareTo(a.$1));
    return scored.take(topK).map((e) => e.$2).toList();
  }

  int _count(String hay, String needle) {
    if (needle.isEmpty) return 0;
    var i = 0, c = 0;
    while ((i = hay.indexOf(needle, i)) >= 0) { c++; i += needle.length; }
    return c;
  }
}
