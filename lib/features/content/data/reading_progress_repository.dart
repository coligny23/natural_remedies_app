import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final readingProgressRepoProvider = Provider<ReadingProgressRepo>((_) => ReadingProgressRepo());

class ReadingProgress {
  final String? section;
  final double? offset;
  ReadingProgress({this.section, this.offset});
}

class ReadingProgressRepo {
  static const _boxName = 'reading_progress_v1'; // String -> JSON

  Future<Box<String>> _box() async {
    return await Hive.openBox<String>(_boxName);
  }

  Future<void> save(String articleId, {String? section, double? offset}) async {
    final b = await _box();
    final jsonStr = jsonEncode({"section": section, "offset": offset});
    await b.put(articleId, jsonStr);
    if (kDebugMode) debugPrint('Saved progress $articleId → $jsonStr');
  }

  Future<ReadingProgress?> load(String articleId) async {
    final b = await _box();
    final s = b.get(articleId);
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return ReadingProgress(
        section: m["section"] as String?,
        offset: (m["offset"] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
