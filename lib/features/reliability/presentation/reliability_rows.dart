import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
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
  'missed_alarm': LocaleKeys.reliability_check_missed_alarm,
};

/// The one short line under a row's title, as a `LocaleKeys` key, picked from
/// the check's reason code. Null for a fine check, which stays quiet.
///
/// A reason this screen does not know still gets a line, by state, so a
/// source can ship a new code before the words exist.
String? reliabilityLineKey(ReliabilityCheck check) {
  if (check.state == ReliabilityState.fine ||
      check.state == ReliabilityState.notOnThisPhone) {
    return null;
  }
  return _lineKeys[check.reason] ??
      (check.state == ReliabilityState.broken
          ? LocaleKeys.reliability_line_broken_generic
          : LocaleKeys.reliability_line_look_generic);
}

const _lineKeys = <String, String>{
  'refused': LocaleKeys.reliability_line_refused,
  'never': LocaleKeys.reliability_line_never,
  'stale': LocaleKeys.reliability_line_stale,
  'silent': LocaleKeys.reliability_line_silent,
  'time_sensitive_off': LocaleKeys.reliability_line_time_sensitive_off,
  'scheduled_summary': LocaleKeys.reliability_line_scheduled_summary,
  'os_changed': LocaleKeys.reliability_line_os_changed,
  'missed_no_push': LocaleKeys.reliability_line_missed_no_push,
  'missed_push_no_ring': LocaleKeys.reliability_line_missed_push_no_ring,
  'missed_rang': LocaleKeys.reliability_line_missed_rang,
  'missed_unanswered': LocaleKeys.reliability_line_missed_unanswered,
  // A permission's reason is its status name.
  'denied': LocaleKeys.reliability_line_denied,
  'restricted': LocaleKeys.reliability_line_restricted,
  'notDetermined': LocaleKeys.reliability_line_not_determined,
};

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
  RunFix() => LocaleKeys.reliability_fix_try_again,
  OpenRouteFix(:final routeName) =>
    routeName == testRouteName
        ? LocaleKeys.reliability_fix_ring_test
        : LocaleKeys.reliability_fix_open,
};

/// Whether a row sits on the system permissions. Those rows also open the
/// permissions screen when tapped, so it stays reachable.
bool isPermissionCheck(ReliabilityCheckId id) => _permissionIds.contains(id);

const _permissionIds = <ReliabilityCheckId>{
  ReliabilityCheckIds.notifications,
  ReliabilityCheckIds.fullScreenAlarm,
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityCheckIds.alarms,
};

/// Each state has its own faces, and none of them is a face the header or
/// another state uses. A row takes the next one in its state's list, so two
/// rows in a row never match until the list wraps.
const _faces = <ReliabilityState, List<FaceState>>{
  ReliabilityState.broken: [
    FaceState.worried,
    FaceState.concerned,
    FaceState.dizzy,
  ],
  ReliabilityState.needsLook: [
    FaceState.thinking,
    FaceState.curious,
    FaceState.confused,
  ],
  ReliabilityState.fine: [
    FaceState.calm,
    FaceState.content,
    FaceState.proud,
  ],
};

/// The face for the [position]th row of [state] on the screen, counting from
/// zero.
FaceState reliabilityRowFace(ReliabilityState state, int position) {
  final faces = _faces[state] ?? _faces[ReliabilityState.fine]!;
  return faces[position % faces.length];
}

/// The faces for a whole ordered list, one per check.
List<FaceState> reliabilityRowFaces(List<ReliabilityCheck> ordered) {
  final seen = <ReliabilityState, int>{};
  return [
    for (final check in ordered)
      reliabilityRowFace(
        check.state,
        seen.update(check.state, (n) => n + 1, ifAbsent: () => 1) - 1,
      ),
  ];
}

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
