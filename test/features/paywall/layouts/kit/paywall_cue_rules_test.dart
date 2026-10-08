import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _beats = [
  PaywallCueBeat(0.2, PaywallCue.pop),
  PaywallCueBeat(0.5, PaywallCue.whoosh),
  PaywallCueBeat(1.1, PaywallCue.snap),
];

/// Every cue a clock plays stepping from zero to [until] in [step]s.
List<PaywallCue> _played({
  double until = 2,
  double step = 0.016,
  bool isStill = false,
  double quietUntil = 0,
  List<PaywallCueBeat> beats = _beats,
}) {
  final played = <PaywallCue>[];
  var before = 0.0;
  while (before < until) {
    final now = before + step;
    played.addAll(
      paywallCuesBetween(
        beats,
        before,
        now,
        isStill: isStill,
        quietUntil: quietUntil,
      ),
    );
    before = now;
  }
  return played;
}

void main() {
  group('a moment on the clock', () {
    test('is reached on the tick that passes it, and on no other', () {
      expect(paywallReached(0.484, 0.5, 0.5), isTrue);
      expect(paywallReached(0.49, 0.506, 0.5), isTrue);
      expect(paywallReached(0.5, 0.516, 0.5), isFalse);
      expect(paywallReached(0, 0.484, 0.5), isFalse);
      // A clock that went back passed nothing.
      expect(paywallReached(0.8, 0.2, 0.5), isFalse);
    });
  });

  group('a timeline of cues', () {
    test('plays each cue once, in order', () {
      expect(_played(), [PaywallCue.pop, PaywallCue.whoosh, PaywallCue.snap]);
    });

    test('plays the same whatever the frame rate', () {
      for (final step in [0.004, 0.008, 0.016, 0.033, 0.1]) {
        expect(_played(step: step), [
          PaywallCue.pop,
          PaywallCue.whoosh,
          PaywallCue.snap,
        ], reason: '$step');
      }
    });

    test('plays a cue on the tick the clock passes its second', () {
      expect(paywallCuesBetween(_beats, 0.19, 0.2), [PaywallCue.pop]);
      expect(paywallCuesBetween(_beats, 0.2, 0.21), isEmpty);
      expect(paywallCuesBetween(_beats, 0.21, 0.49), isEmpty);
    });

    test('plays both, in order, when one long frame passes two', () {
      expect(paywallCuesBetween(_beats, 0.1, 0.6), [
        PaywallCue.pop,
        PaywallCue.whoosh,
      ]);
    });

    test('plays nothing on a rebuild: the clock has not moved', () {
      expect(paywallCuesBetween(_beats, 0.5, 0.5), isEmpty);
      expect(paywallCuesBetween(_beats, 0.2, 0.2), isEmpty);
    });

    test('plays nothing when the clock goes back, then plays again', () {
      expect(paywallCuesBetween(_beats, 1.5, 0), isEmpty);
      expect(paywallCuesBetween(_beats, 0, 0.3), [PaywallCue.pop]);
    });

    test('plays nothing under reduce motion', () {
      expect(_played(isStill: true), isEmpty);
      expect(
        paywallCuesBetween(_beats, 0, 2, isStill: true),
        isEmpty,
      );
    });

    test('after an intro the first moments are left to the intro', () {
      expect(_played(quietUntil: paywallQuietAfterIntro), [
        PaywallCue.whoosh,
        PaywallCue.snap,
      ]);
      expect(_played(quietUntil: 0.8), [PaywallCue.snap]);
      expect(_played(quietUntil: 3), isEmpty);
    });

    test('a moment before the clock starts is never played', () {
      const early = [
        PaywallCueBeat(-0.2, PaywallCue.pop),
        PaywallCueBeat(0, PaywallCue.whoosh),
        PaywallCueBeat(0.3, PaywallCue.snap),
      ];
      expect(_played(beats: early), [PaywallCue.snap]);
    });
  });

  group('the loop by itself', () {
    test('is heard through its first pass and not after', () {
      bool cues(double t, {bool touched = false}) =>
          paywallLoopCues(t, entranceEnd: 1, period: 10, touched: touched);
      expect(cues(0.5), isFalse);
      expect(cues(1), isTrue);
      expect(cues(10.9), isTrue);
      expect(cues(11), isFalse);
      expect(cues(60), isFalse);
      expect(cues(5, touched: true), isFalse);
    });

    test('a change of benefit is heard once, in the first pass only', () {
      bool cues(double began, {double? was = 1, bool touched = false}) =>
          paywallTurnCues(
            began: began,
            was: was,
            entranceEnd: 1,
            period: 10,
            touched: touched,
          );
      // The first turn is the entrance's, not a change.
      expect(cues(1, was: null), isFalse);
      expect(cues(1), isFalse);
      expect(cues(3.5), isTrue);
      // The same turn on the next tick.
      expect(cues(3.5, was: 3.5), isFalse);
      // The second pass, a touch, and a clock that went back.
      expect(cues(11, was: 9), isFalse);
      expect(cues(13.5, was: 11), isFalse);
      expect(cues(3.5, touched: true), isFalse);
      expect(cues(3.5, was: 6), isFalse);
    });

    test('never repeats: a loop left open for a minute is silent', () {
      // Turns of 2.5 seconds, four to a pass.
      var heard = 0;
      double? was;
      for (var t = 0.0; t < 60; t += 0.016) {
        final began = t < 1 ? 1.0 : 1 + ((t - 1) / 2.5).floor() * 2.5;
        if (paywallTurnCues(
          began: began,
          was: was,
          entranceEnd: 1,
          period: 10,
          touched: false,
        )) {
          heard++;
        }
        was = began;
      }
      expect(heard, 3);
    });
  });

  group('leaving a paywall', () {
    test('says so when nothing was bought, whatever the buy state', () {
      for (final status in PaywallBuyStatus.values) {
        if (status == PaywallBuyStatus.done) continue;
        expect(
          paywallSaysClose(status: status, isMuted: false),
          isTrue,
          reason: status.name,
        );
      }
    });

    test('is silent with the product in hand', () {
      expect(
        paywallSaysClose(status: PaywallBuyStatus.done, isMuted: false),
        isFalse,
      );
    });

    test('is silent in a thumbnail', () {
      for (final status in PaywallBuyStatus.values) {
        expect(
          paywallSaysClose(status: status, isMuted: true),
          isFalse,
          reason: status.name,
        );
      }
    });
  });
}
