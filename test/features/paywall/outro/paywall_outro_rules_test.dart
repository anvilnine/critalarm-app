import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _nothing(BuildContext context, PaywallOutroScope scope) =>
    const SizedBox.shrink();

PaywallOutro _outro({
  double seconds = 3.5,
  double uncover = 2.8,
  List<PaywallThanksBeat> beats = const [],
}) => PaywallOutro(
  seconds: seconds,
  uncover: uncover,
  beats: beats,
  builder: _nothing,
);

void main() {
  group('paywallThanksSecondAfterOutro', () {
    test('the end state reads its pick up second until it is uncovered', () {
      final outro = _outro();
      for (final t in [0.0, 1.0, 2.79]) {
        expect(
          paywallThanksSecondAfterOutro(t, outro: outro, pickUp: 0.5),
          0.5,
        );
      }
    });

    test('from the uncover it runs at the host pace from the pick up', () {
      final outro = _outro();
      expect(
        paywallThanksSecondAfterOutro(2.8, outro: outro, pickUp: 0.5),
        0.5,
      );
      expect(
        paywallThanksSecondAfterOutro(3.5, outro: outro, pickUp: 0.5),
        closeTo(1.2, 1e-9),
      );
      expect(
        paywallThanksSecondAfterOutro(5, outro: outro, pickUp: 0.3),
        closeTo(2.5, 1e-9),
      );
    });

    test('it never goes back as the host clock goes on', () {
      final outro = _outro();
      var last = -1.0;
      for (var t = 0.0; t < 8; t += 1 / 60) {
        final now = paywallThanksSecondAfterOutro(t, outro: outro, pickUp: 0.5);
        expect(now, greaterThanOrEqualTo(last));
        last = now;
      }
    });
  });

  group('the swap', () {
    test('the end state draws its mascot from its second at the swap', () {
      final outro = _outro();
      expect(
        paywallThanksMascotFrom(outro: outro, pickUp: 0.5),
        closeTo(1.2, 1e-9),
      );
      // The end state's clock reads that second when the outro is taken away.
      expect(
        paywallThanksSecondAfterOutro(outro.seconds, outro: outro, pickUp: 0.5),
        paywallThanksMascotFrom(outro: outro, pickUp: 0.5),
      );
    });

    test('a tap lands after the swap, with the end state at its rest', () {
      final outro = _outro();
      final rest = paywallThanksRestAfterOutro(
        outro: outro,
        pickUp: 0.5,
        thanksSeconds: 2.4,
      );
      expect(rest, closeTo(4.7, 1e-9));
      expect(
        paywallThanksSecondAfterOutro(rest, outro: outro, pickUp: 0.5),
        closeTo(2.4, 1e-9),
      );
      // An end state that is too short to finish after the swap still rests
      // with the outro gone.
      expect(
        paywallThanksRestAfterOutro(
          outro: outro,
          pickUp: 0.5,
          thanksSeconds: 1,
        ),
        outro.seconds,
      );
    });
  });

  group('paywallOutroPlays', () {
    bool plays({
      PaywallThanksKind? kind = PaywallThanksKind.purchase,
      bool isStill = false,
      bool isOutroBuilt = true,
      bool isThanksBuilt = true,
    }) => paywallOutroPlays(
      kind: kind,
      isStill: isStill,
      isOutroBuilt: isOutroBuilt,
      isThanksBuilt: isThanksBuilt,
    );

    test('a confirmed purchase plays it', () => expect(plays(), isTrue));

    test('a restore, a product already held and no step play none', () {
      expect(plays(kind: PaywallThanksKind.restore), isFalse);
      expect(plays(kind: PaywallThanksKind.owned), isFalse);
      expect(plays(kind: null), isFalse);
    });

    test('reduce motion and a still play none', () {
      expect(plays(isStill: true), isFalse);
    });

    test('an outro or a thanks this build cannot play plays none', () {
      expect(plays(isOutroBuilt: false), isFalse);
      expect(plays(isThanksBuilt: false), isFalse);
    });

    test('with none set the show is as long as it was', () {
      // No outro built means none plays, so the host reads the version's
      // own length and cover, whatever the kind.
      for (final thanks in paywallThanksBuilders.values) {
        for (final kind in [...PaywallThanksKind.values, null]) {
          expect(
            paywallOutroPlays(
              kind: kind,
              isStill: false,
              isOutroBuilt: paywallOutroBuilders[PaywallOutroId.none] != null,
              isThanksBuilt: thanks.mascotAt != null,
            ),
            isFalse,
          );
        }
        expect(paywallThanksSkip(thanks.seconds, 0), thanks.seconds);
      }
    });
  });

  group('paywallOutroPatch', () {
    test('covers the mascot with a little to spare, and is round', () {
      const mascot = Rect.fromLTWH(100, 200, 160, 160);
      final patch = paywallOutroPatch(mascot);
      expect(patch.outerRect.center, mascot.center);
      expect(patch.outerRect.width, closeTo(160 * 1.06, 1e-9));
      expect(patch.outerRect.contains(mascot.topLeft), isTrue);
      expect(patch.outerRect.contains(mascot.bottomRight), isTrue);
      expect(patch.tlRadiusX, greaterThan(0));
    });

    test('is read 7 points left of the mascot at its mid height', () {
      const mascot = Rect.fromLTWH(100, 200, 160, 160);
      expect(paywallOutroSamplePoint(mascot), const Offset(93, 280));
      // A mascot at the left edge reads inside the screen.
      expect(
        paywallOutroSamplePoint(const Rect.fromLTWH(2, 50, 100, 100)).dx,
        greaterThanOrEqualTo(1),
      );
    });
  });

  group('PaywallOutro.isSound', () {
    test('times in order and haptic beats are sound', () {
      expect(
        _outro(
          beats: const [
            PaywallThanksBeat.tap(0.36, HapticPattern.light),
            PaywallThanksBeat.tap(1.15, HapticPattern.medium),
          ],
        ).isSound,
        isTrue,
      );
    });

    test('the uncover must come before the swap', () {
      expect(_outro(uncover: 3.5).isSound, isFalse);
      expect(_outro(uncover: 4).isSound, isFalse);
      expect(_outro(uncover: 0).isSound, isFalse);
    });

    test('beats out of order, or past the swap, are not sound', () {
      expect(
        _outro(
          beats: const [
            PaywallThanksBeat.tap(1.2, HapticPattern.light),
            PaywallThanksBeat.tap(1.1, HapticPattern.light),
          ],
        ).isSound,
        isFalse,
      );
      expect(
        _outro(
          beats: const [PaywallThanksBeat.tap(3.6, HapticPattern.light)],
        ).isSound,
        isFalse,
      );
    });

    test('a beat that is heard is not sound', () {
      expect(
        _outro(
          beats: const [PaywallThanksBeat(2.5, PaywallCue.settle)],
        ).isSound,
        isFalse,
      );
    });

    test('every outro that is built is sound', () {
      for (final outro in paywallOutroBuilders.values) {
        expect(outro.isSound, isTrue);
      }
    });
  });

  group('paywallThanksBeatsAfterOutro', () {
    test('moves a beat later by what the outro took, and drops past ones', () {
      final outro = _outro(); // uncover 2.8
      final beats = paywallThanksBeatsAfterOutro(
        const [
          PaywallThanksBeat.tap(0.2, HapticPattern.light),
          PaywallThanksBeat.tap(0.9, HapticPattern.medium),
          PaywallThanksBeat.tap(1.4, HapticPattern.tick),
        ],
        outro: outro,
        pickUp: 0.5,
      );
      expect(beats.map((b) => b.at), [
        closeTo(3.2, 1e-9),
        closeTo(3.7, 1e-9),
      ]);
      expect(beats.map((b) => b.haptic), [
        HapticPattern.medium,
        HapticPattern.tick,
      ]);
    });

    test('a beat that is heard stays out of the purchase cue', () {
      final outro = _outro(seconds: 1.4, uncover: 1);
      final beats = paywallThanksBeatsAfterOutro(
        const [PaywallThanksBeat(1.6, PaywallCue.settle)],
        outro: outro,
        pickUp: 0.5,
      );
      // 1.6 - 0.5 + 1.0 = 2.1, inside the cue.
      expect(beats, isEmpty);
      final later = paywallThanksBeatsAfterOutro(
        const [PaywallThanksBeat(2, PaywallCue.settle)],
        outro: outro,
        pickUp: 0.5,
      );
      expect(later.single.at, closeTo(2.5, 1e-9));
      expect(later.single.cue, PaywallCue.settle);
    });
  });
}
