import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the landing', () {
    test('is when the mascot is first whole in its place', () {
      for (final style in HeroEntranceStyle.values) {
        final at = heroLandsAt(style);
        final pose = heroEntrancePose(style, at, size: 120, footDrop: 120);
        expect(pose.dx.abs(), lessThan(4), reason: style.name);
        expect(pose.dy.abs(), lessThan(4), reason: style.name);
        expect(pose.scale, closeTo(1, 0.03), reason: style.name);
        expect(pose.opacity, 1, reason: style.name);
        // A little earlier it was still on its way.
        final early = heroEntrancePose(
          style,
          at - 0.08,
          size: 120,
          footDrop: 120,
        );
        expect(
          early.dx.abs() + early.dy.abs() + (1 - early.scale).abs() * 120,
          greaterThan(4),
          reason: style.name,
        );
      }
    });

    test('a drop bounces and the rest pop', () {
      expect(heroLandingCue(HeroEntranceStyle.drop), PaywallCue.drop);
      for (final style in [
        HeroEntranceStyle.pop,
        HeroEntranceStyle.slide,
        HeroEntranceStyle.peek,
      ]) {
        expect(heroLandingCue(style), PaywallCue.pop, reason: style.name);
      }
    });
  });

  group('the approved entrance', () {
    test('is the mascot landing, then the card sliding in', () {
      final cues = heroEntranceCues(const HeroMotion());
      expect(
        [for (final beat in cues) beat.cue],
        [
          PaywallCue.pop,
          PaywallCue.whoosh,
        ],
      );
      expect(cues.first.at, lessThan(cues.last.at));
      expect(cues.last.at, heroCardStartsAt * heroEntranceSeconds);
      expect(cues.last.at, lessThan(heroEntranceSeconds));
    });

    test('every moment waits for a beat of the layout before it', () {
      final alone = heroEntranceCues(const HeroMotion());
      final after = heroEntranceCues(const HeroMotion(), prelude: 0.6);
      for (final (i, beat) in after.indexed) {
        expect(beat.at, closeTo(alone[i].at + 0.6, 1e-9));
      }
    });

    test('a stage with no card sliding in has only the landing', () {
      final cues = heroEntranceCues(
        const HeroMotion(entrance: HeroEntranceStyle.drop),
        cardSlides: false,
      );
      expect(cues.single.cue, PaywallCue.drop);
    });
  });
}
