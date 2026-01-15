import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'tokenizer.dart';
import '../vector_math.dart'; // for l2F32

// Load TFLite + tokenizer once
final _embedRuntimeProvider = FutureProvider<_EmbedRuntime>((ref) async {
  // If web, bail out early (TFLite not supported)
  if (kIsWeb) throw 'TFLite not supported on web';

  final options = InterpreterOptions()
    ..threads = 2;

  // Prefer NNAPI on Android
  if (defaultTargetPlatform == TargetPlatform.android) {
    options.useNnApiForAndroid = true;
  }

  // Add XNNPACK delegate where available for CPU speedups
  try {
    options.addDelegate(XNNPackDelegate(options: XNNPackDelegateOptions(numThreads: 2)));
  } catch (_) {
    // Safe to ignore if not available on platform
  }

  // NOTE: In tflite_flutter, fromAsset() expects the path as listed in pubspec,
  // without the leading 'assets/'. If your pubspec has `- assets/models/encoder.tflite`
  // then pass 'models/encoder.tflite' here.
  final interp = await Interpreter.fromAsset('models/encoder.tflite', options: options);

  final tok = await WordPieceTokenizer.fromAsset('assets/models/vocab.txt', doLowerCase: true);
  return _EmbedRuntime(interp, tok);
});

class _EmbedRuntime {
  final Interpreter interp;
  final WordPieceTokenizer tok;
  _EmbedRuntime(this.interp, this.tok);
}

// LRU cache for recent embeddings (avoid re-encoding same query/text)
class _Lru<K, V> {
  final int cap;
  final _map = <K, V>{};
  final _order = <K>[];
  _Lru(this.cap);
  V? get(K k) {
    final v = _map[k];
    if (v != null) {
      _order.remove(k);
      _order.add(k);
    }
    return v;
  }

  void set(K k, V v) {
    if (_map.containsKey(k)) _order.remove(k);
    _map[k] = v;
    _order.add(k);
    if (_order.length > cap) {
      final old = _order.removeAt(0);
      _map.remove(old);
    }
  }
}

final _cacheProvider = Provider((_) => _Lru<String, List<double>>(64));

/// Public provider: returns a 384-d L2-normalized embedding for [text].
final embedTextProvider = Provider.family<List<double>, String>((ref, text) {
  // 1) cache check
  final cache = ref.read(_cacheProvider);
  final cached = cache.get(text);
  if (cached != null) return cached;

  // 2) try real runtime
  final runtime =
      ref.watch(_embedRuntimeProvider).maybeWhen(data: (r) => r, orElse: () => null);

  if (runtime == null) {
    // Fallback to your existing stub while interpreter loads
    const dim = 384;
    final v = List<double>.filled(dim, 0.0);
    for (var i = 0; i < text.length; i++) {
      v[i % dim] += (text.codeUnitAt(i) % 31) / 31.0;
    }
    final inv = 1.0 / (l2F32(v) + 1e-9);
    for (var i = 0; i < v.length; i++) v[i] *= inv;
    cache.set(text, v);
    return v;
  }

  // 3) tokenize -> run -> normalize
  const maxLen = 128;
  final ids = runtime.tok.encode(text, maxLen: maxLen); // List<int> length <= 128
  final mask = runtime.tok.attentionMaskFor(ids);       // List<int> length <= 128

  // Pad/truncate to exactly 128 to match the model’s fixed input shape
  List<int> _pad128(List<int> src, {int pad = 0}) {
    if (src.length == maxLen) return src;
    if (src.length > maxLen) return src.sublist(0, maxLen);
    final out = List<int>.from(src);
    out.addAll(List<int>.filled(maxLen - src.length, pad));
    return out;
    }

  final ids128 = _pad128(ids, pad: 0);
  final mask128 = _pad128(mask, pad: 0);

  // TFLite inputs: int32 [1, 128], int32 [1, 128]
  final inputIds = <List<int>>[ids128];
  final attnMask = <List<int>>[mask128];

  // Output: float32 [1, 384]
  final output = List<List<double>>.generate(1, (_) => List<double>.filled(384, 0.0),
      growable: false);

  // runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs)
  final inputs = <Object>[inputIds, attnMask];
  final outputs = <int, Object>{0: output};

  runtime.interp.runForMultipleInputs(inputs, outputs);

  final emb = List<double>.from(output[0]); // [384]
  // L2 normalize
  final inv = 1.0 / (l2F32(emb) + 1e-9);
  for (var i = 0; i < emb.length; i++) emb[i] *= inv;

  cache.set(text, emb);
  return emb;
});
