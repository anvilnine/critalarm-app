/// Starts a plan pass. Screens and sheets call this after anything that
/// changes what should be planned: a switch, a sheet answer, a night ack.
// ignore: one_member_abstracts
abstract interface class LocalReminderPlanTrigger {
  Future<void> run();
}

/// Registered on web, which plans no reminders.
final class NoopLocalReminderPlanTrigger implements LocalReminderPlanTrigger {
  const NoopLocalReminderPlanTrigger();

  @override
  Future<void> run() async {}
}
