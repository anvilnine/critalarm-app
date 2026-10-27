import 'package:critalarm/features/onboarding/domain/welcome_word_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

WelcomeWordFrame at(double seconds) =>
    welcomeWordFrameAt(seconds, reducedMotion: false);

/// The frame at [fraction] of the loop.
WelcomeWordFrame atFraction(double fraction) =>
    at(fraction * welcomeWordLoopSeconds + welcomeWordLoopSeconds);

void main() {
  group('the loop', () {
    test('is 7 seconds', () {
      expect(welcomeWordLoopSeconds, 7);
    });

    test('block, letters, rings and face repeat every 7 seconds', () {
      for (final s in [3.3, 4.1, 5.0, 6.4]) {
        final a = at(s + welcomeWordLoopSeconds);
        final b = at(s + 2 * welcomeWordLoopSeconds);
        expect(a.blockScale, closeTo(b.blockScale, 1e-9));
        expect(a.face.shift, closeTo(b.face.shift, 1e-9));
        expect(a.face.shout, closeTo(b.face.shout, 1e-9));
        for (var i = 0; i < welcomeWordLetterCount; i++) {
          expect(a.letters[i].offset, closeTo(b.letters[i].offset, 1e-9));
          expect(a.letters[i].turn, closeTo(b.letters[i].turn, 1e-9));
        }
      }
    });

    test('the lines drop once and do not drop again', () {
      final later = at(welcomeWordLoopSeconds + 0.05);
      for (final line in later.lines) {
        expect(line.offset, 0);
        expect(line.opacity, 1);
      }
    });
  });

  group('the lines', () {
    test('start above their place and unseen', () {
      final first = at(0);
      for (final line in first.lines) {
        expect(line.offset, -welcomeWordDropFrom);
        expect(line.opacity, 0);
      }
    });

    test('drop in order, 0.12 s apart', () {
      final frame = at(0.3);
      expect(frame.lines[0].opacity, greaterThan(frame.lines[1].opacity));
      expect(frame.lines[1].opacity, greaterThan(frame.lines[2].opacity));
      expect(frame.lines[0].offset, greaterThan(frame.lines[1].offset));
      expect(frame.lines[1].offset, greaterThan(frame.lines[2].offset));
      // Line 2 at 0.42 s is where line 1 was at 0.3 s.
      expect(
        at(0.42).lines[1].offset,
        closeTo(at(0.3).lines[0].offset, 1e-9),
      );
      expect(
        at(0.54).lines[2].offset,
        closeTo(at(0.3).lines[0].offset, 1e-9),
      );
    });

    test('a line has not started before its stagger is over', () {
      expect(at(0.1).lines[1].opacity, 0);
      expect(at(0.2).lines[2].opacity, 0);
    });

    test('overshoot past the place, then settle in it', () {
      var lowest = 0.0;
      var highest = 0.0;
      for (var s = 0.0; s <= 0.7; s += 0.01) {
        final offset = at(s).lines[0].offset;
        if (offset > highest) highest = offset;
        if (offset < lowest) lowest = offset;
      }
      expect(highest, greaterThan(0));
      expect(at(0.7).lines[0].offset, closeTo(0, 1e-9));
      expect(at(0.82).lines[1].offset, closeTo(0, 1e-9));
      expect(at(0.94).lines[2].offset, closeTo(0, 1e-9));
    });

    test('opacity never leaves 0 to 1 during the overshoot', () {
      for (var s = 0.0; s <= 1.2; s += 0.01) {
        for (final line in at(s).lines) {
          expect(line.opacity, inInclusiveRange(0, 1));
        }
      }
    });
  });

  group('the block', () {
    test('is 0 before 38 percent', () {
      for (final f in [0.0, 0.1, 0.3, 0.38]) {
        expect(atFraction(f).blockScale, closeTo(0, 1e-6));
      }
    });

    test('grows between 38 and 46 percent', () {
      final half = atFraction(0.42).blockScale;
      expect(half, greaterThan(0));
      expect(half, lessThan(1));
    });

    test('is 1 from 46 to 86 percent', () {
      for (final f in [0.46, 0.5, 0.7, 0.86]) {
        expect(atFraction(f).blockScale, closeTo(1, 1e-9));
      }
    });

    test('shrinks to 0 by 94 percent and stays', () {
      final half = atFraction(0.90).blockScale;
      expect(half, greaterThan(0));
      expect(half, lessThan(1));
      expect(atFraction(0.94).blockScale, closeTo(0, 1e-9));
      expect(atFraction(0.99).blockScale, 0);
    });

    test('has landed at 46 percent of the loop', () {
      expect(welcomeWordBlockLandsAt, closeTo(3.22, 1e-9));
    });
  });

  group('the letters', () {
    test('are still outside 48 to 84 percent', () {
      for (var i = 0; i < welcomeWordLetterCount; i++) {
        for (final f in [0.0, 0.2, 0.4, 0.479, 0.841, 0.9, 0.99]) {
          final letter = atFraction(f).letters[i];
          expect(letter.offset, 0, reason: 'letter $i at $f');
          expect(letter.turn, 0, reason: 'letter $i at $f');
        }
      }
    });

    test('shake inside the window', () {
      var moved = false;
      for (var f = 0.49; f < 0.8; f += 0.005) {
        if (atFraction(f).letters[0].turn != 0) moved = true;
      }
      expect(moved, isTrue);
    });

    test('lift 5 and turn back 5 degrees, dip 3 and turn on 5', () {
      var lowestOffset = 0.0;
      var highestOffset = 0.0;
      var leastTurn = 0.0;
      var mostTurn = 0.0;
      for (var f = 0.48; f < 0.84; f += 0.0005) {
        final letter = atFraction(f).letters[0];
        if (letter.offset < lowestOffset) lowestOffset = letter.offset;
        if (letter.offset > highestOffset) highestOffset = letter.offset;
        if (letter.turn < leastTurn) leastTurn = letter.turn;
        if (letter.turn > mostTurn) mostTurn = letter.turn;
      }
      expect(lowestOffset, closeTo(-welcomeWordShakeLift, 1e-6));
      expect(highestOffset, closeTo(welcomeWordShakeDip, 1e-6));
      expect(leastTurn, closeTo(-welcomeWordShakeTurn, 1e-6));
      expect(mostTurn, closeTo(welcomeWordShakeTurn, 1e-6));
    });

    test('the turn averages to zero over a cycle', () {
      for (var i = 0; i < welcomeWordLetterCount; i++) {
        var sum = 0.0;
        var count = 0;
        for (var f = 0.0; f < 1.0; f += 0.0001) {
          sum += atFraction(f).letters[i].turn;
          count++;
        }
        expect(sum / count, closeTo(0, 2e-4), reason: 'letter $i');
      }
    });

    test('each letter starts 0.04 s after the one before', () {
      const gap = welcomeWordLetterStaggerSeconds;
      for (var i = 1; i < welcomeWordLetterCount; i++) {
        for (final s in [3.6, 4.0, 4.7, 5.2]) {
          final first = at(s).letters[0];
          final later = at(s + i * gap).letters[i];
          expect(later.turn, closeTo(first.turn, 1e-9));
          expect(later.offset, closeTo(first.offset, 1e-9));
        }
      }
    });
  });

  group('the face', () {
    test('is out at the start', () {
      final frame = atFraction(0);
      expect(frame.face.shift, welcomeWordFaceOut);
      expect(frame.face.turn, welcomeWordFaceOutTurn);
      expect(frame.face.shout, 0);
    });

    test('is still out at 40 percent', () {
      expect(atFraction(0.40).face.shift, closeTo(welcomeWordFaceOut, 1));
    });

    test('is in at 48 percent, and shouts', () {
      final frame = atFraction(0.48);
      // The curve is solved to a thousandth.
      expect(frame.face.shift, closeTo(welcomeWordFaceIn, 0.2));
      expect(frame.face.turn, closeTo(welcomeWordFaceInTurn, 0.01));
      expect(frame.face.shout, 1);
    });

    test('is out again at 94 percent, calm again', () {
      final frame = atFraction(0.94);
      expect(frame.face.shift, closeTo(welcomeWordFaceOut, 0.2));
      expect(frame.face.turn, closeTo(welcomeWordFaceOutTurn, 0.01));
      expect(frame.face.shout, 0);
    });

    test('shouts while the block is up and not before it grows', () {
      expect(atFraction(0.2).face.shout, 0);
      expect(atFraction(0.6).face.shout, 1);
      expect(atFraction(0.8).face.shout, 1);
      expect(atFraction(0.97).face.shout, 0);
    });
  });

  group('the rings', () {
    test('are unseen while the block is down', () {
      for (final f in [0.0, 0.2, 0.38, 0.44, 0.95, 0.99]) {
        for (final ring in atFraction(f).rings) {
          expect(ring.opacity, 0, reason: 'at $f');
        }
      }
    });

    test('pulse while the block is up', () {
      var seen = 0;
      for (final ring in atFraction(0.6).rings) {
        if (ring.opacity > 0) seen++;
      }
      expect(seen, welcomeWordRingCount);
    });

    test('start 0.45 s apart and grow from 0.9 to 2.2 times their size', () {
      final frame = atFraction(0.6);
      final scales = [for (final ring in frame.rings) ring.scale];
      expect(scales.toSet().length, welcomeWordRingCount);
      for (final scale in scales) {
        expect(scale, inInclusiveRange(0.9, 2.2));
      }
      // Ring 1 is 0.45 s behind ring 0.
      const base = 0.6 * welcomeWordLoopSeconds + welcomeWordLoopSeconds;
      expect(
        at(base + 0.45).rings[1].scale,
        closeTo(at(base).rings[0].scale, 1e-9),
      );
    });

    test('repeat every 1.4 s', () {
      const base = 4.3 + welcomeWordLoopSeconds;
      expect(
        at(base + welcomeWordRingSeconds).rings[0].scale,
        closeTo(at(base).rings[0].scale, 1e-9),
      );
    });

    test('fade as they grow', () {
      const base = 4.5;
      final early = at(base).rings[0];
      final late = at(base + 1.0).rings[0];
      expect(early.opacity, greaterThan(0));
      expect(late.opacity, lessThan(early.opacity + 1e-9));
    });
  });

  group('reduced motion', () {
    test('is the settled picture at every time', () {
      for (final s in [0.0, 0.2, 1.5, 3.5, 5.0, 6.9, 7.0, 40.0]) {
        final frame = welcomeWordFrameAt(s, reducedMotion: true);
        for (final line in frame.lines) {
          expect(line.offset, 0);
          expect(line.opacity, 1);
        }
        expect(frame.blockScale, 1);
        for (final letter in frame.letters) {
          expect(letter.offset, 0);
          expect(letter.turn, 0);
        }
        for (final ring in frame.rings) {
          expect(ring.opacity, 0);
        }
        expect(frame.face.shift, welcomeWordFaceIn);
        expect(frame.face.turn, welcomeWordFaceInTurn);
        expect(frame.face.shout, 1);
      }
    });
  });

  group('shape of the frame', () {
    test('three lines, five letters, three rings', () {
      final frame = at(1);
      expect(frame.lines, hasLength(3));
      expect(frame.letters, hasLength(5));
      expect(frame.rings, hasLength(3));
    });

    test('a negative time is the first frame', () {
      final frame = at(-1);
      expect(frame.lines[0].opacity, 0);
      expect(frame.blockScale, 0);
    });
  });

  group('the type size', () {
    test('is 21.5 percent of the width', () {
      expect(welcomeWordFontSize(320), closeTo(68.8, 1e-9));
      expect(welcomeWordFontSize(360), closeTo(77.4, 1e-9));
      expect(welcomeWordFontSize(390), closeTo(83.85, 1e-9));
    });

    test('is 84 at most', () {
      expect(welcomeWordFontSize(430), 84);
      expect(welcomeWordFontSize(1000), 84);
    });

    test('about 60 for the 280 wide picture on a 320 wide phone', () {
      expect(welcomeWordFontSize(280), closeTo(60.2, 1e-9));
    });
  });
}
