import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

PaywallBuyState _state(
  PaywallBuyStatus status, {
  bool isPaused = false,
  String? messageKey,
}) => PaywallBuyState(
  product: PaywallProduct.hosted,
  status: status,
  isPaused: isPaused,
  messageKey: messageKey,
);

void main() {
  group('paywallThanksKindFor', () {
    final done = _state(PaywallBuyStatus.done);

    test('a confirmed purchase starts the show', () {
      expect(
        paywallThanksKindFor(
          _state(PaywallBuyStatus.checking),
          done,
          action: PaywallBuyAction.purchase,
        ),
        PaywallThanksKind.purchase,
      );
      expect(
        paywallThanksKindFor(
          _state(PaywallBuyStatus.purchasing),
          done,
          action: PaywallBuyAction.purchase,
        ),
        PaywallThanksKind.purchase,
      );
    });

    test('a held payment that is confirmed later starts it too', () {
      expect(
        paywallThanksKindFor(
          _state(PaywallBuyStatus.checking, isPaused: true),
          done,
          action: PaywallBuyAction.purchase,
        ),
        PaywallThanksKind.purchase,
      );
    });

    test('a restore that worked gets the quiet kind', () {
      expect(
        paywallThanksKindFor(
          _state(PaywallBuyStatus.checking),
          done,
          action: PaywallBuyAction.restore,
        ),
        PaywallThanksKind.restore,
      );
    });

    test('a product held with no trip to the store gets no show', () {
      for (final before in [
        PaywallBuyStatus.loading,
        PaywallBuyStatus.ready,
        PaywallBuyStatus.failed,
        PaywallBuyStatus.notOnSale,
      ]) {
        expect(
          paywallThanksKindFor(_state(before), done, action: null),
          PaywallThanksKind.owned,
        );
      }
    });

    test('nothing but a held product starts anything', () {
      final atStore = _state(PaywallBuyStatus.purchasing);
      final ends = [
        // The buyer backed out.
        _state(PaywallBuyStatus.ready),
        // The store reported a problem.
        _state(
          PaywallBuyStatus.failed,
          messageKey: LocaleKeys.paywall_kit_failed,
        ),
        // A restore found nothing.
        _state(
          PaywallBuyStatus.ready,
          messageKey: LocaleKeys.paywall_kit_nothing_to_restore,
        ),
        // The store is holding the payment.
        _state(
          PaywallBuyStatus.checking,
          isPaused: true,
          messageKey: LocaleKeys.purchase_errors_payment_pending,
        ),
        // Still confirming.
        _state(PaywallBuyStatus.checking),
      ];
      for (final after in ends) {
        for (final action in PaywallBuyAction.values) {
          expect(
            paywallThanksKindFor(atStore, after, action: action),
            isNull,
            reason: '$after',
          );
        }
      }
    });

    test('it starts once: a state that was already held starts nothing', () {
      expect(
        paywallThanksKindFor(done, done, action: PaywallBuyAction.purchase),
        isNull,
      );
    });
  });

  group('beats', () {
    const beats = [
      PaywallThanksBeat.tap(0.4, HapticPattern.tick),
      PaywallThanksBeat.tap(0.8, HapticPattern.medium),
      PaywallThanksBeat(2.3, PaywallCue.pop),
    ];

    test('each plays on the tick the clock passes it, once', () {
      expect(paywallThanksBeatsBetween(beats, 0, 0.39), isEmpty);
      expect(paywallThanksBeatsBetween(beats, 0.39, 0.41), [beats[0]]);
      expect(paywallThanksBeatsBetween(beats, 0.41, 0.6), isEmpty);
    });

    test('a tap that skips to the end plays none of what it skipped', () {
      // The host moves "heard" to the second it skips to.
      expect(paywallThanksBeatsBetween(beats, 2.4, 2.5), isEmpty);
    });

    test('a sound under the purchase cue is not sound', () {
      expect(paywallThanksBeatsAreSound(beats, seconds: 2.4), isTrue);
      expect(
        paywallThanksBeatsAreSound(const [
          PaywallThanksBeat(1, PaywallCue.pop),
        ], seconds: 2.4),
        isFalse,
      );
      // A cue with no sound is a haptic, and may come any time.
      expect(
        paywallThanksBeatsAreSound(const [
          PaywallThanksBeat(1, PaywallCue.ratchet),
        ], seconds: 2.4),
        isTrue,
      );
    });

    test('out of order, or after the end, is not sound', () {
      expect(
        paywallThanksBeatsAreSound(const [
          PaywallThanksBeat.tap(1, HapticPattern.tick),
          PaywallThanksBeat.tap(0.5, HapticPattern.tick),
        ], seconds: 2),
        isFalse,
      );
      expect(
        paywallThanksBeatsAreSound(const [
          PaywallThanksBeat.tap(3, HapticPattern.tick),
        ], seconds: 2),
        isFalse,
      );
    });
  });

  test('a tap skips to the resting frame and changes nothing after', () {
    expect(paywallThanksSkip(2.4, 0.3), 2.4);
    expect(paywallThanksSkip(2.4, 2.4), 2.4);
    expect(paywallThanksSkip(2.4, 5), 5);
  });

  group('registry', () {
    test('none is always built and has no line', () {
      expect(paywallThanksIsBuilt(PaywallThanksId.none), isTrue);
      expect(paywallThanksTakesOver(PaywallThanksId.none), isFalse);
      expect(paywallThanksBuilders, isNot(contains(PaywallThanksId.none)));
    });

    test('every other id is built', () {
      for (final thanks in PaywallThanksId.values) {
        expect(paywallThanksIsBuilt(thanks), isTrue, reason: thanks.key);
      }
    });

    test('every version is sound: the button is on in time and no beat '
        'sounds under the purchase cue', () {
      for (final entry in paywallThanksBuilders.entries) {
        expect(entry.value.isSound, isTrue, reason: entry.key.key);
        expect(
          entry.value.buttonAt,
          lessThanOrEqualTo(paywallThanksButtonBy),
          reason: entry.key.key,
        );
      }
    });

    test('no beat is an alarm: single short haptics, never a run closer '
        'than a tenth of a second', () {
      for (final entry in paywallThanksBuilders.entries) {
        for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
          final beats = entry.value.beats(lines);
          for (var i = 1; i < beats.length; i++) {
            expect(
              beats[i].at - beats[i - 1].at,
              greaterThan(0.1),
              reason: '${entry.key.key} with $lines lines',
            );
          }
          for (final beat in beats) {
            expect(beat.haptic.steps.length, lessThanOrEqualTo(1));
          }
        }
      }
    });
  });
}
