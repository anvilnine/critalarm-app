import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

HeroLoop _loop() => HeroLoop(const [
  PaywallPreviewId.topics,
  PaywallPreviewId.pushes,
  PaywallPreviewId.history,
  PaywallPreviewId.appIcons,
], holdSeconds: reelHoldSeconds);

void main() {
  group('the tone of a scene', () {
    test('no two neighbours share one, round the loop included', () {
      for (var count = 2; count <= 9; count++) {
        for (var i = 0; i < count - 1; i++) {
          expect(reelToneFor(i), isNot(reelToneFor(i + 1)));
        }
      }
      // Hosted has four scenes and Pro five: the last and the first differ.
      expect(reelToneFor(3), isNot(reelToneFor(0)));
      expect(reelToneFor(4), isNot(reelToneFor(0)));
    });

    test('the first scene is not the canvas the buy block sits on', () {
      expect(reelToneFor(0), isNot(ReelTone.canvas));
    });

    test('only the canvas keeps its own atmosphere colours', () {
      expect(reelAirFor(ReelTone.canvas), PaywallTone.canvas);
      expect(reelAirFor(ReelTone.panel), PaywallTone.panel);
      for (final tone in [ReelTone.cream, ReelTone.high, ReelTone.surface]) {
        expect(reelAirFor(tone), PaywallTone.surface);
      }
    });
  });

  group('the story bars', () {
    test('seen scenes are full, the playing one fills, the rest wait', () {
      expect(reelBarFill(0, active: 2, progress: 0.4), 1);
      expect(reelBarFill(1, active: 2, progress: 0.4), 1);
      expect(reelBarFill(2, active: 2, progress: 0.4), 0.4);
      expect(reelBarFill(3, active: 2, progress: 0.4), 0);
    });

    test('a bar never fills past its ends', () {
      expect(reelBarFill(0, active: 0, progress: 1.4), 1);
      expect(reelBarFill(0, active: 0, progress: -0.2), 0);
    });

    test('they follow the loop: the second bar fills in the second turn', () {
      final loop = _loop();
      final second = loop.scenes[1];
      final frame = loop.frameAt(
        loop.entranceEnd + second.start + second.script.seconds / 2,
      );
      expect(frame.activeIndex, 1);
      expect(
        reelBarFill(1, active: frame.activeIndex, progress: frame.progress),
        closeTo(0.5, 0.01),
      );
    });

    test('the resting frame is the first scene with its bar full', () {
      final rest = _loop().rest;
      expect(rest.activeIndex, 0);
      expect(
        reelBarFill(0, active: rest.activeIndex, progress: rest.progress),
        1,
      );
      expect(
        reelBarFill(1, active: rest.activeIndex, progress: rest.progress),
        0,
      );
    });
  });

  group('the hand', () {
    test('the right half is next and the left half is previous', () {
      expect(reelTapStep(300, 390), 1);
      expect(reelTapStep(195, 390), 1);
      expect(reelTapStep(194, 390), -1);
      expect(reelTapStep(10, 390), -1);
    });

    test('a short touch is a tap and a long one is a hold', () {
      expect(reelIsHold(const Duration(milliseconds: 120)), isFalse);
      expect(reelIsHold(reelHoldAfter), isTrue);
      expect(reelIsHold(const Duration(seconds: 3)), isTrue);
    });

    test('a tap on the left of the first scene wraps to the last', () {
      final loop = _loop();
      final hand = loop.touch(loop.entranceEnd + 0.5, step: -1);
      expect(hand!.index, 3);
      expect(hand.direction, -1);
    });

    test('a chosen scene holds for less time than the kit holds', () {
      final loop = _loop();
      expect(loop.holdSeconds, reelHoldSeconds);
      expect(reelHoldSeconds, lessThan(heroHandHoldSeconds));
    });
  });

  group('the push', () {
    test('the next scene comes from the right and the old one leaves left', () {
      final start = reelPushAt(0, 1);
      expect(start.into, 1);
      expect(start.out, 0);
      final end = reelPushAt(1, 1);
      expect(end.into, 0);
      expect(end.out, -1);
    });

    test('the previous scene comes from the left', () {
      final half = reelPushAt(0.5, -1);
      expect(half.into, -0.5);
      expect(half.out, 0.5);
    });

    test('a scene the loop brought comes from the right', () {
      expect(reelPushAt(0.25, 0).into, 0.75);
      expect(reelPushAt(0.25, 0).out, -0.25);
    });

    test('the two scenes always touch: one scene width apart', () {
      for (final eased in [0.0, 0.3, 0.8, 1.0]) {
        for (final direction in [-1, 0, 1]) {
          final push = reelPushAt(eased, direction);
          expect((push.into - push.out).abs(), closeTo(1, 1e-9));
        }
      }
    });
  });

  group('the frames of the two scenes', () {
    test('no scene is leaving at rest, in the entrance or mid turn', () {
      final loop = _loop();
      expect(reelLeaving(loop.rest), isNull);
      expect(reelLeaving(loop.frameAt(0.4)), isNull);
      expect(reelLeaving(loop.frameAt(loop.entranceEnd + 1)), isNull);
    });

    test('as the second turn starts the first scene is the one leaving', () {
      final loop = _loop();
      final t = loop.entranceEnd + loop.scenes[1].start + 0.1;
      final frame = loop.frameAt(t);
      final leaving = reelLeaving(frame)!;
      expect(leaving.activeIndex, 0);
      expect(leaving.previous, isNull);
      expect(leaving.cardEnter, 1);
      expect(leaving.entrance, 1);
      expect(leaving.face, frame.fromFace);
      expect(leaving.playFrom, frame.previousPlayFrom);

      final now = reelSettled(frame);
      expect(now.activeIndex, 1);
      expect(now.previous, isNull);
      expect(now.cardEnter, 1);
      expect(now.face, frame.face);
      expect(now.playFrom, frame.playFrom);
      expect(now.progress, frame.progress);
    });

    test('once the push is over only one scene is drawn', () {
      final loop = _loop();
      final t = loop.entranceEnd + loop.scenes[1].start + heroCardBlend + 0.01;
      expect(reelLeaving(loop.frameAt(t)), isNull);
    });
  });

  group('the room of the stage', () {
    test('it takes what the bars, the words and the gaps leave', () {
      final sizes = ReelSizes.of(isCompact: false);
      expect(
        reelStageHeight(height: 600, words: 100, sizes: sizes),
        600 - reelBarsHeight - 100 - sizes.stageGap - sizes.foot - reelSceneGap,
      );
    });

    test('it is never under zero', () {
      expect(
        reelStageHeight(
          height: 120,
          words: 300,
          sizes: ReelSizes.of(isCompact: true),
        ),
        0,
      );
    });
  });

  group('the motion of the reel', () {
    test('the stage picks its own variants', () {
      expect(reelMotion.atmosphere, HeroAtmosphereStyle.rings);
      expect(reelMotion.entrance, HeroEntranceStyle.slide);
      expect(reelMotion.idle, HeroIdleStyle.benefitHop);
      expect(reelMotion.arrival, HeroCardArrival.slideThrough);
    });

    test('after an intro the mascot is in its place on the first frame', () {
      expect(reelPreludeFor(followsIntro: false), 0);
      final loop = HeroLoop(const [
        PaywallPreviewId.topics,
        PaywallPreviewId.pushes,
      ], prelude: reelPreludeFor(followsIntro: true));
      final first = loop.frameAt(0);
      final pose = heroEntrancePose(
        reelMotion.entrance,
        first.entrance,
        size: 160,
      );
      expect(pose.dx, closeTo(0, 1e-9));
      expect(pose.opacity, 1);
      expect(loop.entranceEnd, lessThan(heroEntranceSeconds));
    });

    test('only the first pass of an untouched reel is felt', () {
      bool cues(double began, {double? was = 1, bool touched = false}) =>
          reelCuesPush(
            began: began,
            was: was,
            entranceEnd: 1,
            period: 10,
            touched: touched,
          );
      // The first page is the entrance, not a push.
      expect(cues(1, was: null), isFalse);
      expect(cues(1), isFalse);
      expect(cues(3.5), isTrue);
      expect(cues(3.5, was: 3.5), isFalse);
      // The second pass, a touch, and a clock that went back.
      expect(cues(11, was: 9), isFalse);
      expect(cues(3.5, touched: true), isFalse);
      expect(cues(3.5, was: 6), isFalse);
    });
  });
}
