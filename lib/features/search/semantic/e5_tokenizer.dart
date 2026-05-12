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

  late final dynamic _tokenizer;
  bool _ready = false;

  Future<void> init() async {
    final jsonText =
        await rootBundle.loadString('assets/models_e5small/tokenizer.json');

    // Hugging Face tokenizer.json loader.
    _tokenizer = await Tokenizer.fromJson(jsonText);

    _ready = true;
  }

  E5TokenizedInput encode(String text) {
    if (!_ready) {
      throw StateError('E5Tokenizer has not been initialized.');
    }

    final encoding = _tokenizer.encode(text);

    final rawIds = List<int>.from(encoding.ids);

    final ids = rawIds.take(maxLen).toList();

    // If truncated, preserve EOS token if available from tokenizer output.
    if (rawIds.length > maxLen && rawIds.isNotEmpty) {
      ids[maxLen - 1] = rawIds.last;
    }

    final mask = List<int>.filled(ids.length, 1);

    while (ids.length < maxLen) {
      ids.add(0);
      mask.add(0);
    }

    return E5TokenizedInput(
      inputIds: [ids],
      attentionMask: [mask],
    );
  }
}