import 'package:critalarm/core/models/weekly_check.dart';

/// How the weekly check stands on this phone, decided once.
///
/// The row on the Reliability screen draws from it, and so does the check
/// the weekly check hands to that screen's overall state. Both read this
/// one answer, so the header can never say one thing above a row that says
/// another.
enum WeeklyCheckStanding {
  /// The install does not hold the pack, or the relay says the account
  /// lost it. The row is locked.
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

  /// On, in a state a newer relay sends and this build has no words for.
  on;

  /// Whether this standing is trouble the user can act on. One miss is not:
  /// iOS may hold back a single background push (api.md §4.5).
  bool get needsLook =>
      this == missedRepeatedly || this == tokenRefused || this == noToken;

  /// Whether the check is switched on and the pack is held.
  bool get isOn => switch (this) {
    locked || neverOn || off => false,
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
  required bool isPackHeld,
  required bool missedByClock,
}) {
  if (!isPackHeld) return WeeklyCheckStanding.locked;
  if (check == null) return WeeklyCheckStanding.neverOn;
  final state = check.state;
  if (state == WeeklyCheckState.off || !check.enabled) {
    // The relay says the pack is gone. The row locks at once, before the
    // packs list has been read again.
    if (check.reason == WeeklyCheckOffReason.pack) {
      return WeeklyCheckStanding.locked;
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
