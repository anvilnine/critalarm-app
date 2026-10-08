import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_card_fixtures.dart';

void main() {
  group('pipsFor', () {
    test('gives one pip per check, in source order', () {
      final checks = [
        check(ReliabilityCheckIds.notifications),
        check(
          ReliabilityCheckIds.batteryOptimization,
          state: ReliabilityState.needsLook,
        ),
        check(ReliabilityCheckIds.alarms, state: ReliabilityState.broken),
        check(ReliabilityCheckIds.systemUpdate),
      ];
      expect(pipsFor(checks), [
        PipTone.fine,
        PipTone.look,
        PipTone.broken,
        PipTone.fine,
      ]);
    });

    test('is empty for no checks', () {
      expect(pipsFor(const []), isEmpty);
    });

    test('skips a check that has no meaning on this phone', () {
      final checks = [
        check(ReliabilityCheckIds.notifications),
        const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.alarms),
      ];
      expect(pipsFor(checks), [PipTone.fine]);
    });

    for (final n in [6, 7, 8, 9]) {
      test('gives $n pips for $n checks', () {
        expect(pipsFor(androidChecks(n)), hasLength(n));
      });
    }
  });

  group('readinessCount', () {
    test('counts passing checks out of the checks given, never a fixed 4', () {
      for (final n in [6, 7, 8, 9]) {
        final all = androidChecks(n);
        expect(
          readinessCount(all),
          ReadinessCount(fine: n, total: n, worst: ReliabilityState.fine),
        );
        expect(
          readinessCount(withCheckAt(all, 2, ReliabilityState.needsLook)),
          ReadinessCount(
            fine: n - 1,
            total: n,
            worst: ReliabilityState.needsLook,
          ),
        );
        expect(
          readinessCount(withCheckAt(all, 0, ReliabilityState.broken)),
          ReadinessCount(fine: n - 1, total: n, worst: ReliabilityState.broken),
        );
      }
    });

    test('broken is worse than needs a look wherever it sits', () {
      final checks = withCheckAt(
        withCheckAt(androidChecks(7), 1, ReliabilityState.needsLook),
        5,
        ReliabilityState.broken,
      );
      expect(readinessCount(checks).worst, ReliabilityState.broken);
    });

    test('an empty list is 0 of 0 and fine', () {
      expect(
        readinessCount(const []),
        const ReadinessCount(fine: 0, total: 0, worst: ReliabilityState.fine),
      );
    });

    test('does not count a check that is not on this phone', () {
      final checks = [
        check(ReliabilityCheckIds.notifications),
        const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.alarms),
      ];
      expect(readinessCount(checks).total, 1);
    });
  });

  group('worstCheck and checkToFix', () {
    test('worst is the first broken check, else the first needing a look', () {
      final checks = withCheckAt(
        withCheckAt(androidChecks(7), 1, ReliabilityState.needsLook),
        4,
        ReliabilityState.broken,
      );
      expect(worstCheck(checks)?.id, checks[4].id);
      expect(
        worstCheck(
          withCheckAt(androidChecks(7), 3, ReliabilityState.needsLook),
        )?.id,
        androidChecks(7)[3].id,
      );
      expect(worstCheck(androidChecks(7)), isNull);
    });

    test('the fix comes from the first attention check that has one', () {
      const fix = OpenRouteFix('somewhere');
      var checks = withCheckAt(androidChecks(7), 1, ReliabilityState.broken);
      checks = withCheckAt(checks, 2, ReliabilityState.needsLook, fix: fix);
      // The broken check has nothing to do, so the next one is offered.
      expect(checkToFix(checks)?.fix, fix);
    });

    test('a broken check with a fix goes before a look check with one', () {
      const brokenFix = OpenRouteFix('broken');
      const lookFix = OpenRouteFix('look');
      var checks = withCheckAt(
        androidChecks(7),
        1,
        ReliabilityState.needsLook,
        fix: lookFix,
      );
      checks = withCheckAt(
        checks,
        5,
        ReliabilityState.broken,
        fix: brokenFix,
      );
      expect(checkToFix(checks)?.fix, brokenFix);
    });

    test('no fix anywhere gives null', () {
      expect(
        checkToFix(withCheckAt(androidChecks(7), 1, ReliabilityState.broken)),
        isNull,
      );
    });
  });
}
