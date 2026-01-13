import 'package:hive_flutter/hive_flutter.dart';

class ProfileRepo {
  static const boxName = 'ml_profile';
  static const keyVec = 'profile_vec'; // List<double>

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  List<double>? readVec() {
    final box = Hive.box(boxName);
    final raw = box.get(keyVec);
    if (raw is List) {
      return raw.cast<num>().map((e) => e.toDouble()).toList();
    }
    return null;
  }

  Future<void> writeVec(List<double> v) async {
    final box = Hive.box(boxName);
    await box.put(keyVec, v);
  }

  Future<void> clear() async {
    final box = Hive.box(boxName);
    await box.clear();
  }
}
