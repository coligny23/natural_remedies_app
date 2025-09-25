import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import '/shared/ml/tokenizers/bert_tokenizer.dart';

/// Holds result text + optional metadata.
class QaAnswer {
  final String text;
  final double score;
  final String? sourceTitle;
  final String? sourceId;
  QaAnswer(this.text, this.score, {this.sourceTitle, this.sourceId});
}

class QaModel {
  final String modelAssetPath;
  final String vocabAssetPath;
  final int maxLen;
  Interpreter? _interpreter;
  IsolateInterpreter? _iso;
  late final BertTokenizer _tok;

  QaModel({
    this.modelAssetPath = 'assets/ml/mobilebert_qa_float32.tflite',
    this.vocabAssetPath = 'assets/ml/vocab.txt',
    this.maxLen = 384,
  });

  Future<void> load() async {
    _tok = await BertTokenizer.fromAsset(vocabAssetPath, maxLen: maxLen);
    final interpreter = await Interpreter.fromAsset(modelAssetPath,
        options: InterpreterOptions()..threads = 2);
    _interpreter = interpreter;
    _iso = await IsolateInterpreter.create(address: interpreter.address);
  }

  bool get isLoaded => _iso != null;

  void dispose() {
    _iso?.close();
    _interpreter?.close();
    _iso = null;
    _interpreter = null;
  }

  /// Returns best answer span within `context` for `question`.
  /// Uses simple max(start_logit + end_logit) with max span width.
  Future<QaAnswer?> answer(String question, String context) async {
    if (_iso == null) return null;
    final enc = _tok.encodePair(question, context);

    // Model expects int32 inputs [1, maxLen].
    final inputIds = [enc.inputIds];
    final inputMask = [enc.inputMask];
    final segIds = [enc.segmentIds];

    // Outputs: start_logits [1, maxLen], end_logits [1, maxLen]
    final start = List<double>.filled(maxLen, 0).reshape([1, maxLen]);
    final end = List<double>.filled(maxLen, 0).reshape([1, maxLen]);
    final outputs = {0: start, 1: end};

    await _iso!.runForMultipleInputs(
      [inputIds, inputMask, segIds],
      outputs,
    );

    final startLogits = start[0];
    final endLogits = end[0];

    // Search best span in context region only.
    final cStart = enc.contextStart;
    final cEnd = maxLen - 1;
    const maxAnswerLen = 30;

    var bestScore = double.negativeInfinity;
    var bestStart = cStart;
    var bestEnd = cStart;

    for (var i = cStart; i < cEnd; i++) {
      for (var j = i; j < math.min(i + maxAnswerLen, cEnd); j++) {
        final score = startLogits[i] + endLogits[j];
        if (score > bestScore && j >= i) {
          bestScore = score;
          bestStart = i;
          bestEnd = j;
        }
      }
    }

    // Convert tokens back to a human string.
    final answerTokens = enc.tokens.sublist(bestStart, bestEnd + 1);
    final text = _tok.detokenize(answerTokens).trim();

    if (text.isEmpty) return null;
    return QaAnswer(text, bestScore);
  }
}
