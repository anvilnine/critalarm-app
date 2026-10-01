import 'dart:async';

import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';

class FakeLocalReminderScheduler implements LocalReminderScheduler {
  final Map<int, LocalReminderRequest> scheduled = {};
  final List<List<int>> cancelled = [];
  final StreamController<LocalReminderTap> tapController =
      StreamController<LocalReminderTap>.broadcast();

  /// Ids the platform holds that this fake did not schedule itself, such as
  /// an incident notification or a lab test fire.
  final Set<int> otherPending = {};

  LocalReminderSystemState state = const LocalReminderSystemState(
    notificationsAllowed: true,
  );
  DeviceTimeZone timeZone = DeviceTimeZone.utc;
  LocalReminderTap? pendingTap;

  @override
  Future<void> schedule(LocalReminderRequest request) async {
    scheduled[request.id] = request;
  }

  @override
  Future<void> cancel(List<int> ids) async {
    cancelled.add(List.of(ids));
    ids.forEach(scheduled.remove);
    otherPending.removeAll(ids);
  }

  @override
  Future<List<PendingReminder>> pending() async => [
    for (final request in scheduled.values)
      PendingReminder(
        id: request.id,
        kind: request.kind,
        fireAt: request.fireAt,
      ),
    for (final id in otherPending) PendingReminder(id: id),
  ];

  @override
  Future<LocalReminderSystemState> systemState() async => state;

  @override
  Future<DeviceTimeZone> deviceTimeZone() async => timeZone;

  @override
  Stream<LocalReminderTap> get taps => tapController.stream;

  @override
  Future<LocalReminderTap?> takePendingTap() async {
    final tap = pendingTap;
    pendingTap = null;
    return tap;
  }
}
