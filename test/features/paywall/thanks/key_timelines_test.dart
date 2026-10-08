import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/key/key_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/key/key_timeline.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _phones = [
  (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  (Size(375, 667), EdgeInsets.only(top: 20)),
];

/// The cues a version plays, with the second each starts.
List<(double, PaywallCue)> _heard(List<PaywallThanksBeat> beats) => [
  for (final beat in beats)
    if (beat.cue case final cue?) (beat.at, cue),
];

void main() {
  group('KeyTimeline', () {
    test('the key turns on the peak, after it is caught and seated', () {
      expect(KeyTimeline.forged, lessThan(KeyTimeline.caught));
      expect(KeyTimeline.caught, lessThan(KeyTimeline.push));
      expect(KeyTimeline.push, 0.4);
      expect(KeyTimeline.seated, lessThan(KeyTimeline.turn));
      expect(KeyTimeline.turn, 0.6);
      expect(KeyTimeline.turn, lessThan(KeyTimeline.spring));
      expect(KeyTimeline.button, lessThanOrEqualTo(paywallThanksButtonBy));
      expect(KeyTimeline.turned(KeyTimeline.seated), 0);
      expect(KeyTimeline.turned(KeyTimeline.turn + 0.07), closeTo(1, 1e-9));
    });

    test('the second turn and the fall wait for the purchase cue to end', () {
      expect(
        KeyTimeline.secondTurn,
        greaterThanOrEqualTo(paywallBoughtCueSeconds),
      );
      // The turn's sound is over before the lock's starts.
      expect(KeyTimeline.fall - KeyTimeline.secondTurn, greaterThan(0.24));
      expect(KeyTimeline.dropped(KeyTimeline.fall), 0);
      expect(KeyTimeline.firstToken, greaterThan(KeyTimeline.fall));
    });

    test('the first frame is the paywall with the button whole', () {
      expect(KeyTimeline.covered(0), 0);
      expect(KeyTimeline.pressed(0), 1);
      expect(KeyTimeline.forge(0), 0);
      expect(KeyTimeline.thrown(0), 0);
      expect(KeyTimeline.travel(0), 0);
      expect(KeyTimeline.lift(0, lines: 4), 0);
    });

    test('every token lands before the end, whatever the count', () {
      for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
        for (var i = 1; i < lines; i++) {
          expect(
            KeyTimeline.tokenAt(i, lines),
            greaterThan(KeyTimeline.tokenAt(i - 1, lines)),
          );
        }
        expect(
          KeyTimeline.tokenLands(lines - 1, lines) + 0.18,
          lessThan(KeyTimeline.end),
        );
      }
    });

    test('the resting frame is complete: nothing half way or at an angle', () {
      for (final t in [KeyTimeline.end, KeyTimeline.end + 30]) {
        expect(KeyTimeline.covered(t), 1);
        expect(KeyTimeline.pressed(t), 0);
        expect(KeyTimeline.forge(t), closeTo(1, 1e-9));
        expect(KeyTimeline.seat(t), 1);
        // Two quarter turns: the key is upright again.
        expect(KeyTimeline.turned(t), closeTo(2, 1e-9));
        expect(KeyTimeline.sprung(t), closeTo(1, 1e-9));
        expect(KeyTimeline.dropped(t), closeTo(1, 1e-9));
        expect(KeyTimeline.shake(t), 0);
        expect(KeyTimeline.reach(t), 0);
        expect(KeyTimeline.travel(t), 1);
        expect(KeyTimeline.stretch(t), closeTo(1, 1e-9));
        expect(KeyTimeline.headlineIn(t), 1);
        expect(KeyTimeline.disc(t), closeTo(1, 1e-9));
        expect(KeyTimeline.ring(t), 1);
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          expect(KeyTimeline.lift(t, lines: lines), 0);
          for (var i = 0; i < lines; i++) {
            expect(KeyTimeline.lineIn(t, i), 1);
            expect(KeyTimeline.token(t, i, lines), 1);
            expect(KeyTimeline.held(t, i, lines), 1);
          }
        }
      }
      expect(KeyTimeline.face(KeyTimeline.end).to, HeroFace.proud);
    });

    test('the lock, the mascot and the words fit above the button', () {
      for (final (size, padding) in _phones) {
        for (var lines = 0; lines <= paywallThanksMaxLines; lines++) {
          final place = KeyStage.of(
            size: size,
            padding: padding,
            lines: lines,
          );
          final foot = size.height - padding.bottom - paywallThanksButtonRoom;
          final top = place.floor - place.unit * KeyStage.tall;
          expect(top, greaterThanOrEqualTo(padding.top));
          expect(place.body.left, greaterThan(0));
          expect(place.stage.crit.right, lessThan(size.width));
          expect(place.stage.crit.bottom, closeTo(place.floor, 1e-6));
          expect(place.stage.words.top, greaterThan(place.floor));
          expect(place.stage.words.bottom, closeTo(foot, 1e-6));
          // The keyhole is clear of the mascot.
          expect(
            place.keyhole(1).dx + place.unit * 0.2,
            lessThanOrEqualTo(place.stage.crit.left + 0.01),
          );
          expect(place.body.contains(place.keyhole(1)), isTrue);
        }
      }
    });
  });

  group('what is heard after the purchase cue', () {
    test('the key version plays the key and then the lock', () {
      expect(keyThanks.isSound, isTrue);
      expect(_heard(keyBeats(4)), [
        (KeyTimeline.secondTurn, PaywallCue.key),
        (KeyTimeline.fall, PaywallCue.lock),
      ]);
    });

    test('confetti plays its settle as the last piece lies still', () {
      expect(confettiThanks.isSound, isTrue);
      expect(_heard(confettiBeats(4)), [
        (ConfettiTimeline.settled, PaywallCue.settle),
      ]);
      expect(
        ConfettiTimeline.settled,
        greaterThanOrEqualTo(paywallBoughtCueSeconds),
      );
    });

    test('no version plays a cue that may be taken for a ring: each cue '
        'comes once, and they are apart', () {
      for (final beats in [keyBeats(5), confettiBeats(5)]) {
        final heard = _heard(beats);
        for (var i = 1; i < heard.length; i++) {
          expect(heard[i].$1 - heard[i - 1].$1, greaterThanOrEqualTo(0.17));
        }
        final once = heard.where((beat) => !beat.$2.mayRepeat);
        expect(once.map((beat) => beat.$2).toSet(), hasLength(once.length));
      }
    });
  });
}
