/// Starts a plan pass. Screens and sheets call this after anything that
/// changes what should be planned: a switch, a sheet answer, a night ack.
// ignore: one_member_abstracts
abstract interface class ReminderPlanTrigger {
  Future<void> run();
}

/// Registered on web, which plans no reminders.
final class NoopReminderPlanTrigger implements ReminderPlanTrigger {
  const NoopReminderPlanTrigger();

  @override
  Future<void> run() async {}
}
