import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// Everything the Reliability screen decides without drawing: which rows, in
// what order, which words and which face. Pure, so it is unit tested and the
// widgets only draw what they are handed. Words are `LocaleKeys` strings,
// translated by the widget.

/// The checks to draw, the ones that need attention first.
///
/// Checks that are not on this phone are dropped. Inside one state the order
/// the sources gave is kept.
List<ReliabilityCheck> orderReliabilityChecks(
  Iterable<ReliabilityCheck> checks,
) {
  final shown = [
    for (final check in checks)
      if (check.state.isOnThisPhone) check,
  ];
  // List.sort is not stable, so the position breaks ties.
  final indexed = shown.asMap().entries.toList()
    ..sort((a, b) {
      final byState = _rank(a.value.state).compareTo(_rank(b.value.state));
      return byState != 0 ? byState : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}

int _rank(ReliabilityState state) => switch (state) {
  ReliabilityState.broken => 0,
  ReliabilityState.needsLook => 1,
  ReliabilityState.fine => 2,
  ReliabilityState.notOnThisPhone => 3,
};

/// The row title for a check, as a `LocaleKeys` key. Null for an id this
/// screen has no words for yet: the row then shows the id itself.
String? reliabilityTitleKey(ReliabilityCheckId id) => _titleKeys[id.value];

const _titleKeys = <String, String>{
  'notifications': LocaleKeys.reliability_check_notifications,
  'full_screen_alarm': LocaleKeys.reliability_check_full_screen_alarm,
  'battery_optimization': LocaleKeys.reliability_check_battery_optimization,
  'alarms': LocaleKeys.reliability_check_alarms,
  'time_sensitive': LocaleKeys.reliability_check_time_sensitive,
  'push_token_confirmed': LocaleKeys.reliability_check_push_token,
  'last_push_received': LocaleKeys.reliability_check_last_push,
  'system_update': LocaleKeys.reliability_check_system_update,
  'phone_maker': LocaleKeys.maker_guide_row_title,
  'missed_alarm': LocaleKeys.reliability_check_missed_alarm,
};

/// The title a row shows, as a `LocaleKeys` key, or null for an id this
/// screen has no words for.
///
/// Two checks read wrong next to a tick under their plain name ("Missed
/// alarm" with a tick reads as an alarm that was missed), so a fine one
/// says what the tick means. A fine check that still carries a reason keeps
/// its plain name: its line says what happened.
String? reliabilityRowTitleKey(ReliabilityCheck check) {
  if (check.state == ReliabilityState.fine && check.reason == null) {
    final fine = _fineTitleKeys[check.id.value];
    if (fine != null) return fine;
  }
  return reliabilityTitleKey(check.id);
}

const _fineTitleKeys = <String, String>{
  'missed_alarm': LocaleKeys.reliability_check_missed_alarm_fine,
  'system_update': LocaleKeys.reliability_check_system_update_fine,
};

/// A string and what goes in its `{}` slots.
typedef ReliabilityWords = ({String key, Map<String, String> args});

/// The one short line under a row's title, as a `LocaleKeys` key, picked from
/// the check's reason code. Null for a fine check, which stays quiet.
///
/// A reason this screen does not know still gets a line, by state, so a
/// source can ship a new code before the words exist.
///
/// One fine check has a line: a missed alarm that rang. The phone did its
/// part, and the row still says what happened.
///
/// The missed alarm lines name a topic and a time, so they need the
/// arguments [reliabilityLine] adds.
String? reliabilityLineKey(ReliabilityCheck check) {
  if (check.state == ReliabilityState.notOnThisPhone) return null;
  if (check.state == ReliabilityState.fine) {
    return check.reason == _missedRang
        ? LocaleKeys.reliability_line_missed_rang
        : null;
  }
  if (check.fix is MissedAlarmFix) {
    final when = _missedLineKeys[check.reason];
    if (when != null) return when;
  }
  return _lineKeys[check.reason] ??
      (check.state == ReliabilityState.broken
          ? LocaleKeys.reliability_line_broken_generic
          : LocaleKeys.reliability_line_look_generic);
}

/// The line under a row's title with its arguments filled in: for a missed
/// alarm, the topic and the time Home's notice shows for it.
ReliabilityWords? reliabilityLine(
  ReliabilityCheck check, {
  required DateTime now,
}) {
  final key = reliabilityLineKey(check);
  if (key == null) return null;
  final fix = check.fix;
  return (
    key: key,
    args: fix is MissedAlarmFix && _missedLineKeys.containsValue(key)
        ? {'topic': fix.topic, 'time': missedAlarmTime(fix.at, now: now)}
        : const {},
  );
}

const _missedRang = 'missed_rang';

/// A missed alarm that needs a look, by reason. Each names the alarm.
const _missedLineKeys = <String, String>{
  'missed_no_push': LocaleKeys.reliability_line_missed_no_push_when,
  'missed_push_no_ring': LocaleKeys.reliability_line_missed_push_no_ring_when,
  'missed_unanswered': LocaleKeys.reliability_line_missed_unanswered_when,
};

const _lineKeys = <String, String>{
  'refused': LocaleKeys.reliability_line_refused,
  'never': LocaleKeys.reliability_line_never,
  'stale': LocaleKeys.reliability_line_stale,
  'silent': LocaleKeys.reliability_line_silent,
  // A clock that was set back. Three sources give it.
  'clock': LocaleKeys.reliability_line_clock,
  'time_sensitive_off': LocaleKeys.reliability_line_time_sensitive_off,
  'scheduled_summary': LocaleKeys.reliability_line_scheduled_summary,
  'os_changed': LocaleKeys.reliability_line_os_changed,
  'maker_unchecked': LocaleKeys.maker_guide_line_unchecked,
  'maker_os_changed': LocaleKeys.maker_guide_line_os_changed,
  _missedRang: LocaleKeys.reliability_line_missed_rang,
  // A permission's reason is its status name.
  'denied': LocaleKeys.reliability_line_denied,
  'restricted': LocaleKeys.reliability_line_restricted,
  'notDetermined': LocaleKeys.reliability_line_not_determined,
};

/// What a fine row shows where its tick would be, or null for the tick.
///
/// Only "Last push" has one: when the last push came, since a tick alone
/// would say a push arrived on a phone that never received one. With none
/// on record it says so. A time after [now] (a clock that was set back)
/// cannot be told as "ago", so the tick stays.
ReliabilityWords? reliabilityFineValue(
  ReliabilityCheck check, {
  required DateTime now,
}) {
  if (check.id != ReliabilityCheckIds.lastPushReceived ||
      check.state != ReliabilityState.fine) {
    return null;
  }
  final last = check.lastKnownGood;
  if (last == null) {
    return (key: LocaleKeys.reliability_last_push_none, args: const {});
  }
  if (last.isAfter(now)) return null;
  return (
    key: LocaleKeys.reliability_last_push_ago,
    args: {'when': reliabilityAgo(now.difference(last))},
  );
}

/// How long ago, in one unit: minutes under an hour, hours under a day,
/// days after that. Rounded down, and never less than a minute.
String reliabilityAgo(Duration since) {
  if (since.inMinutes < 60) {
    return '${since.inMinutes < 1 ? 1 : since.inMinutes} min';
  }
  if (since.inHours < 24) return '${since.inHours} h';
  return '${since.inDays} d';
}

/// The state word on a row, as a `LocaleKeys` key. Fine, check or broken.
String reliabilityStateKey(ReliabilityState state) => switch (state) {
  ReliabilityState.fine ||
  ReliabilityState.notOnThisPhone => LocaleKeys.reliability_state_fine,
  ReliabilityState.needsLook => LocaleKeys.reliability_state_look,
  ReliabilityState.broken => LocaleKeys.reliability_state_broken,
};

/// The label on a row's one action, as a `LocaleKeys` key. [testRouteName] is
/// the name of the test alarm route, so a route fix to it reads "Ring a
/// test" and any other route reads "Open".
String reliabilityFixLabelKey(
  ReliabilityFix fix, {
  required String testRouteName,
}) => switch (fix) {
  OpenSystemSettingsFix() => LocaleKeys.reliability_fix_open_settings,
  AskPermissionFix() => LocaleKeys.reliability_fix_allow,
  MissedAlarmFix() => LocaleKeys.reliability_fix_ring_test,
  RunFix() => LocaleKeys.reliability_fix_try_again,
  OpenRouteFix(:final routeName) =>
    routeName == testRouteName
        ? LocaleKeys.reliability_fix_ring_test
        : routeName == makerGuideRouteName
        ? LocaleKeys.maker_guide_fix_see_steps
        : LocaleKeys.reliability_fix_open,
};

/// The label on a row's second, quieter action, as a `LocaleKeys` key, or
/// null when the fix has none. Only a missed alarm has one: closing its
/// entry, as closing the notice on Home does.
String? reliabilityClearLabelKey(ReliabilityFix? fix) => switch (fix) {
  MissedAlarmFix() => LocaleKeys.reliability_fix_got_it,
  _ => null,
};

/// The index in [ordered] of the row whose action is the screen's one
/// primary button: the first row that is not fine and has something to do.
/// Every later action is drawn quieter. Null when no row has an action.
///
/// It reads the state and the fix only, so a check from any source counts.
int? reliabilityPrimaryRow(List<ReliabilityCheck> ordered) {
  for (var i = 0; i < ordered.length; i++) {
    final check = ordered[i];
    final needsAction =
        check.state == ReliabilityState.needsLook ||
        check.state == ReliabilityState.broken;
    if (needsAction && check.fix != null) return i;
  }
  return null;
}

/// Whether a row sits on the system permissions. Those rows also open the
/// permissions screen when tapped, so it stays reachable.
bool isPermissionCheck(ReliabilityCheckId id) => _permissionIds.contains(id);

const _permissionIds = <ReliabilityCheckId>{
  ReliabilityCheckIds.notifications,
  ReliabilityCheckIds.fullScreenAlarm,
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityCheckIds.alarms,
};

/// What a tap on a row opens.
enum ReliabilityRowTarget {
  /// Nothing. The row is a plain display.
  none,

  /// The permissions screen.
  permissions,

  /// The phone maker's steps.
  makerGuide,
}

/// What a tap on the row for [id] opens, whatever its state. A fine row
/// that opens something shows an arrow after its tick, so the way back to
/// the steps or the permissions is not hidden.
ReliabilityRowTarget reliabilityRowTarget(ReliabilityCheckId id) {
  if (isPermissionCheck(id)) return ReliabilityRowTarget.permissions;
  if (id == ReliabilityCheckIds.phoneMaker) {
    return ReliabilityRowTarget.makerGuide;
  }
  return ReliabilityRowTarget.none;
}

/// The face on a row. It comes from the check and how it stands, never from
/// where the row sits, so a row keeps its face when the order changes.
///
/// A fine row is calm: `calm` or `content` and nothing else. A row that is
/// not fine gets the face of its moment. No row uses a face the header
/// uses, or one that draws its outline in a colour (`worried`, `alarmed`,
/// `acked`), so a column of rows has one outline.
///
/// A check from a source this file does not know gets a face by state.
FaceState reliabilityRowFace(ReliabilityCheck check) {
  final id = check.id.value;
  switch (check.state) {
    case ReliabilityState.fine:
    case ReliabilityState.notOnThisPhone:
      return _fineFaces[id] ?? FaceState.calm;
    case ReliabilityState.needsLook:
    case ReliabilityState.broken:
      break;
  }
  final reason = check.reason;
  if (id == ReliabilityCheckIds.missedAlarm.value) {
    // The same face Home's notice shows for that reason.
    for (final missed in MissedReason.values) {
      if (reason == 'missed_${missed.code}' &&
          missed != MissedReason.rangUnanswered) {
        return missedAlarmFace(missed);
      }
    }
  }
  if (reason == 'notDetermined') {
    final notAsked = _notAskedFaces[id];
    if (notAsked != null) return notAsked;
  }
  if (reason == 'clock') return FaceState.confused;
  return check.state == ReliabilityState.broken
      ? _brokenFaces[id] ?? FaceState.concerned
      : _lookFaces[id] ?? FaceState.thinking;
}

/// Calm faces only. The two alternate down the list a phone usually shows.
const _fineFaces = <String, FaceState>{
  'notifications': FaceState.calm,
  'full_screen_alarm': FaceState.content,
  'battery_optimization': FaceState.calm,
  'alarms': FaceState.content,
  'push_token_confirmed': FaceState.content,
  'last_push_received': FaceState.calm,
  'time_sensitive': FaceState.calm,
  'system_update': FaceState.content,
  'phone_maker': FaceState.calm,
  'missed_alarm': FaceState.content,
};

/// Known not to work.
const _brokenFaces = <String, FaceState>{
  // Turned off: a plain no.
  'notifications': FaceState.shakeHead,
  'full_screen_alarm': FaceState.confused,
  'alarms': FaceState.confused,
  'time_sensitive': FaceState.concerned,
  // The relay turned the phone down. Not `shocked`: its tongue is the one
  // spot of red a row would have, and red is for a ringing alarm.
  'push_token_confirmed': FaceState.dizzy,
};

/// Might not ring.
const _lookFaces = <String, FaceState>{
  // The phone may put the app to sleep.
  'battery_optimization': FaceState.sleepy,
  'phone_maker': FaceState.yawn,
  // Alerts may be held back.
  'time_sensitive': FaceState.thinking,
  // Waiting to hear from the relay, or for a push.
  'push_token_confirmed': FaceState.lookLeft,
  'last_push_received': FaceState.lookRight,
  // The phone changed under the app.
  'system_update': FaceState.realization,
};

/// Never asked: nothing is wrong yet, the question is still open.
const _notAskedFaces = <String, FaceState>{
  'notifications': FaceState.curious,
  'alarms': FaceState.interested,
};

/// What the top of the screen shows.
enum ReliabilityHeadline { loading, fine, needsLook, broken }

/// The headline for what the cubit holds. Until the first read ends it is
/// [ReliabilityHeadline.loading], never "fine".
ReliabilityHeadline reliabilityHeadline(ReliabilitySnapshot snapshot) {
  if (!snapshot.loaded) return ReliabilityHeadline.loading;
  return switch (snapshot.overall) {
    ReliabilityState.broken => ReliabilityHeadline.broken,
    ReliabilityState.needsLook => ReliabilityHeadline.needsLook,
    ReliabilityState.fine ||
    ReliabilityState.notOnThisPhone => ReliabilityHeadline.fine,
  };
}

/// The header's face and words.
@immutable
final class ReliabilityHeadlineView {
  const ReliabilityHeadlineView({
    required this.face,
    required this.wordKey,
    required this.lineKey,
  });

  final FaceState face;
  final String wordKey;
  final String lineKey;

  @override
  bool operator ==(Object other) =>
      other is ReliabilityHeadlineView &&
      other.face == face &&
      other.wordKey == wordKey &&
      other.lineKey == lineKey;

  @override
  int get hashCode => Object.hash(face, wordKey, lineKey);
}

/// The face and words for [headline]. Loading has one line and no word.
ReliabilityHeadlineView reliabilityHeadlineView(
  ReliabilityHeadline headline,
) => switch (headline) {
  ReliabilityHeadline.loading => const ReliabilityHeadlineView(
    face: FaceState.watching,
    wordKey: LocaleKeys.reliability_loading,
    lineKey: LocaleKeys.reliability_loading,
  ),
  ReliabilityHeadline.fine => const ReliabilityHeadlineView(
    face: FaceState.happy,
    wordKey: LocaleKeys.reliability_overall_fine_word,
    lineKey: LocaleKeys.reliability_overall_fine_line,
  ),
  ReliabilityHeadline.needsLook => const ReliabilityHeadlineView(
    face: FaceState.skeptical,
    wordKey: LocaleKeys.reliability_overall_look_word,
    lineKey: LocaleKeys.reliability_overall_look_line,
  ),
  ReliabilityHeadline.broken => const ReliabilityHeadlineView(
    face: FaceState.sad,
    wordKey: LocaleKeys.reliability_overall_broken_word,
    lineKey: LocaleKeys.reliability_overall_broken_line,
  ),
};

/// How many checks are not fine, for the count on the Settings row.
int reliabilityIssueCount(Iterable<ReliabilityCheck> checks) => checks
    .where(
      (check) =>
          check.state == ReliabilityState.needsLook ||
          check.state == ReliabilityState.broken,
    )
    .length;
