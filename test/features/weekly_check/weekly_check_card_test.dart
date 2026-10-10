import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';

void main() {
  setUpAll(loadTestTranslations);

  group('weeklyCheckCardKindFor', () {
    test('locked and not offered never have a switch', () {
      expect(
        weeklyCheckCardKindFor(WeeklyCheckStanding.locked),
        WeeklyCheckCardKind.locked,
      );
      expect(
        weeklyCheckCardKindFor(WeeklyCheckStanding.notOffered),
        WeeklyCheckCardKind.notOffered,
      );
      expect(WeeklyCheckCardKind.locked.hasSwitch, isFalse);
      expect(WeeklyCheckCardKind.notOffered.hasSwitch, isFalse);
    });

    test('every standing with Hosted held has the switch, on or off', () {
      for (final standing in WeeklyCheckStanding.values) {
        final kind = weeklyCheckCardKindFor(standing);
        final away =
            standing == WeeklyCheckStanding.locked ||
            standing == WeeklyCheckStanding.notOffered;
        expect(kind.hasSwitch, !away, reason: standing.name);
      }
      expect(
        weeklyCheckCardKindFor(WeeklyCheckStanding.received),
        WeeklyCheckCardKind.held,
      );
      expect(
        weeklyCheckCardKindFor(WeeklyCheckStanding.off),
        WeeklyCheckCardKind.held,
      );
    });

    test('the switch stands where the standing says', () {
      final on = weeklyCheckCardView(
        standing: WeeklyCheckStanding.received,
        check: null,
        now: DateTime(2026, 10, 9),
      );
      final off = weeklyCheckCardView(
        standing: WeeklyCheckStanding.off,
        check: null,
        now: DateTime(2026, 10, 9),
      );
      expect(on.isOn, isTrue);
      expect(off.isOn, isFalse);
    });
  });

  group('weeklyCheckCardShowsSeePlan', () {
    test('there is no button until the plan is read', () {
      expect(
        weeklyCheckCardShowsSeePlan(planWord: null, canUnlock: true),
        isFalse,
      );
    });

    test('the button needs a way to open the paywall', () {
      expect(
        weeklyCheckCardShowsSeePlan(planWord: 'Hosted', canUnlock: false),
        isFalse,
      );
      expect(
        weeklyCheckCardShowsSeePlan(planWord: 'Hosted', canUnlock: true),
        isTrue,
      );
    });
  });

  group('weeklyCheckCardView', () {
    final now = DateTime(2026, 10, 9, 12);

    WeeklyCheck check(int? nextDueAt) => WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      nextDueAt: nextDueAt,
    );

    test('an on check with a next round says when it is', () {
      final due = DateTime(2026, 10, 12, 9).millisecondsSinceEpoch ~/ 1000;
      final view = weeklyCheckCardView(
        standing: WeeklyCheckStanding.received,
        check: check(due),
        now: now,
      );
      expect(view.lineWhen, 'Monday 09:00');
    });

    test('with no next round it falls back to the row line', () {
      final view = weeklyCheckCardView(
        standing: WeeklyCheckStanding.received,
        check: check(null),
        now: now,
      );
      expect(view.lineKey, isNot(LocaleKeys.proof_card_next_round));
    });

    test('an off check says what it does, whatever the relay named', () {
      final due = DateTime(2026, 10, 12, 9).millisecondsSinceEpoch ~/ 1000;
      final view = weeklyCheckCardView(
        standing: WeeklyCheckStanding.off,
        check: check(due),
        now: now,
      );
      expect(view.lineWhen, isNull);
    });
  });

  group('lockTapFor with the See Hosted button', () {
    test(
      'it opens the paywall only for a locked feature with the plan read',
      () {
        const locked = FeatureDecision.locked(Holding.hosted);
        expect(
          lockTapFor(
            decision: locked,
            isPlanRead: true,
            hasTry: false,
            tap: LockTapKind.seePlan,
          ),
          const OpenPaywall(Holding.hosted),
        );
        expect(
          lockTapFor(
            decision: locked,
            isPlanRead: false,
            hasTry: false,
            tap: LockTapKind.seePlan,
          ),
          const WaitForPlan(),
        );
        expect(
          lockTapFor(
            decision: const FeatureDecision.notOffered(),
            isPlanRead: true,
            hasTry: false,
            tap: LockTapKind.seePlan,
          ),
          const Nothing(),
        );
      },
    );
  });
}
