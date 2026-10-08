import 'dart:convert';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:crypto/crypto.dart';

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
///   was "open", for the account it is on now ([openNoteCountsFor]).
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

/// The tag the note "the last sure answer was open" is kept under for
/// [accountId]: a hash, so the account id itself is not written a second
/// time. Null for an account that is not known.
String? alarmStyleAccountTag(String? accountId) {
  if (accountId == null || accountId.isEmpty) return null;
  return sha256.convert(utf8.encode(accountId)).toString().substring(0, 16);
}

/// Whether the note counts for the account this phone is on now.
///
/// The note belongs to one account. Preferences can travel to another
/// phone in a backup, and a note that arrives that way, for another
/// account or with no account known, is no note at all.
bool openNoteCountsFor({
  required String? noteTag,
  required String? accountTag,
}) => noteTag != null && accountTag != null && noteTag == accountTag;

/// What the note "the last sure answer was open" becomes after [decision],
/// given what is [written] now. The note is the tag of the account the
/// answer was for, or null for no note.
///
/// [decision] is the answer asked once the plan was read, or null when
/// nobody knows. Only a sure answer changes the note:
///
/// - Open, or a purchase being confirmed: the note is [accountTag]. With
///   no account known there is nobody to note it for, and the note goes.
/// - Locked: the note goes.
/// - Anything else: the note stays as it is.
String? openNoteAfter({
  required String? written,
  required FeatureDecision? decision,
  required String? accountTag,
}) => switch (decision) {
  FeatureOpen() || FeatureConfirming() => accountTag,
  FeatureLocked() => null,
  FeatureUnread() || null => written,
};
