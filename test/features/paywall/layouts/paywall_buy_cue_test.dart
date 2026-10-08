import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

const _option = PaywallPlanOption(id: 'a', title: 'A', price: 'A-PRICE');

const _ready = PaywallBuyState(
  product: PaywallProduct.pro,
  status: PaywallBuyStatus.ready,
  options: [_option],
  selectedId: 'a',
);

final PaywallBuyState _atStore = _ready.copyWith(
  status: PaywallBuyStatus.purchasing,
);
final PaywallBuyState _checking = _ready.copyWith(
  status: PaywallBuyStatus.checking,
);
final PaywallBuyState _done = _ready.copyWith(status: PaywallBuyStatus.done);

PaywallCue? _cue(
  PaywallBuyState before,
  PaywallBuyState after, {
  PaywallBuyAction? action = PaywallBuyAction.purchase,
}) => paywallBuyCue(before, after, action: action);

void main() {
  group('what the buy block sounds like', () {
    test('a purchase confirmed is the purchase cue', () {
      expect(_cue(_checking, _done), PaywallCue.bought);
      expect(_cue(_atStore, _done), PaywallCue.bought);
    });

    test('a restore that worked has its own cue', () {
      expect(
        _cue(_checking, _done, action: PaywallBuyAction.restore),
        PaywallCue.restore,
      );
    });

    test('a check asked again remembers what it follows', () {
      final paused = afterConfirmStep(
        _checking,
        PaywallConfirmStep.paused,
        pausedKey: LocaleKeys.paywall_kit_paused,
      );
      expect(_cue(paused, _done), PaywallCue.bought);
      expect(
        _cue(paused, _done, action: PaywallBuyAction.restore),
        PaywallCue.restore,
      );
    });

    test('a product already held when the paywall opens is silent', () {
      const loading = PaywallBuyState(product: PaywallProduct.pro);
      expect(_cue(loading, _done, action: null), isNull);
      expect(_cue(_ready, _done, action: null), isNull);
    });

    test('a problem at the store is the error cue', () {
      final failed = afterStore(_atStore, PaywallStoreResult.problem);
      expect(failed.status, PaywallBuyStatus.failed);
      expect(_cue(_atStore, failed), PaywallCue.error);
    });

    test('backing out is silent', () {
      final rest = afterStore(_atStore, PaywallStoreResult.cancelled);
      expect(_cue(_atStore, rest), isNull);
    });

    test('a payment the store is holding is a refusal', () {
      final held = afterStore(_atStore, PaywallStoreResult.pending);
      expect(_cue(_atStore, held), PaywallCue.refuse);
    });

    test('a restore that found nothing is a refusal', () {
      final nothing = afterConfirmStep(
        _checking,
        PaywallConfirmStep.nothingToRestore,
        pausedKey: LocaleKeys.paywall_kit_paused,
      );
      expect(
        _cue(_checking, nothing, action: PaywallBuyAction.restore),
        PaywallCue.refuse,
      );
    });

    test('a check that paused with nothing known is silent', () {
      final paused = afterConfirmStep(
        _checking,
        PaywallConfirmStep.paused,
        pausedKey: LocaleKeys.paywall_kit_paused,
      );
      expect(_cue(_checking, paused), isNull);
    });

    test('the steps on the way are silent', () {
      expect(_cue(_ready, _atStore), isNull);
      expect(_cue(_atStore, _checking), isNull);
      expect(_cue(_checking, _checking), isNull);
      // Picking a plan, or a message that is still showing.
      final failed = afterStore(_atStore, PaywallStoreResult.problem);
      expect(_cue(failed, failed), isNull);
      expect(_cue(failed, _ready), isNull);
    });
  });
}
