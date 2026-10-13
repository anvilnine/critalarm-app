import 'dart:io';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_outro.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _nothing(BuildContext context, PaywallOutroScope scope) =>
    const SizedBox.shrink();

PaywallOutro _outro({PaywallCue? score, double scoreSeconds = 0}) =>
    PaywallOutro(
      seconds: 3.5,
      uncover: 2.8,
      score: score,
      scoreSeconds: scoreSeconds,
      builder: _nothing,
    );

/// The end states Z uses.
const List<PaywallThanksId> _endStates = [
  PaywallThanksId.stamp,
  PaywallThanksId.limits,
  PaywallThanksId.receiptParty,
  PaywallThanksId.confetti,
];

/// The lengths of the two score files, measured on the m4a files.
const Map<PaywallOutroId, double> _fileSeconds = {
  PaywallOutroId.breakLiftRing: 4.900,
  PaywallOutroId.cloudClimb: 5.065,
};

void main() {
  group('paywallPurchaseCue', () {
    test('an outro with a score plays the score and not the purchase cue', () {
      final outro = _outro(
        score: PaywallCue.scoreCloudClimb,
        scoreSeconds: 5,
      );
      expect(paywallPurchaseCue(playing: outro), PaywallCue.scoreCloudClimb);
    });

    test('an outro with no score leaves the purchase cue', () {
      expect(paywallPurchaseCue(playing: _outro()), PaywallCue.bought);
    });

    test('no outro leaves the purchase cue', () {
      expect(paywallPurchaseCue(playing: null), PaywallCue.bought);
    });

    test('a thanks of none plays no outro, so the purchase cue sounds', () {
      final playing = paywallOutroPlays(
        kind: PaywallThanksKind.purchase,
        isStill: false,
        isOutroBuilt: true,
        isThanksBuilt: false,
      );
      expect(playing, isFalse);
      expect(
        paywallPurchaseCue(
          playing: playing ? paywallOutroBuilders.values.first : null,
        ),
        PaywallCue.bought,
      );
    });
  });

  group('the two built outros', () {
    test('each names its own score and is sound', () {
      expect(breakLiftRing.score, PaywallCue.scoreBreakLiftRing);
      expect(cloudClimb.score, PaywallCue.scoreCloudClimb);
      expect(breakLiftRing.isSound, isTrue);
      expect(cloudClimb.isSound, isTrue);
    });

    test('the length each states is the length of its file', () {
      expect(
        breakLiftRing.scoreSeconds,
        closeTo(_fileSeconds[PaywallOutroId.breakLiftRing]!, 1e-9),
      );
      expect(
        cloudClimb.scoreSeconds,
        closeTo(_fileSeconds[PaywallOutroId.cloudClimb]!, 1e-9),
      );
    });

    test('the score files are on disk', () {
      for (final outro in [breakLiftRing, cloudClimb]) {
        expect(File(outro.score!.asset!).existsSync(), isTrue);
      }
    });

    test('the tail rings past the swap and not for long', () {
      for (final outro in [breakLiftRing, cloudClimb]) {
        expect(outro.scoreSeconds, greaterThan(outro.seconds));
        expect(outro.scoreSeconds - outro.seconds, lessThan(1.2));
      }
    });
  });

  group('isSound with a score', () {
    test('a score must be a cue with a sound', () {
      expect(
        _outro(score: PaywallCue.ratchet, scoreSeconds: 5).isSound,
        isFalse,
      );
      expect(
        _outro(score: PaywallCue.scoreCloudClimb, scoreSeconds: 5).isSound,
        isTrue,
      );
    });

    test('a score states a length that reaches the swap', () {
      expect(_outro(score: PaywallCue.scoreCloudClimb).isSound, isFalse);
      expect(
        _outro(score: PaywallCue.scoreCloudClimb, scoreSeconds: 3).isSound,
        isFalse,
      );
    });

    test('a length with no score is not sound', () {
      expect(_outro(scoreSeconds: 5).isSound, isFalse);
    });
  });

  group('the tail', () {
    test('no heard beat of an end state starts before the score has ended', () {
      for (final entry in paywallOutroBuilders.entries) {
        final outro = entry.value;
        for (final id in _endStates) {
          final thanks = paywallThanksBuilders[id]!;
          for (final lines in [1, 3, 5]) {
            final heard = [
              for (final beat in paywallThanksBeatsAfterOutro(
                thanks.beats(lines),
                outro: outro,
                pickUp: thanks.pickUp,
              ))
                if (beat.isHeard) beat.at,
            ];
            for (final at in heard) {
              expect(
                at,
                greaterThanOrEqualTo(_fileSeconds[entry.key]!),
                reason: '${entry.key.name} then ${id.name}, $lines lines',
              );
            }
          }
        }
      }
    });

    test('a heard beat inside the score is not played', () {
      final outro = _outro(score: PaywallCue.scoreCloudClimb, scoreSeconds: 5);
      const beats = [PaywallThanksBeat(2, PaywallCue.stamp)];
      // Lands at 2.0 - 0.5 + 2.8 = 4.3, inside the 5 s score.
      expect(
        paywallThanksBeatsAfterOutro(beats, outro: outro, pickUp: 0.5),
        isEmpty,
      );
      // Lands at 3.2 - 0.5 + 2.8 = 5.5, after it.
      expect(
        paywallThanksBeatsAfterOutro(
          const [PaywallThanksBeat(3.2, PaywallCue.stamp)],
          outro: outro,
          pickUp: 0.5,
        ),
        hasLength(1),
      );
    });

    test('a haptic beat inside the score still plays', () {
      final outro = _outro(score: PaywallCue.scoreCloudClimb, scoreSeconds: 5);
      final beats = [
        const PaywallThanksBeat.tap(2, HapticPattern.light),
      ];
      expect(
        paywallThanksBeatsAfterOutro(beats, outro: outro, pickUp: 0.5),
        hasLength(1),
      );
    });
  });
}
