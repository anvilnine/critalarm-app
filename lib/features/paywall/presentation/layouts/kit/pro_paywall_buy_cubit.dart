import 'dart:async';

import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

Future<void> _realWait(Duration d) => Future<void>.delayed(d);

/// Buys the Pro pack, through the same shop and the same access object the
/// Pro sheet uses.
///
/// Whether the pack is held is always the relay's answer. The store
/// finishing a purchase only starts the asking, and an answer that says
/// nothing is a reason to ask again, never a failed purchase.
class ProPaywallBuyCubit extends PaywallBuyCubit {
  ProPaywallBuyCubit({
    required this._access,
    required this._shop,
    List<Duration>? confirmWaits,
    Future<void> Function(Duration)? wait,
  }) : _confirmWaits = confirmWaits ?? defaultConfirmWaits,
       _wait = wait ?? _realWait,
       super(PaywallProduct.pro) {
    _stopListening = _access.stream.listen((isHeld) {
      if (isHeld) show(state.copyWith(status: PaywallBuyStatus.done));
    }).cancel;
  }

  /// The waits before each ask after the store finishes. Five asks, which
  /// stays under the relay's limit for one minute.
  static const defaultConfirmWaits = <Duration>[
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
  ];

  final ProPackAccess _access;
  final ProPackShop _shop;
  final List<Duration> _confirmWaits;
  final Future<void> Function(Duration) _wait;
  late final Future<void> Function() _stopListening;

  /// The store's offers behind the options, by option id.
  final Map<String, ProPackOffer> _offers = {};
  bool _afterPurchase = false;

  bool get _isDone => state.status == PaywallBuyStatus.done;

  @override
  Future<void> load() async {
    if (_access.isHeld) {
      return show(state.copyWith(status: PaywallBuyStatus.done));
    }
    final offers = await _shop.readOffers();
    if (isClosed || state.status != PaywallBuyStatus.loading) return;
    _offers
      ..clear()
      ..addAll({for (final offer in offers) offer.handle: offer});
    show(restingState(state, options: proPlanOptions(offers)));
  }

  @override
  Future<void> buy() async {
    final offer = _offers[state.selectedId];
    if (!state.canBuy || offer == null) return;
    began(PaywallBuyAction.purchase);
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    // Written down before the store is asked, so a purchase the app does
    // not live to see confirmed is asked about again on the next launch.
    await _access.purchaseStarted();
    final result = await _shop.buy(offer);
    if (result == ProPackStoreResult.cancelled) {
      await _access.purchaseAbandoned();
    }
    await _afterStore(result, afterPurchase: true);
  }

  @override
  Future<void> restore() async {
    if (!state.canRestore) return;
    began(PaywallBuyAction.restore);
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    await _afterStore(await _shop.restore(), afterPurchase: false);
  }

  @override
  Future<void> checkAgain() async {
    if (state.status != PaywallBuyStatus.checking || !state.isPaused) return;
    await _confirm(afterPurchase: _afterPurchase);
  }

  Future<void> _afterStore(
    ProPackStoreResult result, {
    required bool afterPurchase,
  }) async {
    if (isClosed || _isDone) return;
    show(afterStore(state, storeResultOfProPack(result)));
    if (result == ProPackStoreResult.done) {
      await _confirm(afterPurchase: afterPurchase);
    }
  }

  /// Asks the relay until it says the pack is held, or the tries run out.
  Future<void> _confirm({required bool afterPurchase}) async {
    _afterPurchase = afterPurchase;
    show(state.copyWith(status: PaywallBuyStatus.checking));
    var step = PaywallConfirmStep.paused;
    for (var i = 0; i < _confirmWaits.length; i++) {
      if (_confirmWaits[i] > Duration.zero) await _wait(_confirmWaits[i]);
      if (isClosed || _isDone) return;
      final answer = _access.isHeld
          ? PaywallConfirmAnswer.held
          : confirmAnswerOfProPack(await _access.confirmWithStore());
      if (isClosed) return;
      step = afterConfirm(
        answer,
        afterPurchase: afterPurchase,
        hasTriesLeft: i < _confirmWaits.length - 1,
      );
      if (step != PaywallConfirmStep.askAgain) break;
    }
    // The relay can answer through another door while the last ask is out.
    if (_access.isHeld) step = PaywallConfirmStep.done;
    show(
      afterConfirmStep(
        state,
        step,
        pausedKey: LocaleKeys.paywall_kit_paused,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _stopListening();
    return super.close();
  }
}
