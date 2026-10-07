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

  group('a time in the future', () {
    test('an acceptance dated after now needs a look, not fine', () {
      final check = PushTokenSource.pushTokenCheckFor(
        now: _now,
        confirmedAt: _now.add(const Duration(days: 3)),
        lastOutcome: RelayAttemptOutcome.accepted,
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'clock');
      expect(check.lastKnownGood, isNull);
    });

    test('an acceptance dated exactly now is fine', () {
      final check = PushTokenSource.pushTokenCheckFor(
        now: _now,
        confirmedAt: _now,
        lastOutcome: RelayAttemptOutcome.accepted,
      );
      expect(check.state, ReliabilityState.fine);
    });

    test('a refusal still wins over a future acceptance', () {
      final check = PushTokenSource.pushTokenCheckFor(
        now: _now,
        confirmedAt: _now.add(const Duration(days: 3)),
        lastOutcome: RelayAttemptOutcome.refused,
      );
      expect(check.state, ReliabilityState.broken);
    });
  });

  group('source', () {
    late RelayConfirmationStore store;
    const here = RelayConfirmationScope(
      deviceId: 'dev_a',
      relay: 'https://relay-a.example',
      tokenHash: 'h1',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = RelayConfirmationStore(await SharedPreferences.getInstance());
    });

    PushTokenSource build({
      required bool expected,
      RelayConfirmationScope? scope = here,
    }) => PushTokenSource(
      store: store,
      isRelayExpected: () async => expected,
      currentScope: () async => scope,
      now: () => _now,
    );

    test('reads the store the registry writes', () async {
      await store.record(
        _now.subtract(const Duration(hours: 2)),
        RelayAttemptOutcome.accepted,
        here,
      );
      final checks = await build(expected: true).read();
      expect(checks.single.id, ReliabilityCheckIds.pushTokenConfirmed);
      expect(checks.single.state, ReliabilityState.fine);
    });

    test('a refusal after an acceptance is broken', () async {
      await store.record(
        _now.subtract(const Duration(hours: 30)),
        RelayAttemptOutcome.accepted,
        here,
      );
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.refused,
        here,
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

    test('an acceptance for another device id does not count', () async {
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.accepted,
        const RelayConfirmationScope(
          deviceId: 'dev_old',
          relay: 'https://relay-a.example',
          tokenHash: 'h1',
        ),
      );
      final check = (await build(expected: true).read()).single;
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'never');
    });

    test('an acceptance by another relay does not count', () async {
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.accepted,
        const RelayConfirmationScope(
          deviceId: 'dev_a',
          relay: 'https://relay-b.example',
          tokenHash: 'h1',
        ),
      );
      final check = (await build(expected: true).read()).single;
      expect(check.state, ReliabilityState.needsLook);
    });

    test('an acceptance of another token does not count', () async {
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.accepted,
        const RelayConfirmationScope(
          deviceId: 'dev_a',
          relay: 'https://relay-a.example',
          tokenHash: 'h0',
        ),
      );
      final check = (await build(expected: true).read()).single;
      expect(check.state, ReliabilityState.needsLook);
    });

    test(
      'a refusal of an old token does not make the new one broken',
      () async {
        await store.record(
          _now.subtract(const Duration(hours: 1)),
          RelayAttemptOutcome.refused,
          const RelayConfirmationScope(
            deviceId: 'dev_a',
            relay: 'https://relay-a.example',
            tokenHash: 'h0',
          ),
        );
        final check = (await build(expected: true).read()).single;
        expect(check.state, ReliabilityState.needsLook);
      },
    );

    test('no scope to name reads as never accepted', () async {
      await store.record(
        _now.subtract(const Duration(hours: 1)),
        RelayAttemptOutcome.accepted,
        here,
      );
      final check = (await build(expected: true, scope: null).read()).single;
      expect(check.state, ReliabilityState.needsLook);
    });
  });
}
