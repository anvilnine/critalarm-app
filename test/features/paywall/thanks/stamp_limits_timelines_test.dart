import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/limits/limits_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/limits/limits_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/stamp/stamp_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/stamp/stamp_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _phones = [
  (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  (Size(375, 667), EdgeInsets.only(top: 20)),
];

void main() {
  group('StampTimeline', () {
    test('the slip is caught on the peak and the stamp waits for the cue '
        'to end', () {
      expect(StampTimeline.caught, 0.6);
      expect(StampTimeline.fed(StampTimeline.caught), 1);
      expect(StampTimeline.caught, lessThan(StampTimeline.firstLine));
      expect(StampTimeline.goOn, lessThanOrEqualTo(paywallThanksButtonBy));
      expect(
        StampTimeline.stampAt,
        greaterThanOrEqualTo(paywallBoughtCueSeconds),
      );
      expect(StampTimeline.stampAt, lessThan(StampTimeline.raise));
      expect(StampTimeline.raised, lessThan(StampTimeline.end));
    });

    test('every line is printed before the stamp comes down', () {
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        for (var i = 1; i < lines; i++) {
          expect(
            StampTimeline.lineAt(i, lines),
            greaterThan(StampTimeline.lineAt(i - 1, lines)),
          );
        }
        expect(
          StampTimeline.lineAt(lines - 1, lines) + StampTimeline.lineSeconds,
          lessThan(StampTimeline.stampFalls),
        );
      }
    });

    test('the beats are haptics under the cue and one stamp after it', () {
      expect(stampThanks.isSound, isTrue);
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        final heard = [
          for (final beat in stampBeats(lines))
            if (beat.isHeard) beat,
        ];
        expect(heard, hasLength(1));
        expect(heard.single.cue, PaywallCue.stamp);
        expect(heard.single.at, StampTimeline.stampAt);
      }
    });

    test('the first frame is the paywall with the button whole', () {
      expect(StampTimeline.covered(0), 0);
      expect(StampTimeline.button(0), 1);
      expect(StampTimeline.travel(0), 0);
      expect(StampTimeline.fed(0), 0);
      expect(StampTimeline.stamp(0).opacity, 0);
      expect(StampTimeline.headlineIn(0), 0);
    });

    test('the stamp comes down large and lands at its own size', () {
      const before = StampTimeline.stampFalls + 0.02;
      expect(StampTimeline.stamp(before).scale, greaterThan(2));
      expect(
        StampTimeline.stamp(StampTimeline.stampAt).scale,
        closeTo(1, 1e-9),
      );
      expect(StampTimeline.pressed(StampTimeline.stampAt), 0);
      expect(
        StampTimeline.pressed(StampTimeline.stampAt + 0.1),
        greaterThan(0),
      );
    });

    test('the resting frame is complete, and only the stamp is turned', () {
      for (final t in [StampTimeline.end, StampTimeline.end + 30]) {
        expect(StampTimeline.covered(t), 1);
        expect(StampTimeline.button(t), 0);
        expect(StampTimeline.travel(t), 1);
        expect(StampTimeline.fed(t), 1);
        expect(StampTimeline.lift(t, lines: 4), 0);
        expect(StampTimeline.stretch(t), closeTo(1, 1e-9));
        expect(StampTimeline.pressed(t), closeTo(0, 1e-9));
        expect(StampTimeline.disc(t), closeTo(1, 1e-9));
        expect(StampTimeline.headlineIn(t), 1);
        final stamp = StampTimeline.stamp(t);
        expect(stamp.opacity, 1);
        expect(stamp.scale, closeTo(1, 1e-9));
        expect(stamp.angle, StampTimeline.stampAngle);
        for (var i = 0; i < 5; i++) {
          expect(StampTimeline.printed(t, i, 5), 1);
        }
      }
      expect(StampTimeline.face(StampTimeline.end).to, HeroFace.proud);
    });

    test('the mascot, the slip and the headline fit above the button', () {
      for (final (size, padding) in _phones) {
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          final plan = StampPlan.of(size: size, padding: padding, lines: lines);
          final foot = size.height - padding.bottom - paywallThanksButtonRoom;
          expect(plan.crit.top, greaterThan(padding.top));
          expect(plan.paper.top, lessThan(plan.crit.bottom));
          expect(plan.paper.bottom, lessThan(plan.headline.top));
          expect(plan.headline.top + plan.headlineSize * 1.15, lessThan(foot));
          expect(plan.paper.center.dx, closeTo(size.width / 2, 1e-6));
          expect(plan.paperAt(0, 700).top, 700);
          expect(plan.paperAt(1, 700).top, closeTo(plan.paper.top, 1e-6));
        }
      }
    });
  });

  group('LimitsTimeline', () {
    test('the first limit goes on the peak, the rest in order, and the '
        'mascot grows after the cue', () {
      expect(LimitsTimeline.firstLift, 0.6);
      expect(LimitsTimeline.goOn, lessThanOrEqualTo(paywallThanksButtonBy));
      expect(
        LimitsTimeline.grow,
        greaterThanOrEqualTo(paywallBoughtCueSeconds),
      );
      for (var count = 1; count <= paywallThanksMaxLines; count++) {
        for (var i = 1; i < count; i++) {
          expect(
            LimitsTimeline.liftAt(i, count),
            greaterThan(LimitsTimeline.liftAt(i - 1, count)),
          );
        }
        expect(
          LimitsTimeline.liftAt(count - 1, count) + LimitsTimeline.liftSeconds,
          lessThanOrEqualTo(LimitsTimeline.grow + 1e-9),
        );
      }
    });

    test('the beats are haptics under the cue and one cue after it', () {
      expect(limitsThanks.isSound, isTrue);
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        final heard = [
          for (final beat in limitsBeats(lines))
            if (beat.isHeard) beat,
        ];
        expect(heard.single.cue, PaywallCue.lift);
        expect(heard.single.at, LimitsTimeline.grow);
      }
    });

    test('the first frame is the paywall, and every row comes in at its '
        'cap', () {
      expect(LimitsTimeline.covered(0), 0);
      expect(LimitsTimeline.travel(0), 0);
      expect(LimitsTimeline.rowIn(0, 0), 0);
      const before = LimitsTimeline.firstLift - 0.01;
      for (var i = 0; i < 4; i++) {
        expect(LimitsTimeline.rowIn(before, i), 1);
        expect(LimitsTimeline.lifted(before, i, 4), 0);
        expect(LimitsTimeline.broken(before, i, 4), 0);
        expect(LimitsTimeline.filled(before, i, 4), LimitsTimeline.capShare);
        expect(LimitsTimeline.count(before, i, 4, from: 50, to: 1000), 50);
        expect(LimitsTimeline.turnAngle(before, i, 4), 0);
      }
      expect(LimitsTimeline.size(before, count: 4), LimitsTimeline.small);
    });

    test('a bar is heavy at its cap and rests light once it is lifted', () {
      const before = LimitsTimeline.firstLift - 0.01;
      for (var count = 1; count <= paywallThanksMaxLines; count++) {
        for (var i = 0; i < count; i++) {
          expect(LimitsTimeline.eased(before, i, count), 0);
          // It lets go only once it has run to its end.
          final at = LimitsTimeline.liftAt(i, count);
          expect(LimitsTimeline.eased(at + 0.3, i, count), 0);
          expect(LimitsTimeline.filled(at + 0.4, i, count), greaterThan(0.99));
          expect(LimitsTimeline.eased(LimitsTimeline.end, i, count), 1);
        }
      }
      expect(LimitsTimeline.restThick, lessThan(0.5));
      expect(LimitsTimeline.restInk, lessThan(0.5));
    });

    test('a number only goes up, from the cap to the one the product has', () {
      var last = 50;
      for (var t = 0.0; t < LimitsTimeline.end; t += 0.01) {
        final now = LimitsTimeline.count(t, 1, 4, from: 50, to: 1000);
        expect(now, greaterThanOrEqualTo(last));
        expect(now, lessThanOrEqualTo(1000));
        last = now;
      }
      expect(last, 1000);
    });

    test('the mascot grows with each limit and most at the end', () {
      const count = 4;
      var last = LimitsTimeline.small;
      for (var i = 0; i < count; i++) {
        final after =
            LimitsTimeline.liftAt(i, count) + LimitsTimeline.liftSeconds;
        final size = LimitsTimeline.size(after, count: count);
        expect(size, greaterThan(last));
        last = size;
      }
      expect(
        LimitsTimeline.size(LimitsTimeline.grow, count: count),
        closeTo(LimitsTimeline.middle, 1e-9),
      );
      expect(
        1 - LimitsTimeline.middle,
        greaterThan((LimitsTimeline.middle - LimitsTimeline.small) / count),
      );
    });

    test('a card shows its locked face to the half turn and lies flat at '
        'both ends', () {
      final at = LimitsTimeline.liftAt(0, 2);
      expect(LimitsTimeline.turned(at + 0.1, 0, 2), lessThan(0.5));
      expect(LimitsTimeline.turned(at + 0.4, 0, 2), greaterThan(0.5));
      expect(LimitsTimeline.turnAngle(at, 0, 2), 0);
      expect(LimitsTimeline.turnAngle(at + 0.2, 0, 2), isNot(0));
    });

    test('the resting frame is complete for every count', () {
      for (var count = 1; count <= paywallThanksMaxLines; count++) {
        for (final t in [LimitsTimeline.end, LimitsTimeline.end + 30]) {
          expect(LimitsTimeline.covered(t), 1);
          expect(LimitsTimeline.travel(t), 1);
          expect(LimitsTimeline.size(t, count: count), closeTo(1, 1e-9));
          expect(LimitsTimeline.lift(t, count: count), 0);
          expect(LimitsTimeline.stretch(t), closeTo(1, 1e-9));
          expect(LimitsTimeline.disc(t), closeTo(1, 1e-9));
          expect(LimitsTimeline.ring(t), 1);
          expect(LimitsTimeline.headlineIn(t), 1);
          for (var i = 0; i < count; i++) {
            expect(LimitsTimeline.rowIn(t, i), 1);
            expect(LimitsTimeline.lifted(t, i, count), 1);
            expect(LimitsTimeline.broken(t, i, count), 1);
            expect(LimitsTimeline.filled(t, i, count), closeTo(1, 1e-9));
            expect(LimitsTimeline.count(t, i, count, from: 7, to: 90), 90);
            expect(LimitsTimeline.turned(t, i, count), 1);
            expect(LimitsTimeline.turnAngle(t, i, count), closeTo(0, 1e-9));
          }
        }
      }
      expect(
        LimitsTimeline.face(LimitsTimeline.end, count: 4).to,
        HeroFace.glad,
      );
    });

    test('the mascot, the headline and the rows fit above the button', () {
      for (final (size, padding) in _phones) {
        for (final isCards in [false, true]) {
          for (var count = 1; count <= paywallThanksMaxLines; count++) {
            final plan = LimitsPlan.of(
              size: size,
              padding: padding,
              count: count,
              isCards: isCards,
            );
            final foot = size.height - padding.bottom - paywallThanksButtonRoom;
            expect(plan.crit.top, greaterThan(padding.top));
            expect(plan.headline.top, greaterThan(plan.crit.bottom));
            expect(plan.rows.top, plan.headline.bottom);
            expect(plan.row(count - 1).bottom, lessThan(foot));
            expect(plan.rowHeight, greaterThan(30));
            expect(plan.critAt(0.6).bottom, closeTo(plan.crit.bottom, 1e-6));
            expect(
              plan.critAt(0.6).center.dx,
              closeTo(plan.crit.center.dx, 1e-6),
            );
            expect(plan.critAt(1).top, closeTo(plan.crit.top, 1e-6));
            expect(plan.critAt(1).width, closeTo(plan.crit.width, 1e-6));
          }
        }
      }
    });
  });

  group('the plan numbers', () {
    test('a rolling value ends on the words the app has', () {
      expect(limitsCountText(1000), '1,000');
      expect(
        limitsCountText(hostedP4Daily),
        HostedBenefit.args['hosted_p4_daily'],
      );
      expect(limitsRolling('1,000', to: 1000, count: 50), '50');
      expect(limitsRolling('1,000', to: 1000, count: 1000), '1,000');
      expect(limitsRolling('90 days', to: 90, count: 8), '8 days');
      expect(limitsRolling('No limit', to: 90, count: 8), isNull);
    });

    test(
      'a row reads the free value, rolls, and ends on the product value',
      () {
        const row = LimitsRow(
          label: 'History kept',
          free: '7 days',
          now: '90 days',
          freeCount: 7,
          nowCount: 90,
        );
        expect(row.valueAt(0, 7), '7 days');
        expect(row.valueAt(0.5, 40), '40 days');
        expect(row.valueAt(1, 90), '90 days');
        // A limit that is not a number on both plans has nothing to roll.
        const open = LimitsRow(
          label: 'Topics',
          free: '2',
          now: 'No limit',
          freeCount: 2,
        );
        expect(open.valueAt(0, 2), '2');
        expect(open.valueAt(0.5, 2), 'No limit');
        // An allowance keeps its words and rolls its number.
        const daily = LimitsRow(
          label: 'High priority pushes',
          free: '50 a day',
          now: '1,000 a day',
          freeCount: 50,
          nowCount: 1000,
        );
        expect(daily.rolls, isTrue);
        expect(open.rolls, isFalse);
        expect(daily.valueAt(0, 50), '50 a day');
        expect(daily.valueAt(0.5, 400), '400 a day');
        expect(daily.valueAt(1, 1000), '1,000 a day');
      },
    );

    test('each free value reads as the limit it is, and each number is '
        'the plan fact', () {
      final benefits = paywallBenefitsFor(PaywallProduct.hosted);
      final plain = limitsRowsFor(benefits)!;
      final caps = limitsCapRowsFor(benefits)!;
      expect(caps, hasLength(plain.length));
      final free = {
        for (final (i, benefit) in benefits.indexed)
          benefit.id: (caps[i].free, caps[i].now),
      };
      expect(free[PaywallBenefitId.topics], ('2 of 2', 'No limit'));
      expect(free[PaywallBenefitId.pushes], ('50 a day', '1,000 a day'));
      expect(free[PaywallBenefitId.history], ('7 days', '90 days'));
      expect(free[PaywallBenefitId.appIcons], ('Default only', 'Three extra'));
      for (final (i, row) in caps.indexed) {
        expect(row.freeCount, plain[i].freeCount);
        expect(row.nowCount, plain[i].nowCount);
        // A row that rolls ends on its own product value.
        if (row.rolls) {
          expect(row.valueAt(0.5, row.nowCount!), row.now);
        }
      }
      // The slip of the receipt party reads the compare table as it is.
      expect(plain.map((row) => row.free), ['2', '50', '7 days', 'Default']);
    });

    test('every Hosted benefit a layout lists has its plan facts, and the '
        'numbers are the ones the caps hold', () {
      for (final benefit in paywallBenefitsFor(PaywallProduct.hosted)) {
        expect(limitsHostedFor(benefit), isNotNull, reason: benefit.id.key);
      }
      final pushes = limitsHostedFor(
        paywallBenefitsFor(
          PaywallProduct.hosted,
        ).firstWhere((b) => b.id == PaywallBenefitId.pushes),
      )!;
      expect(pushes.freeValue, AccountCaps.free.p4Daily);
      expect(pushes.hostedValue, hostedP4Daily);
      // Pro has no counters: its benefits are drawn as cards.
      for (final benefit in paywallBenefitsFor(PaywallProduct.pro)) {
        expect(limitsHostedFor(benefit), isNull, reason: benefit.id.key);
      }
      expect(limitsCapRowsFor(paywallBenefitsFor(PaywallProduct.pro)), isNull);
    });
  });
}
