import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

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

  late final Map<String, int> _vocab;

  int _padId = 1;
  int _unkId = 3;
  int _bosId = 0; // <s>
  int _eosId = 2; // </s>

  Future<void> init() async {
    final raw =
        await rootBundle.loadString('assets/models_e5small/tokenizer.json');
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;

    final model = jsonMap['model'] as Map<String, dynamic>;
    final modelType = model['type']?.toString();

    if (modelType != 'Unigram') {
      throw UnsupportedError(
        'Expected Unigram tokenizer, but found $modelType',
      );
    }

    final vocabList = model['vocab'] as List<dynamic>;
    _vocab = <String, int>{};

    for (var i = 0; i < vocabList.length; i++) {
      final row = vocabList[i];

      if (row is List && row.isNotEmpty) {
        final token = row[0].toString();
        _vocab[token] = i;
      }
    }

    _padId = _vocab['<pad>'] ?? _padId;
    _unkId = _vocab['<unk>'] ?? _unkId;
    _bosId = _vocab['<s>'] ?? _bosId;
    _eosId = _vocab['</s>'] ?? _eosId;
  }

  E5TokenizedInput encode(String text) {
    final pieces = <int>[];

    pieces.add(_bosId);

    final normalized = text.trim();
    final words = normalized.split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.trim().isEmpty) continue;

      final metaspaceWord = '▁$word';
      pieces.addAll(_encodePieceGreedy(metaspaceWord));
    }

    pieces.add(_eosId);

    final ids = pieces.take(maxLen).toList();

    if (ids.length == maxLen) {
      ids[maxLen - 1] = _eosId;
    }

    final mask = List<int>.filled(ids.length, 1);

    while (ids.length < maxLen) {
      ids.add(_padId);
      mask.add(0);
    }

    return E5TokenizedInput(
      inputIds: [ids],
      attentionMask: [mask],
    );
  }

  List<int> _encodePieceGreedy(String text) {
    final ids = <int>[];

    var start = 0;

    while (start < text.length) {
      var end = text.length;
      int? foundId;
      int? foundEnd;

      while (end > start) {
        final sub = text.substring(start, end);
        final id = _vocab[sub];

        if (id != null) {
          foundId = id;
          foundEnd = end;
          break;
        }

        end--;
      }

      if (foundId != null && foundEnd != null) {
        ids.add(foundId);
        start = foundEnd;
      } else {
        ids.add(_unkId);
        start++;
      }
    }

    return ids;
  }
}