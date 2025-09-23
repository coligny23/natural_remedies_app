import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Minimal event schema: one line per event (JSONL).
class TelemetryEvent {
  final String type;                 // e.g., "search", "open_article"
  final Map<String, Object?> props;  // freeform properties
  final DateTime ts;

  TelemetryEvent({required this.type, required this.props, DateTime? ts})
      : ts = ts ?? DateTime.now();

  Map<String, Object?> toJson() => {
        "type": type,
        "ts": ts.toIso8601String(),
        "props": props,
      };

  @override
  String toString() => jsonEncode(toJson());
}

class TelemetryRepo {
  static const _boxName = 'telemetry_v1'; // String list (JSONL lines)

  Future<Box<String>> _box() async => Hive.openBox<String>(_boxName);

  Future<void> log(TelemetryEvent e) async {
    final b = await _box();
    // Append line; store as a monotonically increasing key
    final key = 'e_${DateTime.now().microsecondsSinceEpoch}';
    await b.put(key, e.toString());
    if (kDebugMode) debugPrint('telemetry: $key ${e.type}');
  }

  Future<List<String>> dumpLines() async {
    final b = await _box();
    // Return values ordered by key (roughly chronological)
    final keys = b.keys.map((e) => e as String).toList()..sort();
    return [for (final k in keys) b.get(k)!];
  }

  Future<void> clear() async {
    final b = await _box();
    await b.clear();
  }

  Future<int> count() async {
    final b = await _box();
    return b.length;
  }
}
