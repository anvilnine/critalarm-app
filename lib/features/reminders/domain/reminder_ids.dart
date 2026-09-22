import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Notification ids. Each kind owns a range so a plan pass can cancel what it
/// planned and nothing else: incident notifications and the lab's test fires
/// are never touched.
abstract final class ReminderIds {
  static const int drill = 9100;
  static const int drillLast = 9199;
  static const int silentFirst = 9200;
  static const int silentLast = 9299;
  static const int backup = 9300;
  static const int planFirst = 9350;
  static const int planLast = 9359;
  static const int morningAfter = 9400;
  static const int proLater = 9410;
  static const int reviewAsk = 9500;
  static const int feedbackAsk = 9510;

  /// Fired by hand from the Reminder lab. Outside every planned range.
  static const int labFirst = 9590;

  static int silent(int index) =>
      silentFirst + index % (silentLast - silentFirst + 1);

  static int lab(ReminderKind kind) => labFirst + kind.index;

  /// True for an id a plan pass owns and may cancel.
  static bool isPlanned(int id) =>
      (id >= drill && id <= drillLast) ||
      (id >= silentFirst && id <= silentLast) ||
      id == backup ||
      (id >= planFirst && id <= planLast) ||
      id == morningAfter ||
      id == proLater ||
      id == reviewAsk ||
      id == feedbackAsk;

  /// The kind a planned id belongs to. Null for any id outside the planned
  /// ranges.
  static ReminderKind? kindOf(int id) {
    if (id >= drill && id <= drillLast) return ReminderKind.fireDrill;
    if (id >= silentFirst && id <= silentLast) return ReminderKind.silentTopic;
    if (id == backup) return ReminderKind.backup;
    if (id >= planFirst && id <= planLast) return ReminderKind.planHeadsUp;
    if (id == morningAfter) return ReminderKind.morningAfter;
    if (id == proLater) return ReminderKind.proLater;
    if (id == reviewAsk) return ReminderKind.reviewAsk;
    if (id == feedbackAsk) return ReminderKind.feedbackAsk;
    return null;
  }

  /// True for any reminder id, the lab's included.
  static bool isReminder(int id) =>
      isPlanned(id) ||
      (id >= labFirst && id < labFirst + ReminderKind.values.length);
}
