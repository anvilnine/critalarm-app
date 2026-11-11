import 'dart:ui';

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_tap_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock the test moves by hand.
class _Clock {
  DateTime now = DateTime(2026, 11, 11, 9);

  void advance(Duration by) => now = now.add(by);
}

void main() {
  late _Clock clock;
  late FaceTapSequencer seq;

  setUp(() {
    clock = _Clock();
    seq = FaceTapSequencer(now: () => clock.now);
  });

  /// Taps once, then waits [gap] before the next tap.
  FaceTapReaction? tapThenWait(
    FaceState rest, {
    Duration gap = const Duration(seconds: 2),
  }) {
    final r = seq.tap(rest);
    clock.advance(gap);
    return r;
  }

  group('FaceTapSequencer', () {
    test('slow taps walk the cycle in order and wrap', () {
      final got = [
        for (var i = 0; i < faceTapCycle.length + 2; i++)
          tapThenWait(FaceState.calm),
      ];
      expect(got, [
        ...faceTapCycle,
        faceTapCycle[0],
        faceTapCycle[1],
      ]);
      expect(got.first, FaceTapReaction.boop);
    });

    test('the fifth quick tap makes Crit dizzy', () {
      const quick = Duration(milliseconds: 300);
      final got = [
        for (var i = 0; i < 5; i++) tapThenWait(FaceState.calm, gap: quick),
      ];
      expect(got.take(4), faceTapCycle.take(4));
      expect(got.last, FaceTapReaction.dizzy);
    });

    test('a gap longer than the streak gap starts the count again', () {
      const quick = Duration(milliseconds: 300);
      for (var i = 0; i < 4; i++) {
        tapThenWait(FaceState.calm, gap: quick);
      }
      expect(seq.streak, 4);
      clock.advance(FaceTapSequencer.streakGap);
      // 300 + 700 ms since the last tap: too slow, so a fresh streak.
      expect(seq.tap(FaceState.calm), isNot(FaceTapReaction.dizzy));
      expect(seq.streak, 1);
    });

    test('a gap of exactly the streak gap still counts as quick', () {
      for (var i = 0; i < 4; i++) {
        tapThenWait(FaceState.calm, gap: FaceTapSequencer.streakGap);
      }
      expect(seq.tap(FaceState.calm), FaceTapReaction.dizzy);
    });

    test('taps while dizzy are ignored, then play resumes from boop', () {
      const quick = Duration(milliseconds: 200);
      for (var i = 0; i < 5; i++) {
        tapThenWait(FaceState.calm, gap: quick);
      }
      // Dizzy began 200 ms ago and runs 2.6 s.
      expect(seq.tap(FaceState.calm), isNull);
      clock.advance(const Duration(milliseconds: 2000));
      expect(seq.tap(FaceState.calm), isNull);
      clock.advance(const Duration(milliseconds: 400));
      // 2.6 s after the dizzy tap: over.
      expect(seq.tap(FaceState.calm), FaceTapReaction.boop);
      expect(seq.streak, 1);
    });

    test('a long rest starts the cycle again from boop', () {
      tapThenWait(FaceState.calm);
      tapThenWait(FaceState.calm, gap: FaceTapSequencer.cycleResetAfter);
      expect(seq.tap(FaceState.calm), FaceTapReaction.boop);
    });

    test('just under the reset time carries on through the cycle', () {
      tapThenWait(FaceState.calm);
      tapThenWait(
        FaceState.calm,
        gap: FaceTapSequencer.cycleResetAfter - const Duration(seconds: 1),
      );
      expect(seq.tap(FaceState.calm), FaceTapReaction.startle);
    });

    test('a sleepy face wakes on a fresh tap, plays on quick taps', () {
      expect(
        tapThenWait(FaceState.sleepy, gap: const Duration(milliseconds: 300)),
        FaceTapReaction.wake,
      );
      expect(seq.tap(FaceState.sleepy), FaceTapReaction.boop);
      clock.advance(const Duration(seconds: 2));
      expect(seq.tap(FaceState.dozing), FaceTapReaction.wake);
    });

    test('a sleepy face can still be made dizzy', () {
      const quick = Duration(milliseconds: 300);
      final got = [
        for (var i = 0; i < 5; i++) tapThenWait(FaceState.sleepy, gap: quick),
      ];
      expect(got.first, FaceTapReaction.wake);
      expect(got.last, FaceTapReaction.dizzy);
    });

    test('a face that says something is wrong only blinks', () {
      const quick = Duration(milliseconds: 200);
      for (final rest in faceTapSeriousFaces) {
        for (var i = 0; i < 6; i++) {
          expect(
            tapThenWait(rest, gap: quick),
            FaceTapReaction.notice,
            reason: '$rest never plays or gets dizzy',
          );
        }
      }
    });

    test('an alarmed or busy face never reacts', () {
      for (final rest in faceTapStillFaces) {
        expect(seq.tap(rest), isNull);
      }
      // And those taps do not count toward a streak.
      expect(seq.tap(FaceState.calm), FaceTapReaction.boop);
      expect(seq.streak, 1);
    });
  });

  group('faceTapFrame', () {
    void expectRest(FaceTapFrame f, String why) {
      expect(f.mix, 0, reason: why);
      expect(f.scaleX, closeTo(1, 1e-9), reason: why);
      expect(f.scaleY, closeTo(1, 1e-9), reason: why);
      expect(f.angle, closeTo(0, 1e-9), reason: why);
      expect(f.lift, closeTo(0, 1e-9), reason: why);
      expect(f.lean, closeTo(0, 1e-9), reason: why);
    }

    test('every reaction starts and ends on the resting frame', () {
      for (final r in FaceTapReaction.values) {
        expectRest(faceTapFrame(r, 0, leanSign: 1), '$r at 0');
        expectRest(faceTapFrame(r, r.seconds, leanSign: 1), '$r at end');
        expectRest(faceTapFrame(r, r.seconds + 1, leanSign: 1), '$r after');
      }
    });

    test('every reaction wears its face fully at some point', () {
      for (final r in FaceTapReaction.values) {
        final times = faceTapFaceTimes(r);
        expect(times.enter, lessThan(times.leaveAt), reason: '$r');
        expect(times.leaveAt, lessThan(r.seconds), reason: '$r');
        final mid = (times.enter + times.leaveAt) / 2;
        expect(faceTapFrame(r, mid).mix, 1, reason: '$r');
      }
    });

    test('the face blend never leaves 0..1 and nothing tips far', () {
      for (final r in FaceTapReaction.values) {
        for (var t = 0.0; t <= r.seconds; t += 1 / 60) {
          final f = faceTapFrame(r, t, leanSign: -1);
          expect(f.mix, inInclusiveRange(0, 1), reason: '$r at $t');
          expect(f.angle.abs(), lessThan(0.1), reason: '$r at $t');
          expect(f.scaleX, inInclusiveRange(0.85, 1.15), reason: '$r at $t');
          expect(f.scaleY, inInclusiveRange(0.85, 1.15), reason: '$r at $t');
          expect(f.lift.abs(), lessThan(0.1), reason: '$r at $t');
        }
      }
    });

    test('the boop squashes first', () {
      final f = faceTapFrame(FaceTapReaction.boop, 0.08);
      expect(f.scaleY, lessThan(1));
      expect(f.scaleX, greaterThan(1));
    });

    test('the startle hops up', () {
      expect(faceTapFrame(FaceTapReaction.startle, 0.14).lift, greaterThan(0));
    });

    test('the peek leans toward the tapped side', () {
      expect(
        faceTapFrame(FaceTapReaction.peek, 0.5, leanSign: -1).lean,
        lessThan(0),
      );
      expect(
        faceTapFrame(FaceTapReaction.peek, 0.5, leanSign: 1).lean,
        greaterThan(0),
      );
    });

    test('still mode changes the face only, never moves', () {
      for (final r in FaceTapReaction.values) {
        var sawFace = false;
        for (var t = 0.0; t <= r.seconds; t += 1 / 60) {
          final f = faceTapFrame(r, t, still: true, leanSign: 1);
          expect(f.mix == 0 || f.mix == 1, isTrue, reason: '$r snaps');
          expect(f.scaleX, 1, reason: '$r at $t');
          expect(f.scaleY, 1, reason: '$r at $t');
          expect(f.angle, 0, reason: '$r at $t');
          expect(f.lift, 0, reason: '$r at $t');
          expect(f.lean, 0, reason: '$r at $t');
          if (f.mix == 1) sawFace = true;
        }
        expect(sawFace, isTrue, reason: '$r shows its face');
        expectRest(faceTapFrame(r, r.seconds, still: true), '$r still end');
      }
    });
  });

  group('faceTapGaze', () {
    const box = Size.square(120);

    test('a tap in the middle looks straight out', () {
      expect(faceTapGaze(const Offset(60, 60), box), Offset.zero);
    });

    test('a tap at a corner looks that way, as far as the reach', () {
      expect(faceTapGaze(Offset.zero, box), const Offset(-9, -9));
      expect(faceTapGaze(const Offset(120, 120), box), const Offset(9, 9));
    });

    test('a tap outside the face is held to the reach', () {
      expect(faceTapGaze(const Offset(500, 60), box), const Offset(9, 0));
    });

    test('an empty box looks straight out', () {
      expect(faceTapGaze(const Offset(5, 5), Size.zero), Offset.zero);
    });
  });
}
