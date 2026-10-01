import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';

/// Web has no local notifications, so the dashboard plans nothing.
final class NoopLocalReminderScheduler implements LocalReminderScheduler {
  const NoopLocalReminderScheduler();

  @override
  Future<void> schedule(LocalReminderRequest request) async {}

  @override
  Future<void> cancel(List<int> ids) async {}

  @override
  Future<List<PendingReminder>> pending() async => const [];

  @override
  Future<LocalReminderSystemState> systemState() async =>
      const LocalReminderSystemState(notificationsAllowed: false);

  @override
  Future<DeviceTimeZone> deviceTimeZone() async => DeviceTimeZone.fromDart();

  @override
  Stream<LocalReminderTap> get taps => const Stream<LocalReminderTap>.empty();

  @override
  Future<LocalReminderTap?> takePendingTap() async => null;
}
