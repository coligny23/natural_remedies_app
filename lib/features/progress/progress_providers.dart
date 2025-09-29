import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _boxName = 'progress_v1';

/// Each entry: { articleId: { "lastSection": "id", "percent": 0.6, "qaAsked": 4 } }
final progressProvider = StateNotifierProvider<ProgressController, Map<String, Map>>((ref) {
  return ProgressController();
});

class ProgressController extends StateNotifier<Map<String, Map>> {
  ProgressController() : super(const {}) { _load(); }

  Future<Box> _box() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);

  Future<void> _load() async {
    final b = await _box();
    state = Map<String, Map>.from(b.toMap().cast());
  }

  Future<void> update(String articleId, {String? lastSection, double? percent, int? qaAsked}) async {
    final b = await _box();
    final existing = Map<String, dynamic>.from(b.get(articleId, defaultValue: {}) as Map);
    if (lastSection != null) existing['lastSection'] = lastSection;
    if (percent != null) existing['percent'] = percent;
    if (qaAsked != null) existing['qaAsked'] = (existing['qaAsked'] ?? 0) + qaAsked;
    
    existing['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    
    await b.put(articleId, existing);
    await _load();
  }

  Future<void> clear() async {
    final b = await _box();
    await b.clear();
    state = {};
  }
}
