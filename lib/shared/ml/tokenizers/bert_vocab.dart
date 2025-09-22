import 'package:flutter/services.dart' show rootBundle;

class BertVocab {
  final Map<String, int> tokenToId;
  final List<String> idToToken;
  BertVocab(this.tokenToId, this.idToToken);

  static Future<BertVocab> fromAsset(String path) async {
    final s = await rootBundle.loadString(path);
    final lines = s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final t2i = <String,int>{};
    final i2t = <String>[];
    var idx = 0;
    for (final tok in lines) {
      t2i[tok] = idx++;
      i2t.add(tok);
    }
    return BertVocab(t2i, i2t);
  }

  int? idOf(String tok) => tokenToId[tok];
}
