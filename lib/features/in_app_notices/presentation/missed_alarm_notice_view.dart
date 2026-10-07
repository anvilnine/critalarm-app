import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:intl/intl.dart';

// What Home's missed alarm entry decides without drawing: which words and
// which face go with a reason, and how its time reads. Pure, so it is unit
// tested and the card only draws what it is handed.

/// The few words for why, as a `LocaleKeys` key.
String missedAlarmReasonKey(MissedReason reason) => switch (reason) {
  MissedReason.noPushReached => LocaleKeys.notices_missed_alarm_reason_no_push,
  MissedReason.pushButNoRing =>
    LocaleKeys.notices_missed_alarm_reason_push_no_ring,
  MissedReason.rangUnanswered => LocaleKeys.notices_missed_alarm_reason_rang,
  MissedReason.unanswered => LocaleKeys.notices_missed_alarm_reason_unanswered,
};

/// What the card's one button does. The words say what the person will do:
/// ring a test, or look at the alarm. Neither names a screen.
enum MissedAlarmAction {
  /// The phone cannot be shown to have done its part, so the next step is a
  /// test alarm. Opens the same test alarm screen as the Reliability screen.
  ringTest,

  /// The phone did its part, so the useful thing is the alarm itself. Opens
  /// that incident.
  seeAlarm,
}

/// The action that fits [reason].
MissedAlarmAction missedAlarmAction(MissedReason reason) => switch (reason) {
  MissedReason.noPushReached ||
  MissedReason.pushButNoRing => MissedAlarmAction.ringTest,
  MissedReason.rangUnanswered ||
  MissedReason.unanswered => MissedAlarmAction.seeAlarm,
};

/// The button's label for [reason], as a `LocaleKeys` key.
String missedAlarmButtonKey(MissedReason reason) => switch (missedAlarmAction(
  reason,
)) {
  MissedAlarmAction.ringTest => LocaleKeys.notices_missed_alarm_button_test,
  MissedAlarmAction.seeAlarm => LocaleKeys.notices_missed_alarm_button_incident,
};

/// The line under the title: the topic and time for a single missed alarm,
/// and for several the same words led by "Latest", so the reason under it
/// reads as being about that one.
String missedAlarmWhenKey({required int count}) => count > 1
    ? LocaleKeys.notices_missed_alarm_latest
    : LocaleKeys.notices_missed_alarm_when;

/// The face of a missed alarm notice. A missed alarm needs a look, so every
/// reason wears the one look face (`face_meaning.dart`). The reason is in
/// the words, never in the face. [reason] is kept so callers that hold one
/// need not change.
FaceState missedAlarmFace(MissedReason reason) => needsLookFace;

/// When the alarm ran out, in the phone's own time: the hour alone for
/// today, the weekday with it for any other day in the week it is shown.
String missedAlarmTime(DateTime at, {required DateTime now}) {
  final local = at.toLocal();
  final today = now.toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return DateFormat(sameDay ? 'HH:mm' : 'EEE HH:mm').format(local);
}
