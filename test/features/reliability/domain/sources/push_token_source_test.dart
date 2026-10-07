import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/sources/push_token_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 7, 12);

ReliabilityCheck _rule({
  Duration? ago,
  RelayAttemptOutcome? outcome = RelayAttemptOutcome.accepted,
}) => PushTokenSource.pushTokenCheckFor(
  now: _now,
  confirmedAt: ago == null ? null : _now.subtract(ago),
  lastOutcome: outcome,
);

void main() {
  group('state rule', () {
    test('accepted a minute ago is fine', () {
      final check = _rule(ago: const Duration(minutes: 1));
      expect(check.state, ReliabilityState.fine);
      expect(check.reason, isNull);
      expect(check.fix, isNull);
      expect(check.lastKnownGood, _now.subtract(const Duration(minutes: 1)));
    });

    test('exactly 48 hours ago is still fine', () {
      expect(
        _rule(ago: const Duration(hours: 48)).state,
        ReliabilityState.fine,
      );
    });

    test('one second past 48 hours needs a look', () {
      final check = _rule(ago: const Duration(hours: 48, seconds: 1));
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'stale');
      expect(check.fix, const RunFix(ReliabilityFixAction.reRegisterPushToken));
    });

    test('never accepted needs a look', () {
      final check = _rule(outcome: null);
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'never');
      expect(check.lastKnownGood, isNull);
    });

    test('a last attempt that was refused is broken, even if recent', () {
      final check = _rule(
        ago: const Duration(hours: 1),
        outcome: RelayAttemptOutcome.refused,
      );
      expect(check.state, ReliabilityState.broken);
      expect(check.reason, 'refused');
      expect(check.fix, const RunFix(ReliabilityFixAction.reRegisterPushToken));
    });

    test('a refusal with nothing ever accepted is broken', () {
      expect(
        _rule(outcome: RelayAttemptOutcome.refused).state,
        ReliabilityState.broken,
      );
    });

    test('an attempt that failed on the network is judged by age alone', () {
      expect(
        _rule(
          ago: const Duration(hours: 5),
          outcome: RelayAttemptOutcome.failed,
        ).state,
        ReliabilityState.fine,
      );
      expect(
        _rule(
          ago: const Duration(hours: 60),
          outcome: RelayAttemptOutcome.failed,
        ).state,
        ReliabilityState.needsLook,
      );
    });
  });

  group('source', () {
    late RelayConfirmationStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = RelayConfirmationStore(await SharedPreferences.getInstance());
    });

    PushTokenSource build({required bool expected}) => PushTokenSource(
      store: store,
      isRelayExpected: () async => expected,
      now: () => _now,
    );

    test('reads the store the registry writes', () async {
      await store.record(
        _now.subtract(const Duration(hours: 2)),
        RelayAttemptOutcome.accepted,
      );
      final checks = await build(expected: true).read();
      expect(checks.single.id, ReliabilityCheckIds.pushTokenConfirmed);
      expect(checks.single.state, ReliabilityState.fine);
    });

    test('a refusal after an acceptance is broken', () async {
      await store.record(
        _now.subtract(const Duration(hours: 30)),
        RelayAttemptOutcome.accepted,
      );
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.refused,
      );
      final check = (await build(expected: true).read()).single;
      expect(check.state, ReliabilityState.broken);
      expect(
        check.lastKnownGood,
        _now.subtract(const Duration(hours: 30)),
        reason: 'the refusal does not move the last good time',
      );
    });

    test(
      'no relay to talk to (mock build, no server) is not on this phone',
      () async {
        final check = (await build(expected: false).read()).single;
        expect(check.state, ReliabilityState.notOnThisPhone);
        expect(check.state, isNot(ReliabilityState.broken));
      },
    );
  });
}
