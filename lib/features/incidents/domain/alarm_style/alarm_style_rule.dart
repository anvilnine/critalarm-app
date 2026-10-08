import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';

/// Which look the alarm screen draws.
///
/// This is the one place that says what a saved look turns into. The saved
/// choices are never changed by it: a look picked while the plan was held
/// is kept, and draws again the moment the plan is held again.
///
/// - [saved] is what the phone holds.
/// - [topicName] is the topic that rings. Null asks for the phone's own
///   look.
/// - [decision] is the access layer's answer for alarm screen styles.
/// - [isPlanRead] is false until the access layer has read the plan and
///   the saved server. Before that a "locked" can be wrong, so it counts
///   as "could not be read".
/// - [wasOpenWhenLastSure] is the phone's note that the last sure answer
///   was "open".
/// - [isSetupAlarm] is true for an alarm setup itself caused, or a test
///   run again from Settings. Those screens have their own layout and
///   always draw the standard look.
///
/// In order:
///
/// 1. A setup alarm: standard.
/// 2. Nothing saved, the standard look saved, or an id this build does not
///    know: standard.
/// 3. Open, or a purchase being confirmed: the saved look.
/// 4. Locked, and the plan was read: standard.
/// 5. The plan could not be read, or a "locked" from before it was read:
///    the saved look when the last sure answer was "open", else standard.
///
/// When in doubt the answer is the standard look, which is the alarm
/// screen everyone has.
AlarmStyleId alarmStyleFor({
  required AlarmStyleAssignments saved,
  required FeatureDecision decision,
  required bool isPlanRead,
  required bool wasOpenWhenLastSure,
  String? topicName,
  bool isSetupAlarm = false,
}) {
  if (isSetupAlarm) return AlarmStyleId.standard;
  final chosen = AlarmStyleId.fromId(saved.styleIdFor(topicName));
  if (chosen == null || chosen.isFree) return AlarmStyleId.standard;
  return switch (decision) {
    FeatureOpen() || FeatureConfirming() => chosen,
    FeatureLocked() when isPlanRead => AlarmStyleId.standard,
    FeatureLocked() ||
    FeatureUnread() => wasOpenWhenLastSure ? chosen : AlarmStyleId.standard,
  };
}

/// What the note "the last sure answer was open" becomes after [decision],
/// given what is [written] now.
///
/// [decision] is the answer asked once the plan was read, or null when
/// nobody knows. Only a sure answer changes the note: open or a purchase
/// being confirmed sets it, locked clears it, and anything else leaves it
/// as it is.
bool openWhenLastSureAfter({
  required bool written,
  required FeatureDecision? decision,
}) => switch (decision) {
  FeatureOpen() || FeatureConfirming() => true,
  FeatureLocked() => false,
  FeatureUnread() || null => written,
};
