import 'package:flutter/services.dart' show rootBundle;
import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';

class E5TokenizedInput {
  final List<List<int>> inputIds;
  final List<List<int>> attentionMask;

  const E5TokenizedInput({
    required this.inputIds,
    required this.attentionMask,
  });
}

class E5Tokenizer {
  static const int maxLen = 128;

  late final SentencePieceTokenizer _tokenizer;
  bool _ready = false;

  Future<void> init() async {
    final jsonText =
        await rootBundle.loadString('assets/models_e5small/tokenizer.json');

    _tokenizer = TokenizerJsonLoader.fromJsonString(jsonText);

    _tokenizer
      ..enablePadding(
        length: maxLen,
        direction: SpPaddingDirection.right,
      )
      ..enableTruncation(
        maxLength: maxLen,
        direction: SpTruncationDirection.right,
      );

    _ready = true;
  }

  E5TokenizedInput encode(String text) {
    if (!_ready) {
      throw StateError('E5Tokenizer has not been initialized.');
    }

    final encoding = _tokenizer.encode(text);

    final ids = List<int>.from(encoding.ids);
    final mask = List<int>.from(encoding.attentionMask);

    return E5TokenizedInput(
      inputIds: [ids],
      attentionMask: [mask],
    );
  }
}