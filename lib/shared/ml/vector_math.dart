// lib/shared/ml/vector_math.dart
import 'dart:math' as math;

double dotF32(List<double> a, List<double> b) {
  var s = 0.0;
  final n = a.length;
  for (var i = 0; i < n; i++) {
    s += a[i] * b[i];
  }
  return s;
}

double l2F32(List<double> a) {
  var s = 0.0;
  for (final x in a) {
    s += x * x;
  }
  return math.sqrt(s);
}

double cosineF32(List<double> a, List<double> b) {
  return dotF32(a, b) / (l2F32(a) * l2F32(b) + 1e-9);
}

List<int> topKCosineF32(List<double> q, List<List<double>> M, {int k = 10}) {
  final scores = <(int, double)>[];
  for (var i = 0; i < M.length; i++) {
    scores.add((i, cosineF32(q, M[i])));
  }
  scores.sort((a, b) => b.$2.compareTo(a.$2));
  final out = <int>[];
  for (final t in scores.take(k)) {
    out.add(t.$1);
  }
  return out;
}
