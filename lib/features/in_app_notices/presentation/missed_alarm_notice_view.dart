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

/// One face per reason, so the card does not look the same for a phone that
/// slept through a push and a phone that rang for nobody.
FaceState missedAlarmFace(MissedReason reason) => switch (reason) {
  MissedReason.noPushReached => FaceState.dozing,
  MissedReason.pushButNoRing => FaceState.dizzy,
  MissedReason.rangUnanswered => FaceState.sad,
  MissedReason.unanswered => FaceState.concerned,
};

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
