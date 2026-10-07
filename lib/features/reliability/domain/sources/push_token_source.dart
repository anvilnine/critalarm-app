import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// Whether the relay holds this phone's push token.
///
/// `DeviceTokenRegistry` sends the token at most once a day and keeps what
/// came back in a [RelayConfirmationStore]. This reads it.
///
/// - Broken: the last attempt was refused (the relay answered with a 4xx).
/// - Needs a look: the relay has not accepted the token for more than
///   [fineFor], or never has. A token that could not be sent because the
///   network was down is judged by the same age.
/// - Fine: accepted within [fineFor].
///
/// The check is not on this phone when [isRelayExpected] says so: no server is
/// connected, the build has no push (web), or it runs against the mock server,
/// where registration is skipped. A mock build therefore reports "not on this
/// phone", never broken.
///
/// Reasons: `refused`, `never`, `stale`. The fix is a re-register for all
/// three. Self-hosted servers register the same way (see the registry).
final class PushTokenSource implements ReliabilityCheckSource {
  PushTokenSource({
    required this.store,
    required this.isRelayExpected,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Accepted this recently counts as fine.
  static const fineFor = Duration(hours: 48);

  final RelayConfirmationStore store;
  final Future<bool> Function() isRelayExpected;
  final DateTime Function() _now;

  @override
  Future<List<ReliabilityCheck>> read() async {
    if (!await isRelayExpected()) {
      return [
        const ReliabilityCheck.notOnThisPhone(
          ReliabilityCheckIds.pushTokenConfirmed,
        ),
      ];
    }
    return [
      pushTokenCheckFor(
        now: _now(),
        confirmedAt: store.confirmedAt,
        lastOutcome: store.lastOutcome,
      ),
    ];
  }

  /// The state rule. Pure, so a test picks the clock.
  static ReliabilityCheck pushTokenCheckFor({
    required DateTime now,
    required DateTime? confirmedAt,
    required RelayAttemptOutcome? lastOutcome,
  }) {
    const id = ReliabilityCheckIds.pushTokenConfirmed;
    const fix = RunFix(ReliabilityFixAction.reRegisterPushToken);
    if (lastOutcome == RelayAttemptOutcome.refused) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.broken,
        lastKnownGood: confirmedAt,
        reason: 'refused',
        fix: fix,
      );
    }
    if (confirmedAt == null) {
      return const ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        reason: 'never',
        fix: fix,
      );
    }
    if (now.difference(confirmedAt) > fineFor) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        lastKnownGood: confirmedAt,
        reason: 'stale',
        fix: fix,
      );
    }
    return ReliabilityCheck(
      id: id,
      state: ReliabilityState.fine,
      lastKnownGood: confirmedAt,
    );
  }
}
