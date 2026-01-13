// lib/shared/ml/index_loader.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

class IndexRow {
  final String id;
  final String title;
  final String lang;
  IndexRow(this.id, this.title, this.lang);
}

/// Full in-memory index (simple + safest for Day 3).
class EmbeddingIndex {
  final int n;
  final int d;
  final List<List<double>> vecs; // N rows of D
  final List<IndexRow> meta;
  EmbeddingIndex(this.n, this.d, this.vecs, this.meta);
}

/// Loads the compact binary index:
/// index.bin = [uint32 N][uint16 D][N*D float32]
Future<EmbeddingIndex> loadIndex() async {
  // Load vectors
  final bin = await rootBundle.load('assets/embeddings/index.bin');
  final bytes = bin.buffer.asByteData();
  var off = 0;

  final n = bytes.getUint32(off, Endian.little);
  off += 4;
  final d = bytes.getUint16(off, Endian.little);
  off += 2;

  final floats = bin.buffer.asFloat32List(off, n * d);

  // Row-slice into List<List<double>> (simple & clear for Day 3)
  final vecs = <List<double>>[];
  vecs.length = n;
  for (var i = 0; i < n; i++) {
    final row = List<double>.generate(d, (j) => floats[i * d + j].toDouble(), growable: false);
    vecs[i] = row;
  }

  // Load meta
  final metaStr = await rootBundle.loadString('assets/embeddings/meta.json');
  final raw = json.decode(metaStr) as List;
  final meta = <IndexRow>[
    for (final m in raw) IndexRow(m['id'] as String, m['title'] as String, (m['lang'] ?? 'en') as String),
  ];

  return EmbeddingIndex(n, d, vecs, meta);
}
