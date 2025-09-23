import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'telemetry.dart';

/// User consent (default OFF). You can persist this later if needed.
final telemetryEnabledProvider = StateProvider<bool>((_) => false);

final telemetryRepoProvider = Provider<TelemetryRepo>((_) => TelemetryRepo());

/// Convenience helper: safe logger that respects the toggle.
extension TelemetryX on WidgetRef {
  Future<void> logEvent(String type, Map<String, Object?> props) async {
    final enabled = read(telemetryEnabledProvider);
    if (!enabled) return;
    final repo = read(telemetryRepoProvider);
    await repo.log(TelemetryEvent(type: type, props: props));
  }
}
