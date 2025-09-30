import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../shared/notifications/notifications_service.dart';

const _box = 'reminders_v1';
const _kEnabled = 'enabled';
const _kHour = 'hour';
const _kMinute = 'minute';
const _notifId = 101; // stable id

final reminderStateProvider = StateNotifierProvider<ReminderController, ReminderState>((ref) {
  return ReminderController()..load();
});

class ReminderState {
  final bool enabled;
  final int hour;
  final int minute;
  const ReminderState({required this.enabled, required this.hour, required this.minute});

  String get pretty => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ReminderController extends StateNotifier<ReminderState> {
  ReminderController()
      : super(const ReminderState(enabled: false, hour: 20, minute: 0)); // default 20:00

  Future<Box> _open() async => Hive.isBoxOpen(_box) ? Hive.box(_box) : await Hive.openBox(_box);

  Future<void> load() async {
    final b = await _open();
    final en = b.get(_kEnabled, defaultValue: false) as bool;
    final h = (b.get(_kHour, defaultValue: 20) as num).toInt();
    final m = (b.get(_kMinute, defaultValue: 0) as num).toInt();
    state = ReminderState(enabled: en, hour: h, minute: m);

    if (en) {
      await NotificationsService().scheduleDaily(
        _notifId,
        TimeOfDay(hour: h, minute: m),
        title: 'Natural Remedies',
        body: 'Open the app and learn one thing today.',
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final b = await _open();
    await b.put(_kEnabled, enabled);
    state = ReminderState(enabled: enabled, hour: state.hour, minute: state.minute);
    if (enabled) {
      await NotificationsService().scheduleDaily(
        _notifId,
        TimeOfDay(hour: state.hour, minute: state.minute),
        title: 'Natural Remedies',
        body: 'Open the app and learn one thing today.',
      );
    } else {
      await NotificationsService().cancel(_notifId);
    }
  }

  Future<void> setTime(int hour, int minute) async {
    final b = await _open();
    await b.put(_kHour, hour);
    await b.put(_kMinute, minute);
    state = ReminderState(enabled: state.enabled, hour: hour, minute: minute);

    if (state.enabled) {
      await NotificationsService().scheduleDaily(
        _notifId,
        TimeOfDay(hour: hour, minute: minute),
        title: 'Natural Remedies',
        body: 'Open the app and learn one thing today.',
      );
    }
  }
}
