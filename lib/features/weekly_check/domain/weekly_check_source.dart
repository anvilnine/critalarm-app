import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';

/// The weekly check as one check on the Reliability screen, so the screen's
/// overall state and the Settings row count it like any other.
///
/// It counts only while the check is switched on and Hosted is held, and
/// then as "needs a look" at most, never broken: missed repeatedly, a
/// refused token, or no token. One miss does not count. A locked row, one
/// that is not offered on this server, one never switched on and one
/// switched off are not on this phone as far as the screen's state goes.
///
/// It reads what the phone already holds: the relay's last answer as
/// `WeeklyCheckMonitor` kept it, and the native record. It never calls the
/// relay. The row's own cubit does that when the screen opens.
final class WeeklyCheckSource implements ReliabilityCheckSource {
  WeeklyCheckSource({
    required this._readCheck,
    required this._readAccess,
    required this._readMissedByClock,
    required this._testRouteName,
  });

  static const id = ReliabilityCheckId('weekly_check');

  /// The reason codes, for the screen to pick words with.
  static const reasonMissed = 'weekly_missed';
  static const reasonTokenRefused = 'weekly_token_refused';
  static const reasonNoToken = 'weekly_no_token';

  final WeeklyCheck? Function() _readCheck;
  final WeeklyCheckAccess Function() _readAccess;
  final Future<bool> Function() _readMissedByClock;

  /// The `AppRoute` name of the test alarm screen.
  final String _testRouteName;

  @override
  Future<List<ReliabilityCheck>> read() async {
    final check = _readCheck();
    final access = _readAccess();
    // Only asked when it can matter, and a read that fails is "no".
    var missedByClock = false;
    if (access == WeeklyCheckAccess.open && check != null) {
      try {
        missedByClock = await _readMissedByClock();
      } on Object {
        missedByClock = false;
      }
    }
    return [
      weeklyCheckReliability(
        weeklyCheckStanding(
          check: check,
          access: access,
          missedByClock: missedByClock,
        ),
        testRouteName: _testRouteName,
      ),
    ];
  }
}

/// The check the Reliability screen counts for [standing], with the one
/// thing to do about it.
///
/// - Missed repeatedly: ring a test, the one way to see whether a push
///   still gets through.
/// - Token refused and no token: send the push token to the relay again.
ReliabilityCheck weeklyCheckReliability(
  WeeklyCheckStanding standing, {
  required String testRouteName,
}) => switch (standing) {
  WeeklyCheckStanding.notOffered ||
  WeeklyCheckStanding.locked ||
  WeeklyCheckStanding.neverOn ||
  WeeklyCheckStanding.off => const ReliabilityCheck.notOnThisPhone(
    WeeklyCheckSource.id,
  ),
  WeeklyCheckStanding.waiting ||
  WeeklyCheckStanding.received ||
  WeeklyCheckStanding.missedOnce ||
  WeeklyCheckStanding.on => const ReliabilityCheck(
    id: WeeklyCheckSource.id,
    state: ReliabilityState.fine,
  ),
  WeeklyCheckStanding.missedRepeatedly => ReliabilityCheck(
    id: WeeklyCheckSource.id,
    state: ReliabilityState.needsLook,
    reason: WeeklyCheckSource.reasonMissed,
    fix: OpenRouteFix(testRouteName),
  ),
  WeeklyCheckStanding.tokenRefused => const ReliabilityCheck(
    id: WeeklyCheckSource.id,
    state: ReliabilityState.needsLook,
    reason: WeeklyCheckSource.reasonTokenRefused,
    fix: RunFix(ReliabilityFixAction.reRegisterPushToken),
  ),
  WeeklyCheckStanding.noToken => const ReliabilityCheck(
    id: WeeklyCheckSource.id,
    state: ReliabilityState.needsLook,
    reason: WeeklyCheckSource.reasonNoToken,
    fix: RunFix(ReliabilityFixAction.reRegisterPushToken),
  ),
};
