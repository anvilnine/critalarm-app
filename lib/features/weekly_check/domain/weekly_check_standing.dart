import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';

/// How the weekly check stands on this phone, decided once.
///
/// The row on the Reliability screen draws from it, and so does the check
/// the weekly check hands to that screen's overall state. Both read this
/// one answer, so the header can never say one thing above a row that says
/// another.
enum WeeklyCheckStanding {
  /// The phone is on a server of the user's own, where the check does not
  /// exist. The row says so and offers nothing.
  notOffered,

  /// The install does not hold Hosted, or that is not sure yet. The row is
  /// locked and offers Hosted. What the person chose on the switch is kept
  /// by the relay and shows again when Hosted is back.
  locked,

  /// Held, and never switched on. The relay has sent no round.
  neverOn,

  /// Switched off after having been on.
  off,

  /// On, and no round has closed yet.
  waiting,

  /// On, and the last round was received.
  received,

  /// On, and one round was missed. A prompt to look, and nothing more.
  missedOnce,

  /// On, and two rounds in a row were missed: the relay says so, or this
  /// phone's own clock passed the moment the relay named.
  missedRepeatedly,

  /// On, and the relay's push provider refused this phone's token.
  tokenRefused,

  /// On, and the relay holds no push token for this phone.
  noToken,

  /// On, with no words for how the rounds went: a state a newer relay
  /// sends, or the relay still answering that the account is not on Hosted
  /// while this phone holds it, which lasts until the next read.
  on;

  /// Whether this standing is trouble the user can act on. One miss is not:
  /// iOS may hold back a single background push (api.md §4.5).
  bool get needsLook =>
      this == missedRepeatedly || this == tokenRefused || this == noToken;

  /// Whether the check is switched on and Hosted is held.
  bool get isOn => switch (this) {
    notOffered || locked || neverOn || off => false,
    waiting ||
    received ||
    missedOnce ||
    missedRepeatedly ||
    tokenRefused ||
    noToken ||
    on => true,
  };
}

/// The standing for what the phone holds.
///
/// [check] is the relay's last answer, null until it has answered on this
/// phone: that is "never on", not trouble, so a screen that is still
/// loading never reads as a problem. [missedByClock] is the phone telling
/// by itself that two rounds were missed (`WeeklyCheckNoticeRule`), which
/// is what raises the notice on Home when the relay cannot be reached.
WeeklyCheckStanding weeklyCheckStanding({
  required WeeklyCheck? check,
  required WeeklyCheckAccess access,
  required bool missedByClock,
}) {
  switch (access) {
    case WeeklyCheckAccess.notOffered:
      return WeeklyCheckStanding.notOffered;
    case WeeklyCheckAccess.locked || WeeklyCheckAccess.unsure:
      return WeeklyCheckStanding.locked;
    case WeeklyCheckAccess.open:
      break;
  }
  if (check == null) return WeeklyCheckStanding.neverOn;
  final state = check.state;
  if (state == WeeklyCheckState.off || !check.enabled) {
    // Still enrolled, and the relay says the account is not on Hosted,
    // while this phone holds Hosted: the relay's answer is the older one.
    // The switch stays where the person left it (api.md §4.5, "When the
    // tier changes"). What is held decides the lock, never this answer.
    if (check.enabled && check.reason == WeeklyCheckOffReason.tier) {
      return WeeklyCheckStanding.on;
    }
    return check.lastSentAt == null
        ? WeeklyCheckStanding.neverOn
        : WeeklyCheckStanding.off;
  }
  return switch (state) {
    WeeklyCheckState.tokenRefused => WeeklyCheckStanding.tokenRefused,
    WeeklyCheckState.noToken => WeeklyCheckStanding.noToken,
    WeeklyCheckState.missedRepeatedly => WeeklyCheckStanding.missedRepeatedly,
    _ when missedByClock => WeeklyCheckStanding.missedRepeatedly,
    WeeklyCheckState.missedOnce => WeeklyCheckStanding.missedOnce,
    WeeklyCheckState.received => WeeklyCheckStanding.received,
    WeeklyCheckState.waiting => WeeklyCheckStanding.waiting,
    WeeklyCheckState.off || null => WeeklyCheckStanding.on,
  };
}
