import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:flutter_test/flutter_test.dart';

const List<PaywallPreviewId> _hosted = [
  PaywallPreviewId.topics,
  PaywallPreviewId.pushes,
  PaywallPreviewId.history,
  PaywallPreviewId.appIcons,
];

void main() {
  group('proofTurnFor', () {
    test('every turn is two beats: one face on Free, then one hop', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);
        final beats = turn.script.beats;

        expect(beats.first.at, 0, reason: '$preview');
        expect(beats.first.face, proofFreeFace(turn.start));
        expect(beats.first.isReaction, isFalse);
        expect(beats[1].isReaction, isTrue, reason: '$preview');
        expect(turn.liftAt, beats[1].at);
        expect(beats.where((b) => b.isReaction), hasLength(1));
        for (var i = 1; i < beats.length; i++) {
          expect(beats[i].at, greaterThan(beats[i - 1].at));
          expect(beats[i].at, lessThan(turn.script.seconds));
        }
      }
    });

    test('the Free beat is long enough to read and leaves time after', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);

        expect(turn.liftAt, greaterThanOrEqualTo(1), reason: '$preview');
        expect(turn.liftAt, lessThanOrEqualTo(1.7), reason: '$preview');
        expect(turn.script.seconds - turn.liftAt, greaterThanOrEqualTo(0.8));
      }
    });

    test('the hold is inside the Free beat, and the lead makes it', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);

        expect(turn.hold, lessThan(turn.liftAt), reason: '$preview');
        expect(turn.script.lead, closeTo(turn.from - turn.hold, 1e-9));
      }
    });

    test('a refusal is doubted and lands glad', () {
      for (final preview in _hosted.take(3)) {
        final turn = proofTurnFor(preview, count: 4);

        expect(turn.start, ProofStart.refused);
        expect(turn.script.beats.first.face, HeroFace.doubtful);
        expect(turn.script.beats[1].face, HeroFace.glad);
      }
    });

    test('nothing is worn on Free', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);
        for (final at in turn.script.props.values) {
          expect(at, greaterThanOrEqualTo(turn.liftAt), reason: '$preview');
        }
      }
    });

    test('a lone benefit plays the approved turn for one', () {
      final turn = proofTurnFor(PaywallPreviewId.weeklyCheck, count: 1);

      expect(
        turn.script,
        same(heroSoloScripts[PaywallPreviewId.weeklyCheck]),
      );
      expect(turn.liftAt, 3.3);
      expect(proofLockAt(turn, 0), 0);
    });
  });

  group('proofCueAt', () {
    test('holds the first frame, then plays from it', () {
      final turn = proofTurnFor(PaywallPreviewId.pushes, count: 4);
      // The turn began at 10, so the loop cues it at 10 less the lead.
      final playFrom = 10 - turn.script.lead;
      double second(double t) =>
          t - proofCueAt(t, playFrom: playFrom, from: turn.from);

      expect(second(10), closeTo(turn.from, 1e-9));
      expect(second(10 + turn.hold / 2), closeTo(turn.from, 1e-9));
      expect(second(10 + turn.hold), closeTo(turn.from, 1e-9));
      expect(second(10 + turn.hold + 0.5), closeTo(turn.from + 0.5, 1e-9));
    });

    test('a turn with no hold plays from its start', () {
      final turn = proofTurnFor(PaywallPreviewId.topics, count: 4);
      final playFrom = 10 - turn.script.lead;

      expect(
        proofCueAt(10.4, playFrom: playFrom, from: turn.from),
        closeTo(playFrom, 1e-9),
      );
    });
  });

  group('proofLockAt', () {
    test('only a benefit Free does not have is behind a lock', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);
        final isLocked = turn.start == ProofStart.locked;

        expect(proofLockAt(turn, 0), isLocked ? 1 : 0, reason: '$preview');
        expect(proofLockAt(turn, turn.liftAt - 0.01), isLocked ? 1 : 0);
        expect(proofLockAt(turn, turn.liftAt + proofUnlockSeconds), 0);
        expect(proofLockAt(turn, turn.script.seconds), 0);
      }
    });
  });

  group('proofTagAt', () {
    test('says Free until the lift, then the product', () {
      expect(proofTagAt(seconds: 0, liftAt: 1.5).isLifted, isFalse);
      expect(proofTagAt(seconds: 1.49, liftAt: 1.5).isLifted, isFalse);
      expect(proofTagAt(seconds: 1.49, liftAt: 1.5).flat, 1);
      expect(
        proofTagAt(seconds: 1.5 + proofFlipSeconds, liftAt: 1.5).isLifted,
        isTrue,
      );
      expect(proofTagAt(seconds: 9, liftAt: 1.5).flat, 1);
    });

    test('the flip closes to an edge, changes side there, and opens', () {
      final before = proofTagAt(seconds: 1.5 + 0.11, liftAt: 1.5);
      final after = proofTagAt(seconds: 1.5 + 0.13, liftAt: 1.5);

      expect(before.isLifted, isFalse);
      expect(after.isLifted, isTrue);
      expect(before.flat, lessThan(0.15));
      expect(after.flat, lessThan(0.15));
    });

    test('flips back to Free at the start of a turn after a lift', () {
      final early = proofTagAt(
        seconds: 0.05,
        liftAt: 1.5,
        cameFromLifted: true,
      );
      final late = proofTagAt(seconds: 0.2, liftAt: 1.5, cameFromLifted: true);

      expect(early.isLifted, isTrue);
      expect(late.isLifted, isFalse);
      expect(
        proofTagAt(seconds: 0.3, liftAt: 1.5, cameFromLifted: true).flat,
        1,
      );
    });
  });

  group('proofTagFor', () {
    final loop = proofLoopFor(_hosted);

    test('rests lifted and flat', () {
      final tag = proofTagFor(loop.rest, isStill: true);

      expect(tag.isLifted, isTrue);
      expect(tag.flat, 1);
    });

    test('follows the loop: Free, lifted, Free again on the next turn', () {
      final first = loop.scenes.first;
      final lift = loop.entranceEnd + proofLiftAt(first.script);

      expect(proofTagFor(loop.frameAt(0.5)).isLifted, isFalse);
      expect(proofTagFor(loop.frameAt(lift - 0.1)).isLifted, isFalse);
      expect(proofTagFor(loop.frameAt(lift + 0.3)).isLifted, isTrue);

      final next = loop.entranceEnd + first.end;
      expect(proofTagFor(loop.frameAt(next + 0.02)).isLifted, isTrue);
      expect(proofTagFor(loop.frameAt(next + 0.4)).isLifted, isFalse);
    });

    test('the loop wraps: the last turn hands back to the first', () {
      final wrap = loop.entranceEnd + loop.period;

      expect(loop.frameAt(wrap + 0.4).activeIndex, 0);
      expect(proofTagFor(loop.frameAt(wrap + 0.4)).isLifted, isFalse);
    });

    test('a swipe away from a Free beat does not flash the product', () {
      final hand = loop.touch(loop.entranceEnd + 0.4, step: 1)!;
      final tag = proofTagFor(
        loop.frameAt(loop.entranceEnd + 0.42, hand: hand),
      );

      expect(tag.isLifted, isFalse);
      expect(tag.flat, 1);
    });

    test('a chosen turn holds lifted', () {
      final hand = loop.touch(loop.entranceEnd + 5, index: 2)!;
      final held = loop.frameAt(loop.resumesAt(hand) - 0.5, hand: hand);

      expect(held.isHeld, isTrue);
      expect(proofTagFor(held).isLifted, isTrue);
      expect(proofTagFor(held).flat, 1);
    });
  });

  group('the motion of the proof', () {
    final refused = proofTurnFor(PaywallPreviewId.topics, count: 4);
    final plain = proofTurnFor(PaywallPreviewId.appIcons, count: 4);

    test('the stage picks its own variants', () {
      expect(proofMotion.atmosphere, HeroAtmosphereStyle.rings);
      expect(proofMotion.entrance, HeroEntranceStyle.drop);
      expect(proofMotion.idle, HeroIdleStyle.lean);
      expect(proofMotion.arrival, HeroCardArrival.flip);
    });

    test('a refusal shakes sideways and is over before the lift', () {
      for (final preview in PaywallPreviewId.values) {
        final turn = proofTurnFor(preview, count: 4);
        expect(proofNudgeAt(turn, 0), Offset.zero);
        expect(proofNudgeAt(turn, proofShakeAt), Offset.zero);
        // Just before the lift it is back in its place.
        expect(proofNudgeAt(turn, turn.liftAt - 1e-6).distance, lessThan(0.01));
        for (var s = 0.0; s < turn.liftAt; s += 0.01) {
          final nudge = proofNudgeAt(turn, s);
          expect(nudge.dy, 0);
          expect(nudge.dx.abs(), lessThanOrEqualTo(proofShakeReach));
        }
      }
      expect(proofShakes(refused), isTrue);
      const mid = proofShakeAt + proofShakeSeconds / (proofShakeTurns * 4);
      expect(proofNudgeAt(refused, mid).dx, greaterThan(2));
    });

    test('a plain default has nothing to shake at', () {
      expect(proofShakes(plain), isFalse);
      for (var s = 0.0; s < plain.liftAt; s += 0.01) {
        expect(proofNudgeAt(plain, s), Offset.zero);
      }
    });

    test('the lift jumps and lands, and the tag swells with it', () {
      for (final turn in [refused, plain]) {
        final top = turn.liftAt + proofPopSeconds / 2;
        expect(proofNudgeAt(turn, turn.liftAt), Offset.zero);
        expect(proofNudgeAt(turn, top).dy, closeTo(-proofPopHeight, 1e-9));
        expect(proofNudgeAt(turn, top).dx, 0);
        expect(proofNudgeAt(turn, turn.liftAt + proofPopSeconds), Offset.zero);
        expect(proofNudgeAt(turn, turn.script.seconds), Offset.zero);
        expect(proofTagSwellAt(turn, 0), 1);
        expect(proofTagSwellAt(turn, top), closeTo(1 + proofPopSwell, 1e-9));
        expect(proofTagSwellAt(turn, turn.script.seconds), 1);
      }
    });

    test('each moment is passed once', () {
      expect(proofMomentsBetween(refused, 0, 0.1), isEmpty);
      expect(proofMomentsBetween(refused, 0.4, 0.45), {ProofMoment.refusal});
      expect(proofMomentsBetween(refused, 0.45, 0.5), isEmpty);
      expect(
        proofMomentsBetween(refused, refused.liftAt - 0.01, refused.liftAt),
        {ProofMoment.lift},
      );
      expect(proofMomentsBetween(plain, 0, 1), isEmpty);
      expect(proofMomentsBetween(plain, 0, plain.liftAt), {ProofMoment.lift});
      // A clock that went back passed nothing.
      expect(proofMomentsBetween(refused, 2, 0.5), isEmpty);
    });

    test('only the first pass of an untouched loop is felt', () {
      bool cues(double t, {bool touched = false}) =>
          proofCuesAt(t, entranceEnd: 1, period: 10, touched: touched);
      expect(cues(0.5), isFalse);
      expect(cues(1), isTrue);
      expect(cues(10.9), isTrue);
      expect(cues(11), isFalse);
      expect(cues(5, touched: true), isFalse);
    });

    test('after an intro the mascot has landed on the first frame', () {
      final loop = proofLoopFor(_hosted, followsIntro: true);
      final pose = heroEntrancePose(
        proofMotion.entrance,
        loop.frameAt(0).entrance,
        size: 160,
      );
      expect(pose.opacity, 1);
      expect(pose.dy.abs(), lessThan(160 * 0.12));
      expect(proofLoopFor(_hosted).prelude, 0);
    });
  });
}
