import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/party/party_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/party/party_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _phones = [
  (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  (Size(375, 667), EdgeInsets.only(top: 20)),
];

ThanksSlipPlan _plan(Size size, EdgeInsets padding, int lines) =>
    ThanksSlipPlan.of(
      size: size,
      padding: padding,
      lines: lines,
      foot: PartyTimeline.foot,
    );

void main() {
  group('PartyTimeline', () {
    test('the slip is caught, then the stamp lands on the peak, then the '
        'lines change, then the mascot jumps', () {
      expect(PartyTimeline.fed(PartyTimeline.caught), 1);
      expect(PartyTimeline.caught, lessThanOrEqualTo(PartyTimeline.stampFalls));
      expect(PartyTimeline.stampAt, 0.6);
      expect(PartyTimeline.stampAt, lessThan(PartyTimeline.firstLine));
      expect(PartyTimeline.goOn, lessThanOrEqualTo(paywallThanksButtonBy));
      expect(PartyTimeline.raise, lessThan(PartyTimeline.settled));
      expect(PartyTimeline.settled, lessThan(PartyTimeline.end));
      expect(PartyTimeline.end, inInclusiveRange(3, 3.5));
    });

    test('every line has changed before the mascot jumps', () {
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        for (var i = 1; i < lines; i++) {
          expect(
            PartyTimeline.lineAt(i, lines),
            greaterThan(PartyTimeline.lineAt(i - 1, lines)),
          );
        }
        expect(
          PartyTimeline.lineAt(lines - 1, lines) + PartyTimeline.lineSeconds,
          lessThanOrEqualTo(PartyTimeline.raise),
        );
      }
    });

    test('the beats are haptics under the cue and one settle after it', () {
      expect(partyThanks.isSound, isTrue);
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        final beats = partyBeats(lines);
        final heard = [
          for (final beat in beats)
            if (beat.isHeard) beat,
        ];
        expect(heard.single.cue, PaywallCue.settle);
        expect(heard.single.at, PartyTimeline.settled);
        expect(
          PartyTimeline.settled,
          greaterThanOrEqualTo(paywallBoughtCueSeconds),
        );
        // The stamp is felt on the peak and makes no sound of its own.
        expect(beats.where((b) => b.at == PartyTimeline.stampAt), hasLength(1));
        expect(beats.every((b) => b.cue != PaywallCue.stamp), isTrue);
      }
    });

    test('the first frame is the paywall with the button whole', () {
      expect(PartyTimeline.covered(0), 0);
      expect(PartyTimeline.button(0), 1);
      expect(PartyTimeline.travel(0), 0);
      expect(PartyTimeline.fed(0), 0);
      expect(PartyTimeline.stamp(0).opacity, 0);
      expect(PartyTimeline.headlineIn(0), 0);
      expect(PartyTimeline.burst(0), lessThan(0));
    });

    test('the slip comes up with the old limits on it, whole', () {
      const before = PartyTimeline.firstLine - 0.01;
      for (var i = 0; i < 4; i++) {
        expect(PartyTimeline.lifted(before, i, 4), 0);
        expect(PartyTimeline.struck(before, i, 4), 0);
        expect(PartyTimeline.valueIn(before, i, 4), 0);
        expect(PartyTimeline.count(before, i, 4, from: 50, to: 1000), 50);
      }
    });

    test('a line is struck through before its new value comes in', () {
      final at = PartyTimeline.lineAt(1, 4);
      expect(PartyTimeline.struck(at + 0.06, 1, 4), greaterThan(0));
      expect(PartyTimeline.valueIn(at + 0.06, 1, 4), 0);
      expect(PartyTimeline.struck(at + 0.12, 1, 4), 1);
      var last = 50;
      for (var t = 0.0; t < PartyTimeline.end; t += 0.01) {
        final now = PartyTimeline.count(t, 1, 4, from: 50, to: 1000);
        expect(now, greaterThanOrEqualTo(last));
        last = now;
      }
      expect(last, 1000);
    });

    test('the stamp comes down large and turned and lands square', () {
      const before = PartyTimeline.stampFalls + 0.02;
      expect(PartyTimeline.stamp(before).scale, greaterThan(2));
      expect(PartyTimeline.stamp(before).angle, isNot(0));
      final landed = PartyTimeline.stamp(PartyTimeline.stampAt);
      expect(landed.scale, closeTo(1, 1e-9));
      expect(landed.angle, closeTo(0, 1e-9));
      expect(PartyTimeline.pressed(PartyTimeline.stampAt), 0);
      expect(
        PartyTimeline.pressed(PartyTimeline.stampAt + 0.1),
        greaterThan(0),
      );
    });

    test('the resting frame is complete and nothing is at an angle', () {
      for (final t in [PartyTimeline.end, PartyTimeline.end + 30]) {
        expect(PartyTimeline.covered(t), 1);
        expect(PartyTimeline.button(t), 0);
        expect(PartyTimeline.travel(t), 1);
        expect(PartyTimeline.fed(t), 1);
        expect(PartyTimeline.stretch(t), closeTo(1, 1e-9));
        expect(PartyTimeline.pressed(t), closeTo(0, 1e-9));
        expect(PartyTimeline.disc(t), closeTo(1, 1e-9));
        expect(PartyTimeline.headlineIn(t), 1);
        final stamp = PartyTimeline.stamp(t);
        expect(stamp.opacity, 1);
        expect(stamp.scale, closeTo(1, 1e-9));
        expect(stamp.angle, closeTo(0, 1e-9));
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          expect(PartyTimeline.lift(t, lines: lines), 0);
          for (var i = 0; i < lines; i++) {
            expect(PartyTimeline.lifted(t, i, lines), 1);
            expect(PartyTimeline.struck(t, i, lines), 1);
            expect(PartyTimeline.valueIn(t, i, lines), closeTo(1, 1e-9));
            expect(PartyTimeline.count(t, i, lines, from: 7, to: 90), 90);
          }
        }
      }
      expect(PartyTimeline.face(PartyTimeline.end).to, HeroFace.glad);
    });

    test('the mascot, the slip, the headline and the confetti fit above '
        'the button', () {
      for (final (size, padding) in _phones) {
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          final plan = _plan(size, padding, lines);
          final foot = size.height - padding.bottom - paywallThanksButtonRoom;
          expect(plan.crit.top, greaterThan(padding.top));
          expect(plan.paper.top, lessThan(plan.crit.bottom));
          expect(plan.paper.bottom, lessThan(plan.headline.top));
          expect(
            plan.headline.top + plan.headlineSize * 1.15,
            lessThanOrEqualTo(plan.floor),
          );
          expect(plan.paper.contains(plan.stampCentre), isTrue);
          // The strip the confetti lies in is under the headline's box
          // and over the button's.
          final floor = plan.floor + PartyTimeline.floorDrop;
          expect(floor, greaterThan(plan.headline.bottom));
          expect(floor + ThanksConfetti.floorDepth, lessThan(foot));
        }
      }
    });

    test('the confetti bursts from the stamp and every piece left lies '
        'flat on the floor by the settle, and stays', () {
      for (final (size, padding) in _phones) {
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          final plan = _plan(size, padding, lines);
          final floor = plan.floor + PartyTimeline.floorDrop;
          expect(
            PartyTimeline.stampAt +
                ThanksConfetti.settledBy(size: size, floor: floor),
            lessThanOrEqualTo(PartyTimeline.settled),
            reason: '$size $lines',
          );
          ThanksConfettiPiece? at(int i, double t) => ThanksConfetti.piece(
            i,
            PartyTimeline.burst(t),
            origin: plan.stampCentre,
            size: size,
            floor: floor,
          );
          var flying = 0;
          var lying = 0;
          for (var i = 0; i < ThanksConfetti.pieces; i++) {
            expect(at(i, PartyTimeline.stampAt), isNull);
            if (at(i, PartyTimeline.stampAt + 0.3) != null) flying++;
            // One that settles is down by the settle. The others have
            // faded by the resting frame.
            final piece = at(i, PartyTimeline.end);
            final later = at(i, PartyTimeline.end + 30);
            expect(piece == null, !ThanksConfetti.settles(i));
            if (piece == null) continue;
            lying++;
            final down = at(i, PartyTimeline.settled)!;
            expect(down.at.dx, closeTo(piece.at.dx, 1e-6));
            expect(down.at.dy, closeTo(piece.at.dy, 1e-6));
            expect(piece.angle, 0);
            expect(piece.at.dy, greaterThanOrEqualTo(floor));
            expect(
              piece.at.dy,
              lessThanOrEqualTo(floor + ThanksConfetti.floorDepth),
            );
            expect(later!.at.dx, closeTo(piece.at.dx, 1e-6));
            expect(later.at.dy, closeTo(piece.at.dy, 1e-6));
          }
          expect(flying, ThanksConfetti.pieces);
          expect(lying, greaterThan(8));
        }
      }
    });
  });
}
