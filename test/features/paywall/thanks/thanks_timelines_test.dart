import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/features/paywall/presentation/thanks/unlock/unlock_timeline.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(390, 844);
const _origin = Offset(195, 700);
const _floor = 320.0;

void main() {
  group('ConfettiTimeline', () {
    test('the beats come in order, timed to the purchase cue', () {
      const t = ConfettiTimeline.burst;
      expect(t, 0);
      expect(ConfettiTimeline.crouch, lessThan(ConfettiTimeline.leap));
      // The jump starts on the swell and tops out on its peak.
      expect(ConfettiTimeline.leap, 0.4);
      expect(ConfettiTimeline.apex, closeTo(0.6, 0.03));
      expect(ConfettiTimeline.land, lessThan(ConfettiTimeline.firstCheck));
      expect(ConfettiTimeline.settled, lessThan(ConfettiTimeline.end));
      expect(ConfettiTimeline.goOn, lessThanOrEqualTo(paywallThanksButtonBy));
    });

    test('every line is checked inside the cue, whatever the count', () {
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        final last = ConfettiTimeline.checkAt(lines - 1, lines);
        expect(last + 0.22, lessThan(paywallBoughtCueSeconds));
        expect(
          ConfettiTimeline.check(ConfettiTimeline.end, lines - 1, lines),
          1,
        );
      }
    });

    test('the first frame is the paywall with the button whole', () {
      expect(ConfettiTimeline.covered(0), 0);
      expect(ConfettiTimeline.button(0), 1);
      expect(ConfettiTimeline.travel(0), 0);
      expect(ConfettiTimeline.lift(0, lines: 4), 0);
      expect(ConfettiTimeline.crown(0), 0);
      for (var i = 0; i < ConfettiTimeline.pieces; i++) {
        expect(
          ConfettiTimeline.piece(
            i,
            0,
            origin: _origin,
            size: _size,
            floor: _floor,
          ),
          isNull,
        );
      }
    });

    test('the mascot is on the stage before it jumps, and is highest at '
        'the apex', () {
      expect(ConfettiTimeline.travel(ConfettiTimeline.leap), 1);
      expect(ConfettiTimeline.covered(ConfettiTimeline.cover), 1);
      final top = ConfettiTimeline.lift(ConfettiTimeline.apex, lines: 4);
      expect(top, greaterThan(0.5));
      for (var t = 0.0; t < ConfettiTimeline.end; t += 0.01) {
        expect(ConfettiTimeline.lift(t, lines: 4), lessThanOrEqualTo(top));
      }
    });

    test('the resting frame is complete: nothing half way or at an angle', () {
      for (final t in [ConfettiTimeline.end, ConfettiTimeline.end + 30]) {
        expect(ConfettiTimeline.covered(t), 1);
        expect(ConfettiTimeline.button(t), 0);
        expect(ConfettiTimeline.travel(t), 1);
        expect(ConfettiTimeline.lift(t, lines: 4), 0);
        expect(ConfettiTimeline.stretch(t), closeTo(1, 1e-9));
        expect(ConfettiTimeline.lean(t), closeTo(0, 1e-9));
        expect(ConfettiTimeline.crown(t), 1);
        expect(ConfettiTimeline.disc(t), closeTo(1, 1e-9));
        expect(ConfettiTimeline.headlineIn(t), 1);
        for (var i = 0; i < 5; i++) {
          expect(ConfettiTimeline.lineIn(t, i), 1);
          expect(ConfettiTimeline.check(t, i, 5), 1);
        }
      }
      expect(ConfettiTimeline.face(ConfettiTimeline.end).to, HeroFace.glad);
    });

    test('at rest every piece left lies flat on the floor, and stays', () {
      var lying = 0;
      for (var i = 0; i < ConfettiTimeline.pieces; i++) {
        final piece = ConfettiTimeline.piece(
          i,
          ConfettiTimeline.settled,
          origin: _origin,
          size: _size,
          floor: _floor,
        );
        final later = ConfettiTimeline.piece(
          i,
          ConfettiTimeline.end + 20,
          origin: _origin,
          size: _size,
          floor: _floor,
        );
        expect(piece == null, !ConfettiTimeline.settles(i));
        if (piece == null) continue;
        lying++;
        expect(piece.angle, 0);
        expect(piece.alpha, 1);
        expect(piece.at.dy, greaterThanOrEqualTo(_floor));
        expect(
          piece.at.dy,
          lessThanOrEqualTo(_floor + ConfettiTimeline.floorDepth),
        );
        expect(later!.at.dx, closeTo(piece.at.dx, 1e-6));
        expect(later.at.dy, closeTo(piece.at.dy, 1e-6));
      }
      expect(lying, greaterThan(8));
    });
  });

  group('UnlockTimeline', () {
    test('the first padlock opens on the swell and they open in order', () {
      expect(UnlockTimeline.firstOpen, 0.4);
      for (var count = 1; count <= paywallThanksMaxLines; count++) {
        for (var i = 1; i < count; i++) {
          expect(
            UnlockTimeline.openAt(i, count),
            greaterThan(UnlockTimeline.openAt(i - 1, count)),
          );
        }
        // The mascot jumps after the last one, and lands before the end.
        expect(
          UnlockTimeline.glad(count),
          greaterThan(
            UnlockTimeline.openAt(count - 1, count) +
                UnlockTimeline.openSeconds,
          ),
        );
        expect(
          UnlockTimeline.landed(count) + 0.3,
          lessThan(UnlockTimeline.end),
        );
      }
    });

    test('the first frame is the paywall, and the lines come in shut', () {
      expect(UnlockTimeline.covered(0), 0);
      expect(UnlockTimeline.travel(0), 0);
      expect(UnlockTimeline.lineIn(0, 0), 0);
      const before = UnlockTimeline.firstOpen - 0.01;
      for (var i = 0; i < 4; i++) {
        expect(UnlockTimeline.lineIn(before, i), 1);
        expect(UnlockTimeline.open(before, i, 4), 0);
      }
      expect(UnlockTimeline.headlineIn(before, count: 4), 0);
    });

    test('a padlock shakes only while it gives', () {
      expect(UnlockTimeline.shake(0.3, 0, 4), 0);
      expect(UnlockTimeline.shake(0.44, 0, 4), isNot(0));
      expect(UnlockTimeline.shake(1, 0, 4), 0);
    });

    test('the resting frame is complete for every count', () {
      for (var count = 1; count <= paywallThanksMaxLines; count++) {
        for (final t in [UnlockTimeline.end, UnlockTimeline.end + 30]) {
          expect(UnlockTimeline.covered(t), 1);
          expect(UnlockTimeline.travel(t), 1);
          expect(UnlockTimeline.lift(t, count: count), 0);
          expect(UnlockTimeline.stretch(t, count: count), closeTo(1, 1e-9));
          expect(UnlockTimeline.headlineIn(t, count: count), 1);
          expect(UnlockTimeline.disc(t, count: count), closeTo(1, 1e-9));
          expect(UnlockTimeline.ring(t, count: count), 1);
          for (var i = 0; i < count; i++) {
            expect(UnlockTimeline.lineIn(t, i), 1);
            expect(UnlockTimeline.open(t, i, count), 1);
            expect(UnlockTimeline.shake(t, i, count), 0);
          }
        }
      }
      expect(
        UnlockTimeline.face(UnlockTimeline.end, count: 4).to,
        HeroFace.proud,
      );
    });
  });

  group('ThanksStage', () {
    test('the mascot and the words fit above the button on both phones', () {
      for (final (size, padding) in const [
        (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
        (Size(375, 667), EdgeInsets.only(top: 20)),
      ]) {
        for (var lines = 0; lines <= paywallThanksMaxLines; lines++) {
          final stage = ThanksStage.of(
            size: size,
            padding: padding,
            lines: lines,
          );
          final foot = size.height - padding.bottom - paywallThanksButtonRoom;
          expect(stage.crit.top, greaterThan(padding.top));
          expect(stage.words.top, greaterThan(stage.floor));
          expect(stage.words.bottom, foot);
          expect(stage.crit.center.dx, size.width / 2);
        }
      }
    });
  });

  test('the idle face is the resting one at rest and changes for a moment', () {
    expect(thanksIdleFace(0).to, HeroFace.glad);
    expect(thanksIdleFace(1).to, HeroFace.glad);
    expect(thanksIdleFace(4).to, HeroFace.winking);
    expect(thanksIdleFace(5.5).to, HeroFace.glad);
  });
}
