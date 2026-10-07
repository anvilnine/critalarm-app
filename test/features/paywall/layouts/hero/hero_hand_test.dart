import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero_paywall_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const List<PaywallPreviewId> _previews = [
  PaywallPreviewId.topics,
  PaywallPreviewId.pushes,
  PaywallPreviewId.history,
  PaywallPreviewId.appIcons,
];

void main() {
  final loop = HeroLoop(_previews);
  // Seconds each turn lasts: 2.4, 2.6, 2.4, 2.3.
  double seconds(int i) => loop.scenes[i].script.seconds;

  group('untouched', () {
    test('no hand is the loop of the clock alone', () {
      for (var t = 0.0; t < 30; t += 0.37) {
        final frame = loop.frameAt(t);
        expect(frame.isHeld, isFalse);
        expect(frame.direction, 0);
        expect(loop.chosenAt(t), frame.activeIndex);
      }
    });

    test('the pip of the turn fills from empty to full', () {
      expect(loop.frameAt(heroEntranceSeconds).progress, 0);
      expect(
        loop.frameAt(heroEntranceSeconds + 1.2).progress,
        closeTo(0.5, 1e-9),
      );
      expect(
        loop.frameAt(heroEntranceSeconds + 2.4 - 1e-6).progress,
        closeTo(1, 1e-3),
      );
    });
  });

  group('a swipe', () {
    test('to the next benefit starts its turn from the beginning', () {
      // 1.5 seconds into the first turn.
      const t = heroEntranceSeconds + 1.5;
      final hand = loop.touch(t, step: 1)!;
      expect(hand.index, 1);
      expect(hand.since, t);
      expect(hand.direction, 1);

      final frame = loop.frameAt(t + 0.1, hand: hand);
      expect(frame.activeIndex, 1);
      expect(frame.sceneSeconds, closeTo(0.1, 1e-9));
      expect(frame.face, HeroFace.watching);
      // Its preview is cued so its loop is `lead` seconds in at the start.
      expect(frame.playFrom, closeTo(t - 0.5, 1e-9));
      // It comes in over the turn that was playing, which carries on.
      expect(frame.previous!.index, 0);
      expect(frame.previousPlayFrom, closeTo(heroEntranceSeconds - 0.3, 1e-9));
      expect(frame.cardEnter, closeTo(0.1 / heroCardBlend, 1e-9));
      expect(frame.direction, 1);
    });

    test('to the previous one comes in from the other side', () {
      const t = heroEntranceSeconds + 3;
      final hand = loop.touch(t, step: -1, pull: 18)!;
      expect(hand.index, 0);
      expect(hand.direction, -1);
      final frame = loop.frameAt(t + 0.05, hand: hand);
      expect(frame.activeIndex, 0);
      expect(frame.direction, -1);
      expect(frame.pull, 18);
    });

    test('wraps at both ends', () {
      expect(loop.touch(heroEntranceSeconds + 0.5, step: -1)!.index, 3);
      // 0.2 seconds into the last turn.
      final last = heroEntranceSeconds + loop.scenes[3].start + 0.2;
      expect(loop.chosenAt(last), 3);
      expect(loop.touch(last, step: 1)!.index, 0);
    });

    test('steps from what the hand chose, not from where the loop would '
        'have been', () {
      const t = heroEntranceSeconds + 0.5;
      final first = loop.touch(t, index: 2)!;
      final second = loop.touch(t + 1, hand: first, step: 1)!;
      expect(second.index, 3);
      final third = loop.touch(t + 2, hand: second, step: 1)!;
      expect(third.index, 0);
    });
  });

  group('a tap on a line', () {
    test('puts that benefit on the stage from its first beat', () {
      const t = heroEntranceSeconds + 6;
      final hand = loop.touch(t, index: 3)!;
      expect(hand.direction, 0);
      final frame = loop.frameAt(t + 0.2, hand: hand);
      expect(frame.activeIndex, 3);
      expect(frame.sceneSeconds, closeTo(0.2, 1e-9));
      expect(frame.props, isEmpty);
      // The mascot starts from the face it had.
      expect(frame.fromFace, loop.frameAt(t).face);
    });

    test('on the line already playing plays it again', () {
      const t = heroEntranceSeconds + 2;
      final hand = loop.touch(t, index: 0)!;
      final frame = loop.frameAt(t + 0.1, hand: hand);
      expect(frame.activeIndex, 0);
      expect(frame.sceneSeconds, closeTo(0.1, 1e-9));
      // The picture before and the picture after are two turns.
      expect(frame.previous!.index, 0);
      expect(frame.previousTurn, isNot(frame.turn));
    });
  });

  group('a tap on the stage', () {
    test('plays the current benefit again and the mascot hops', () {
      const t = heroEntranceSeconds + 2.4 + 1;
      final hand = loop.touch(t)!;
      expect(hand.index, 1);
      expect(hand.direction, 0);
      final frame = loop.frameAt(t + heroTouchHopSeconds / 2, hand: hand);
      expect(frame.activeIndex, 1);
      expect(frame.sceneSeconds, closeTo(heroTouchHopSeconds / 2, 1e-9));
      expect(frame.hop, closeTo(heroTouchHopHeight, 1e-9));
      expect(
        loop.frameAt(t + heroTouchHopSeconds + 0.01, hand: hand).hop,
        0,
      );
    });
  });

  group('the hold', () {
    const t = heroEntranceSeconds + 0.4;
    final hand = loop.touch(t, index: 3)!;
    final played = t + seconds(3);

    test('the chosen turn plays, then holds on its finished frame', () {
      expect(heroHandHoldSeconds, 4);
      final end = loop.frameAt(played - 0.01, hand: hand);
      expect(end.isHeld, isFalse);

      for (final into in [0.0, 1.0, 3.9]) {
        final held = loop.frameAt(played + into, hand: hand);
        expect(held.isHeld, isTrue, reason: '$into');
        expect(held.activeIndex, 3);
        expect(held.sceneSeconds, closeTo(seconds(3), 1e-9));
        expect(held.progress, 1);
        expect(held.face, HeroFace.cool);
        expect(held.faceBlend, 1);
        expect(held.cardEnter, 1);
        // The preview stays on the frame it finished on.
        expect(
          played + into - held.playFrom,
          closeTo(seconds(3) + 2.3, 1e-9),
          reason: 'the preview second does not move',
        );
      }
    });

    test('what the mascot wears stays on through the hold and comes off as '
        'it ends', () {
      final held = loop.frameAt(played + 2, hand: hand);
      expect(held.props[HeroProp.crown], 1);
      expect(held.props[HeroProp.shades], 1);
      final leaving = loop.frameAt(
        played + heroHandHoldSeconds - heroPropBlend / 2,
        hand: hand,
      );
      expect(leaving.props[HeroProp.crown], closeTo(0.5, 1e-9));
    });

    test('it still breathes: the blink and the bob go on', () {
      final bobs = {
        for (final into in [0.5, 1.3, 2.1])
          loop.frameAt(played + into, hand: hand).bob,
      };
      expect(bobs, hasLength(3));
    });

    test('then the loop moves on from the benefit after it', () {
      final resume = loop.resumesAt(hand);
      expect(resume, closeTo(played + heroHandHoldSeconds, 1e-9));
      expect(loop.frameAt(resume - 0.01, hand: hand).activeIndex, 3);

      final next = loop.frameAt(resume + 0.1, hand: hand);
      expect(next.activeIndex, 0);
      expect(next.isHeld, isFalse);
      expect(next.sceneSeconds, closeTo(0.1, 1e-9));
      expect(next.previous!.index, 3);
      expect(next.fromFace, HeroFace.cool);
      expect(next.playFrom, closeTo(resume - 0.3, 1e-9));

      // And goes round as it always did, each turn its own length.
      expect(loop.frameAt(resume + 2.4 + 0.1, hand: hand).activeIndex, 1);
      expect(loop.frameAt(resume + 5.0 + 0.1, hand: hand).activeIndex, 2);
      expect(loop.frameAt(resume + 7.4 + 0.1, hand: hand).activeIndex, 3);
      final round = loop.frameAt(resume + loop.period + 0.1, hand: hand);
      expect(round.activeIndex, 0);
      expect(round.previous!.index, 3);
      expect(round.playFrom, closeTo(resume + loop.period - 0.3, 1e-9));
    });

    test('a touch during the hold starts the new turn at once', () {
      final during = played + 1.5;
      final again = loop.touch(during, hand: hand, step: 1)!;
      expect(again.index, 0);
      expect(again.since, during);
      final frame = loop.frameAt(during + 0.1, hand: again);
      expect(frame.activeIndex, 0);
      expect(frame.isHeld, isFalse);
      expect(frame.sceneSeconds, closeTo(0.1, 1e-9));
      // The held picture fades out still on its finished frame.
      expect(frame.previous!.index, 3);
      expect(
        during + 0.1 - frame.previousPlayFrom!,
        closeTo(seconds(3) + 2.3, 1e-9),
      );
      // The new hold is counted from the new turn.
      expect(
        loop.resumesAt(again),
        closeTo(during + seconds(0) + heroHandHoldSeconds, 1e-9),
      );
    });

    test('a tap on the stage during the hold plays the held benefit '
        'again', () {
      final again = loop.touch(played + 1, hand: hand)!;
      expect(again.index, 3);
      expect(loop.frameAt(played + 1.2, hand: again).isHeld, isFalse);
    });
  });

  group('a touch during the entrance', () {
    test('waits: the entrance plays to its end, then the chosen turn '
        'begins', () {
      final hand = loop.touch(0.4, index: 2)!;
      expect(hand.since, heroEntranceSeconds);
      expect(hand.touchedAt, 0.4);
      expect(loop.chosenAt(0.5, hand: hand), 2);

      // The entrance is the same entrance.
      final entering = loop.frameAt(0.7, hand: hand);
      expect(entering.entrance, closeTo(0.7, 1e-9));
      expect(entering.activeIndex, 0);
      expect(entering.fromFace, HeroFace.arriving);

      final frame = loop.frameAt(heroEntranceSeconds + 0.1, hand: hand);
      expect(frame.entrance, 1);
      expect(frame.activeIndex, 2);
      expect(frame.sceneSeconds, closeTo(0.1, 1e-9));
      expect(frame.previous!.index, 0);
    });

    test('the mascot still hops at the touch', () {
      final hand = loop.touch(0.6, index: 1)!;
      expect(
        loop.frameAt(0.6 + heroTouchHopSeconds / 2, hand: hand).hop,
        closeTo(heroTouchHopHeight, 1e-9),
      );
    });

    test('a second touch before the entrance ends replaces the first', () {
      final first = loop.touch(0.3, index: 2)!;
      final second = loop.touch(0.6, hand: first, step: 1)!;
      expect(second.index, 3);
      expect(second.since, heroEntranceSeconds);
      expect(second.before, isNull);
      final frame = loop.frameAt(heroEntranceSeconds + 0.1, hand: second);
      expect(frame.activeIndex, 3);
      expect(frame.previous!.index, 0);
    });
  });

  group('when nothing may move', () {
    test('a touch cuts to the chosen benefit resting', () {
      final hand = loop.touch(heroEntranceSeconds, step: 1, isStill: true)!;
      expect(hand.index, 1);
      final frame = loop.frameAt(
        heroEntranceSeconds,
        isStill: true,
        hand: hand,
      );
      expect(frame.activeIndex, 1);
      expect(frame.face, HeroFace.glad);
      expect(frame.faceBlend, 1);
      expect(frame.previous, isNull);
      expect(frame.cardEnter, 1);
      expect(frame.props, isEmpty);
      expect(frame.hop, 0);
      expect(frame.bob, 0);
      expect(frame.progress, 1);
    });

    test('and stays there: nothing moves on by itself', () {
      final hand = loop.touch(heroEntranceSeconds, index: 2, isStill: true)!;
      for (final t in [1.0, 9.0, 60.0]) {
        expect(loop.frameAt(t, isStill: true, hand: hand).activeIndex, 2);
      }
    });
  });

  group('one benefit', () {
    final solo = HeroLoop(const [PaywallPreviewId.weeklyCheck]);

    test('any touch plays it again, then it holds and goes round', () {
      const t = heroEntranceSeconds + 5;
      final hand = solo.touch(t, step: 1)!;
      expect(hand.index, 0);
      expect(solo.frameAt(t + 1, hand: hand).sceneSeconds, closeTo(1, 1e-9));
      expect(solo.frameAt(t + 9 + 1, hand: hand).isHeld, isTrue);
      final after = solo.frameAt(solo.resumesAt(hand) + 0.5, hand: hand);
      expect(after.activeIndex, 0);
      expect(after.isHeld, isFalse);
      expect(after.sceneSeconds, closeTo(0.5, 1e-9));
    });
  });

  group('where a tap lands in the list', () {
    // Five lines 19 points tall, 5 apart.
    final centres = [for (var i = 0; i < 5; i++) 40 + 9.5 + i * 24.0];

    test('each line answers 22 points either side of its middle', () {
      expect(heroLineAt(centres[0] - 22, centres), 0);
      expect(heroLineAt(centres[4] + 22, centres), 4);
      expect(heroLineAt(centres[0] - 22.5, centres), isNull);
      expect(heroLineAt(centres[4] + 22.5, centres), isNull);
    });

    test('between two lines the nearer one takes it', () {
      expect(heroLineAt(centres[1] + 11, centres), 1);
      expect(heroLineAt(centres[2] - 11, centres), 2);
      expect(heroLineAt(centres[2], centres), 2);
    });

    test('no lines, no line', () {
      expect(heroLineAt(10, const []), isNull);
    });
  });

  group('the finger on the card', () {
    test('the card follows closely at first and never past its limit', () {
      expect(heroPullFor(0), 0);
      expect(heroPullFor(10), closeTo(5.6, 0.1));
      expect(heroPullFor(-10), closeTo(-5.6, 0.1));
      expect(heroPullFor(4000).abs(), lessThan(56));
      expect(heroPullFor(60), greaterThan(heroPullFor(30)));
    });

    test('a long drag or a quick flick asks for another benefit', () {
      expect(heroSwipeStep(-60, 0), 1);
      expect(heroSwipeStep(60, 0), -1);
      expect(heroSwipeStep(-10, -500), 1);
      expect(heroSwipeStep(10, 500), -1);
      // A flick wins over where the finger ended.
      expect(heroSwipeStep(-50, 400), -1);
    });

    test('a short slow one asks for nothing', () {
      expect(heroSwipeStep(20, 100), 0);
      expect(heroSwipeStep(-43, -200), 0);
    });
  });
}
