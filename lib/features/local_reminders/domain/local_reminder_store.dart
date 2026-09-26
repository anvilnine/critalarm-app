import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/domain/planned_record.dart';

/// Everything the reminders feature keeps on the phone. Times are instants.
abstract interface class LocalReminderStore {
  /// Reads the preferences file again. Native code writes to it while the
  /// app is in the background.
  Future<void> reload();

  LocalReminderSwitches readSwitches();
  Future<void> writeSwitches(LocalReminderSwitches switches);

  /// The last successful test ring per topic.
  Map<String, DateTime> readLastTestAt();
  Future<void> markTested(String topic, DateTime at);

  /// The last test that answered 409, 401 or never left the phone.
  DateTime? readLastTestFailedAt();
  Future<void> markTestFailed(DateTime at);

  int? readDrillLastIndex();
  Future<void> writeDrillLastIndex(int index);

  bool readSheetShown();
  Future<void> markSheetShown();

  DateTime? readBudgetSpentAt();
  Future<void> writeBudgetSpentAt(DateTime at);

  List<PlannedRecord> readPlanned();
  Future<void> writePlanned(List<PlannedRecord> records);

  /// `reminder_review_fire_at`: a planned idea 21 not yet settled.
  DateTime? readReviewFireAt();
  Future<void> writeReviewFireAt(DateTime? at);

  /// `reminder_feedback_fire_at`: a planned idea 22 not yet settled.
  DateTime? readFeedbackFireAt();
  Future<void> writeFeedbackFireAt(DateTime? at);

  Map<String, DateTime> readTopicsCreatedHere();
  Future<void> recordTopicCreatedHere(String topic, DateTime at);

  Set<String> readSilentDone();
  Future<void> addSilentDone(String topic);

  Set<String> readPlanHeadsUpsSent();
  Future<void> addPlanHeadsUpSent(String key);

  Set<String> readMorningAfterDone();
  Future<void> addMorningAfterDone(String incidentId);

  bool readProSheetOwed();
  Future<void> writeProSheetOwed({required bool owed});

  bool readSkipRules();
  Future<void> writeSkipRules({required bool skip});

  /// True once after native code recorded a "Not now" tap on the morning
  /// after notification, then false until the next one.
  Future<bool> takePendingProDismiss();

  /// The Reminder lab's reset: every flag, test time and the sheet-shown
  /// flag.
  Future<void> resetAll();
}
