import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/overall_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:flutter_test/flutter_test.dart';

const _route = 'testRing';

WeeklyCheck _on(WeeklyCheckState? state, {int misses = 0}) => WeeklyCheck(
  enabled: true,
  state: state,
  misses: misses,
  lastSentAt: 100,
);

const _neverOn = WeeklyCheck(
  enabled: false,
  state: WeeklyCheckState.off,
  reason: WeeklyCheckOffReason.disabled,
);
const _off = WeeklyCheck(
  enabled: false,
  state: WeeklyCheckState.off,
  reason: WeeklyCheckOffReason.disabled,
  lastSentAt: 100,
);

/// What the relay answers for an enrolled device while the account is not
/// on Hosted (api.md §4.5, "When the tier changes").
const _tierAway = WeeklyCheck(
  enabled: true,
  state: WeeklyCheckState.off,
  reason: WeeklyCheckOffReason.tier,
  lastSentAt: 100,
);

/// The same answer as a relay before 1.19.0 worded it. `pack` is a reason
/// this build does not know, so it reads as none.
final _packFrom118 = WeeklyCheck.fromJson(const {
  'enabled': true,
  'state': 'off',
  'reason': 'pack',
  'last_sent_at': 100,
});

const _everyCheck = <WeeklyCheck?>[null, _neverOn, _off, _tierAway];

WeeklyCheckStanding _standing(
  WeeklyCheck? check, {
  WeeklyCheckAccess access = WeeklyCheckAccess.open,
  bool missedByClock = false,
}) => weeklyCheckStanding(
  check: check,
  access: access,
  missedByClock: missedByClock,
);

Future<ReliabilityCheck> _read(
  WeeklyCheck? check, {
  WeeklyCheckAccess access = WeeklyCheckAccess.open,
  bool missedByClock = false,
}) async => (await WeeklyCheckSource(
  readCheck: () => check,
  readAccess: () => access,
  readMissedByClock: () async => missedByClock,
  testRouteName: _route,
).read()).single;

