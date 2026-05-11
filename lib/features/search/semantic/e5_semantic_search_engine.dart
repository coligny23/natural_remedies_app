import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'e5_search_result.dart';

class E5SemanticSearchEngine {
  late final Interpreter _interpreter;
  late Float32List _indexVectors;
  late List<Map<String, dynamic>> _meta;

  late int _count;
  late int _dim;

  Future<void> init({
    required String modelPath,
    required String indexPath,
    required String metaPath,
  }) async {
    _interpreter = await Interpreter.fromAsset(modelPath);
    await _loadIndex(indexPath);
    await _loadMeta(metaPath);
  }

  Future<void> _loadIndex(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    final bd = ByteData.sublistView(bytes);

    _count = bd.getUint32(0, Endian.little);
    _dim = bd.getUint16(4, Endian.little);

    final vectorBytes = bytes.sublist(6);
    _indexVectors = vectorBytes.buffer.asFloat32List(
      vectorBytes.offsetInBytes,
      vectorBytes.lengthInBytes ~/ 4,
    );
  }

  Future<void> _loadMeta(String path) async {
    final text = await rootBundle.loadString(path);
    _meta = List<Map<String, dynamic>>.from(jsonDecode(text));
  }

  Float32List _l2Normalize(Float32List vector) {
    var sumSquares = 0.0;
    for (final v in vector) {
      sumSquares += v * v;
    }

    final norm = sqrt(sumSquares) + 1e-9;
    final out = Float32List(vector.length);

    for (var i = 0; i < vector.length; i++) {
      out[i] = vector[i] / norm;
    }

    return out;
  }

  Future<Float32List> encodeQuery(String query) async {
    final text = 'query: $query';

    // TODO: replace this with real E5 tokenizer.
    // Must return inputIds and attentionMask shaped [1, 128].
    final tokenized = await _tokenize(text);

    final inputDetails = _interpreter.getInputTensors();
    final outputDetails = _interpreter.getOutputTensors();

    final inputs = <Object>[
      tokenized.attentionMask,
      tokenized.inputIds,
    ];

    final output = List.generate(
      1,
      (_) => List<double>.filled(384, 0.0),
    );

    _interpreter.runForMultipleInputs(inputs, {0: output});

    final raw = Float32List.fromList(output.first);
    return _l2Normalize(raw);
  }

  Future<List<E5SearchResult>> search(
    String query, {
    int topK = 10,
    int topN = 50,
    double lexicalWeight = 0.0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final queryVector = await encodeQuery(q);

    final candidates = <E5SearchResult>[];

    for (var i = 0; i < _count; i++) {
      var semantic = 0.0;

      for (var j = 0; j < _dim; j++) {
        semantic += _indexVectors[i * _dim + j] * queryVector[j];
      }

      final item = _meta[i];
      final lexical = _lexicalScore(q, item);
      final finalScore = semantic + lexicalWeight * lexical;

      candidates.add(
        E5SearchResult(
          id: item['id'] as String,
          title: item['title'] as String? ?? '',
          titleSw: item['titleSw'] as String?,
          score: finalScore,
          semanticScore: semantic,
          lexicalScore: lexical,
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(topK).toList();
  }

  double _lexicalScore(String query, Map<String, dynamic> item) {
    final qTokens = _tokens(query);
    if (qTokens.isEmpty) return 0.0;

    final titleTokens = _tokens(item['title'] as String? ?? '');
    final titleSwTokens = _tokens(item['titleSw'] as String? ?? '');
    final idTokens = _tokens((item['id'] as String? ?? '').replaceAll('-', ' '));

    final aliases = item['aliasesSw'];
    final aliasText = aliases is List ? aliases.join(' ') : '';
    final aliasTokens = _tokens(aliasText);

    var hits = 0;
    hits += 2 * qTokens.intersection(titleTokens).length;
    hits += 3 * qTokens.intersection(titleSwTokens).length;
    hits += 3 * qTokens.intersection(aliasTokens).length;
    hits += qTokens.intersection(idTokens).length;

    return hits / qTokens.length;
  }

  Set<String> _tokens(String text) {
    final regex = RegExp(r"[a-zA-ZÀ-ÿ0-9']+");
    return regex
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((t) => t.length > 1)
        .toSet();
  }

  Future<_E5TokenizedInput> _tokenize(String text) async {
    throw UnimplementedError(
      'Implement tokenizer.json-based E5 tokenizer here.',
    );
  }

  void close() {
    _interpreter.close();
  }
}

class _E5TokenizedInput {
  final List<List<int>> inputIds;
  final List<List<int>> attentionMask;

  const _E5TokenizedInput({
    required this.inputIds,
    required this.attentionMask,
  });
}