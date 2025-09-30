import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _box = 'streak_v1';
const _kCount = 'count';
const _kLastDay = 'last_day'; // YYYY-MM-DD

final streakProvider = StateNotifierProvider<StreakController, int>((ref) {
  return StreakController()..load();
});

class StreakController extends StateNotifier<int> {
  StreakController(): super(0);

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }
  String _yesterday() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  Future<Box> _open() async => Hive.isBoxOpen(_box) ? Hive.box(_box) : await Hive.openBox(_box);

  Future<void> load() async {
    final b = await _open();
    state = (b.get(_kCount, defaultValue: 0) as num).toInt();
  }

  /// Call once per day on "meaningful activity" (app open or article view).
  Future<void> markActiveToday() async {
    final b = await _open();
    final last = b.get(_kLastDay) as String?;
    final today = _today();
    final yesterday = _yesterday();

    if (last == today) return; // already counted
    int next = 1;
    if (last == yesterday) {
      final prev = (b.get(_kCount, defaultValue: 0) as num).toInt();
      next = prev + 1;
    }
    await b.put(_kCount, next);
    await b.put(_kLastDay, today);
    state = next;
  }

  Future<void> reset() async {
    final b = await _open();
    await b.put(_kCount, 0);
    await b.put(_kLastDay, null);
    state = 0;
  }
}