void main() {
  group('how the check stands', () {
    test('without Hosted it is locked, whatever the relay said', () {
      for (final check in [
        ..._everyCheck,
        _on(WeeklyCheckState.received),
        _on(WeeklyCheckState.missedRepeatedly, misses: 3),
        _on(WeeklyCheckState.tokenRefused),
      ]) {
        for (final access in [
          WeeklyCheckAccess.locked,
          // A purchase being confirmed, or a plan that could not be read:
          // the relay would refuse the check, so the row stays locked.
          WeeklyCheckAccess.unsure,
        ]) {
          expect(
            _standing(check, access: access, missedByClock: true),
            WeeklyCheckStanding.locked,
            reason: '$check, ${access.name}',
          );
        }
      }
    });

    test('on a server of the user own it is not offered, whatever the '
        'relay said', () {
      for (final check in [
        ..._everyCheck,
        _on(WeeklyCheckState.received),
        _on(WeeklyCheckState.missedRepeatedly, misses: 3),
      ]) {
        expect(
          _standing(
            check,
            access: WeeklyCheckAccess.notOffered,
            missedByClock: true,
          ),
          WeeklyCheckStanding.notOffered,
        );
      }
      expect(WeeklyCheckStanding.notOffered.isOn, isFalse);
      expect(WeeklyCheckStanding.notOffered.needsLook, isFalse);
    });

    test('before the relay has answered it was never on', () {
      expect(_standing(null), WeeklyCheckStanding.neverOn);
      // Loading is not trouble, even with a stale clock answer.
      expect(_standing(null, missedByClock: true), WeeklyCheckStanding.neverOn);
    });

    test('off is never on until a round was sent, then off', () {
      expect(_standing(_neverOn), WeeklyCheckStanding.neverOn);
      expect(_standing(_off), WeeklyCheckStanding.off);
      expect(_standing(_off, missedByClock: true), WeeklyCheckStanding.off);
    });

    test('a lapse: what is held locks the row, and the switch the person '
        'chose is kept for the return', () {
      // Hosted is gone: locked, with the relay still holding the device as
      // enrolled.
      expect(
        _standing(_tierAway, access: WeeklyCheckAccess.locked),
        WeeklyCheckStanding.locked,
      );
      expect(_tierAway.enabled, isTrue);

      // Hosted is back and the relay's answer is still the one from the
      // lapse: the row is on, as the person left it, with no new tap. It
      // is not locked, and not trouble.
      final back = _standing(_tierAway, missedByClock: true);
      expect(back, WeeklyCheckStanding.on);
      expect(back.isOn, isTrue);
      expect(back.needsLook, isFalse);

      // The relay's next answer says how the rounds stand.
      expect(
        _standing(_on(WeeklyCheckState.received)),
        WeeklyCheckStanding.received,
      );
    });

    test('a reason this build does not know is no reason: `pack` from a '
        'relay before 1.19.0 is plain off', () {
      expect(_packFrom118.reason, isNull);
      expect(_packFrom118.state, WeeklyCheckState.off);
      // Off with a round sent before: "off", and never "on".
      expect(_standing(_packFrom118), WeeklyCheckStanding.off);
      expect(_standing(_packFrom118).isOn, isFalse);
    });

    test('each state the relay reports', () {
      expect(
        _standing(_on(WeeklyCheckState.waiting)),
        WeeklyCheckStanding.waiting,
      );
      expect(
        _standing(_on(WeeklyCheckState.received)),
        WeeklyCheckStanding.received,
      );
      expect(
        _standing(_on(WeeklyCheckState.missedOnce, misses: 1)),
        WeeklyCheckStanding.missedOnce,
      );
      expect(
        _standing(_on(WeeklyCheckState.missedRepeatedly, misses: 2)),
        WeeklyCheckStanding.missedRepeatedly,
      );
      expect(
        _standing(_on(WeeklyCheckState.tokenRefused, misses: 1)),
        WeeklyCheckStanding.tokenRefused,
      );
      expect(
        _standing(_on(WeeklyCheckState.noToken)),
        WeeklyCheckStanding.noToken,
      );
      expect(_standing(_on(null)), WeeklyCheckStanding.on);
    });

    test('the phone telling by its own clock is missed repeatedly', () {
      for (final state in [
        WeeklyCheckState.waiting,
        WeeklyCheckState.received,
        WeeklyCheckState.missedOnce,
        null,
      ]) {
        expect(
          _standing(_on(state), missedByClock: true),
          WeeklyCheckStanding.missedRepeatedly,
          reason: '$state',
        );
      }
      // A token problem keeps its own name and its own fix.
      expect(
        _standing(_on(WeeklyCheckState.tokenRefused), missedByClock: true),
        WeeklyCheckStanding.tokenRefused,
      );
      expect(
        _standing(_on(WeeklyCheckState.noToken), missedByClock: true),
        WeeklyCheckStanding.noToken,
      );
    });

    test('only three standings need a look, and one miss is not one', () {
      expect(
        {
          for (final standing in WeeklyCheckStanding.values)
            if (standing.needsLook) standing,
        },
        {
          WeeklyCheckStanding.missedRepeatedly,
          WeeklyCheckStanding.tokenRefused,
          WeeklyCheckStanding.noToken,
        },
      );
      expect(WeeklyCheckStanding.missedOnce.needsLook, isFalse);
    });
  });

  group('the check the Reliability screen counts', () {
    test('every standing has one, and none is ever broken', () {
      for (final standing in WeeklyCheckStanding.values) {
        final check = weeklyCheckReliability(standing, testRouteName: _route);
        expect(check.id, WeeklyCheckSource.id);
        expect(
          check.state,
          isNot(ReliabilityState.broken),
          reason: '$standing',
        );
        expect(
          check.state == ReliabilityState.needsLook,
          standing.needsLook,
          reason: '$standing',
        );
      }
    });

    test('not offered, locked, never on and off are not on this phone', () {
      for (final standing in [
        WeeklyCheckStanding.notOffered,
        WeeklyCheckStanding.locked,
        WeeklyCheckStanding.neverOn,
        WeeklyCheckStanding.off,
      ]) {
        final check = weeklyCheckReliability(standing, testRouteName: _route);
        expect(check.state, ReliabilityState.notOnThisPhone);
        expect(check.fix, isNull);
      }
    });

    test('waiting, received, one miss and an unknown state are fine', () {
      for (final standing in [
        WeeklyCheckStanding.waiting,
        WeeklyCheckStanding.received,
        WeeklyCheckStanding.missedOnce,
        WeeklyCheckStanding.on,
      ]) {
        final check = weeklyCheckReliability(standing, testRouteName: _route);
        expect(check.state, ReliabilityState.fine, reason: '$standing');
        expect(check.fix, isNull);
        expect(check.reason, isNull);
      }
    });

    test('missed repeatedly offers a test alarm', () {
      final check = weeklyCheckReliability(
        WeeklyCheckStanding.missedRepeatedly,
        testRouteName: _route,
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, WeeklyCheckSource.reasonMissed);
      expect(check.fix, const OpenRouteFix(_route));
      expect(
        reliabilityFixLabelKey(check.fix!, testRouteName: _route),
        'reliability.fix_ring_test',
      );
    });

    test('token refused and no token offer to register again', () {
      for (final (standing, reason) in [
        (
          WeeklyCheckStanding.tokenRefused,
          WeeklyCheckSource.reasonTokenRefused,
        ),
        (WeeklyCheckStanding.noToken, WeeklyCheckSource.reasonNoToken),
      ]) {
        final check = weeklyCheckReliability(standing, testRouteName: _route);
        expect(check.state, ReliabilityState.needsLook);
        expect(check.reason, reason);
        expect(
          check.fix,
          const RunFix(ReliabilityFixAction.reRegisterPushToken),
        );
        expect(
          reliabilityFixLabelKey(check.fix!, testRouteName: _route),
          'reliability.fix_try_again',
        );
      }
    });
  });

  group('the source', () {
    test('reads what the phone holds for every row state', () async {
      expect(
        (await _read(null)).state,
        ReliabilityState.notOnThisPhone,
      );
      expect((await _read(_neverOn)).state, ReliabilityState.notOnThisPhone);
      expect((await _read(_off)).state, ReliabilityState.notOnThisPhone);
      expect(
        (await _read(_tierAway, access: WeeklyCheckAccess.locked)).state,
        ReliabilityState.notOnThisPhone,
      );
      expect(
        (await _read(
          _on(WeeklyCheckState.missedRepeatedly, misses: 2),
          access: WeeklyCheckAccess.notOffered,
          missedByClock: true,
        )).state,
        ReliabilityState.notOnThisPhone,
      );
      expect(
        (await _read(_packFrom118)).state,
        ReliabilityState.notOnThisPhone,
      );
      expect(
        (await _read(
          _on(WeeklyCheckState.received),
          access: WeeklyCheckAccess.locked,
        )).state,
        ReliabilityState.notOnThisPhone,
      );
      expect(
        (await _read(_on(WeeklyCheckState.waiting))).state,
        ReliabilityState.fine,
      );
      expect(
        (await _read(_on(WeeklyCheckState.received))).state,
        ReliabilityState.fine,
      );
      expect(
        (await _read(_on(WeeklyCheckState.missedOnce, misses: 1))).state,
        ReliabilityState.fine,
      );
      expect(
        (await _read(_on(WeeklyCheckState.missedRepeatedly, misses: 2))).state,
        ReliabilityState.needsLook,
      );
      expect(
        (await _read(_on(WeeklyCheckState.tokenRefused))).state,
        ReliabilityState.needsLook,
      );
      expect(
        (await _read(_on(WeeklyCheckState.noToken))).state,
        ReliabilityState.needsLook,
      );
    });

    test(
      'the clock passing notice_after counts like the relay saying so',
      () async {
        final check = await _read(
          _on(WeeklyCheckState.received),
          missedByClock: true,
        );
        expect(check.state, ReliabilityState.needsLook);
        expect(check.reason, WeeklyCheckSource.reasonMissed);
      },
    );

    test('the clock is not asked when it cannot matter', () async {
      var asked = 0;
      Future<bool> clock() async {
        asked++;
        return true;
      }

      for (final (check, held) in [
        (null, true),
        (_on(WeeklyCheckState.missedRepeatedly), false),
      ]) {
        await WeeklyCheckSource(
          readCheck: () => check,
          readAccess: () =>
              held ? WeeklyCheckAccess.open : WeeklyCheckAccess.locked,
          readMissedByClock: clock,
          testRouteName: _route,
        ).read();
      }
      expect(asked, 0);
    });

    test('a clock read that throws is no', () async {
      final check = (await WeeklyCheckSource(
        readCheck: () => _on(WeeklyCheckState.received),
        readAccess: () => WeeklyCheckAccess.open,
        readMissedByClock: () async => throw StateError('disk'),
        testRouteName: _route,
      ).read()).single;
      expect(check.state, ReliabilityState.fine);
    });
  });

  group('the overall state and the Settings count', () {
    const fine = ReliabilityCheck(
      id: ReliabilityCheckIds.notifications,
      state: ReliabilityState.fine,
    );

    Future<List<ReliabilityCheck>> withWeekly(
      WeeklyCheck? check, {
      WeeklyCheckAccess access = WeeklyCheckAccess.open,
    }) async => [
      fine,
      // What `ReliabilityCubit` does with a check not on this phone.
      for (final weekly in [await _read(check, access: access)])
        if (weekly.state != ReliabilityState.notOnThisPhone) weekly,
    ];

    test(
      'trouble while switched on is "Take a look", and counts once',
      () async {
        for (final state in [
          WeeklyCheckState.missedRepeatedly,
          WeeklyCheckState.tokenRefused,
          WeeklyCheckState.noToken,
        ]) {
          final checks = await withWeekly(_on(state, misses: 2));
          expect(overallReliabilityState(checks), ReliabilityState.needsLook);
          expect(reliabilityIssueCount(checks), 1);
        }
      },
    );

    test('one miss, a locked row and a row that is off never count', () async {
      for (final checks in [
        await withWeekly(_on(WeeklyCheckState.missedOnce, misses: 1)),
        await withWeekly(_on(WeeklyCheckState.received)),
        await withWeekly(_on(WeeklyCheckState.waiting)),
        await withWeekly(null),
        await withWeekly(_neverOn),
        await withWeekly(_off),
        await withWeekly(_tierAway),
        await withWeekly(_tierAway, access: WeeklyCheckAccess.locked),
        await withWeekly(_packFrom118),
        await withWeekly(
          _on(WeeklyCheckState.missedRepeatedly, misses: 2),
          access: WeeklyCheckAccess.notOffered,
        ),
        await withWeekly(
          _on(WeeklyCheckState.missedRepeatedly, misses: 2),
          access: WeeklyCheckAccess.locked,
        ),
      ]) {
        expect(overallReliabilityState(checks), ReliabilityState.fine);
        expect(reliabilityIssueCount(checks), 0);
      }
    });
  });
}
