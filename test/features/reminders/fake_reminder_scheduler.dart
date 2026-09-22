import 'dart:async';

import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';

class FakeReminderScheduler implements ReminderScheduler {
  final Map<int, ReminderRequest> scheduled = {};
  final List<List<int>> cancelled = [];
  final StreamController<ReminderTap> tapController =
      StreamController<ReminderTap>.broadcast();

  /// Ids the platform holds that this fake did not schedule itself, such as
  /// an incident notification or a lab test fire.
  final Set<int> otherPending = {};

  ReminderSystemState state = const ReminderSystemState(
    notificationsAllowed: true,
  );
  DeviceTimeZone timeZone = DeviceTimeZone.utc;
  ReminderTap? pendingTap;

  @override
  Future<void> schedule(ReminderRequest request) async {
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
  Future<ReminderSystemState> systemState() async => state;

  @override
  Future<DeviceTimeZone> deviceTimeZone() async => timeZone;

  @override
  Stream<ReminderTap> get taps => tapController.stream;

  @override
  Future<ReminderTap?> takePendingTap() async {
    final tap = pendingTap;
    pendingTap = null;
    return tap;
  }
}
