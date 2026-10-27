import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence/sentence_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the endings', () {
    test('every benefit has an ending and a name of its own', () {
      final tails = {
        for (final id in PaywallBenefitId.values) sentenceTailKeyFor(id),
      };
      final names = {
        for (final id in PaywallBenefitId.values) sentenceNameKeyFor(id),
      };
      expect(tails, hasLength(PaywallBenefitId.values.length));
      expect(names, hasLength(PaywallBenefitId.values.length));
      expect(tails.intersection(names), isEmpty);
    });
  });

  group('the roll', () {
    test('at rest the ending is in place and nothing is leaving', () {
      final roll = sentenceRollAt(enter: 1, direction: 0, isChange: true);
      expect(roll.arriving, 0);
      expect(roll.leaving, isNull);
    });

    test('the same ending playing again does not roll', () {
      final roll = sentenceRollAt(enter: 0.3, direction: 0, isChange: false);
      expect(roll.arriving, 0);
      expect(roll.leaving, isNull);
    });

    test('it rolls upwards: the new one from below, the old over the top', () {
      final start = sentenceRollAt(enter: 0, direction: 0, isChange: true);
      expect(start.arriving, 1);
      expect(start.leaving, 0);

      final half = sentenceRollAt(enter: 0.5, direction: 1, isChange: true);
      expect(half.arriving, 0.5);
      expect(half.leaving, -0.5);
    });

    test('a swipe back rolls the other way', () {
      final half = sentenceRollAt(enter: 0.25, direction: -1, isChange: true);
      expect(half.arriving, -0.75);
      expect(half.leaving, 0.25);
    });

    test('the two endings are always one whole box apart', () {
      for (final enter in [0.0, 0.2, 0.6, 0.99]) {
        for (final direction in [-1, 0, 1]) {
          final roll = sentenceRollAt(
            enter: enter,
            direction: direction,
            isChange: true,
          );
          expect((roll.arriving - roll.leaving!).abs(), closeTo(1, 1e-9));
        }
      }
    });
  });

  group('the first ending', () {
    test('waits one box below, out of sight, until its turn', () {
      final before = sentenceFirstRollAt(sentenceFirstRollStart);
      expect(before.arriving, 1);
      expect(before.shown, 0);
    });

    test('rolls up into place and stays there', () {
      const mid = (sentenceFirstRollStart + sentenceFirstRollEnd) / 2;
      final half = sentenceFirstRollAt(mid);
      expect(half.arriving, inExclusiveRange(0, 1));
      expect(half.shown, inExclusiveRange(0, 1));

      for (final t in [sentenceFirstRollEnd, heroEntranceSeconds, 9.0]) {
        final landed = sentenceFirstRollAt(t);
        expect(landed.arriving, closeTo(0, 1e-9));
        expect(landed.shown, 1);
      }
    });

    test('is in place before the entrance is over', () {
      expect(sentenceFirstRollEnd, lessThanOrEqualTo(heroEntranceSeconds));
    });

    test('is heard as it starts, after the mascot has landed', () {
      final cues = sentenceCues(prelude: 0);
      expect(
        [for (final beat in cues) beat.cue],
        [
          PaywallCue.pop,
          PaywallCue.roll,
        ],
      );
      expect(cues.last.at, sentenceFirstRollStart);
      expect(cues.first.at, lessThan(cues.last.at));
      // A head start moves both.
      final early = sentenceCues(prelude: -0.3);
      expect(early.last.at, closeTo(sentenceFirstRollStart - 0.3, 1e-9));
    });
  });

  group('the motion', () {
    test('is its own: rays, in from the side, a hop for each ending', () {
      expect(sentenceMotion.atmosphere, HeroAtmosphereStyle.rays);
      expect(sentenceMotion.entrance, HeroEntranceStyle.slide);
      expect(sentenceMotion.idle, HeroIdleStyle.benefitHop);
      expect(sentenceMotion.arrival, HeroCardArrival.fade);
    });

    test('after an intro the mascot is already in its place', () {
      expect(sentencePreludeFor(followsIntro: false), 0);
      final prelude = sentencePreludeFor(followsIntro: true);
      expect(prelude, lessThan(0));
      // The entrance is this far in when the layout's clock starts.
      final pose = heroEntrancePose(
        sentenceMotion.entrance,
        -prelude / heroEntranceSeconds,
        size: 160,
      );
      expect(pose.dx, closeTo(0, 1e-9));
      expect(pose.opacity, 1);
    });
  });
}
