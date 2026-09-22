import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';

/// Web has no local notifications, so the dashboard plans nothing.
final class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> schedule(ReminderRequest request) async {}

  @override
  Future<void> cancel(List<int> ids) async {}

  @override
  Future<List<PendingReminder>> pending() async => const [];

  @override
  Future<ReminderSystemState> systemState() async =>
      const ReminderSystemState(notificationsAllowed: false);

  @override
  Future<DeviceTimeZone> deviceTimeZone() async => DeviceTimeZone.fromDart();

  @override
  Stream<ReminderTap> get taps => const Stream<ReminderTap>.empty();

  @override
  Future<ReminderTap?> takePendingTap() async => null;
}
