import 'dart:async';

import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sequence_rules.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';

/// Asks the store whether the offer's product can be bought, early, and
/// keeps the answer.
///
/// The check starts with the real alarm step ([start]). It makes the buy
/// model the paywall route makes and loads it, so the one store read is the
/// one the paywall already makes and no request goes to the app's own
/// server. Two readers share the answer: the "It works" screen asks
/// [answerFor] and never waits, and the offer step takes the loaded model
/// with [takeOnSale], which waits only when the store has not answered yet.
///
/// The probe holds one model at a time. Starting for another product, or
/// calling [discard], closes the one it holds.
class OfferSaleProbe {
  OfferSaleProbe({required this.makeBuyModel});

  /// Makes the buy model for a product, through the factory the paywall
  /// route uses.
  final PaywallBuyCubit Function(PaywallProduct product) makeBuyModel;

  PaywallProduct? _product;
  PaywallBuyCubit? _model;

  /// Completes with false when the model's load threw.
  Future<bool>? _loading;
  bool _hasFailed = false;

  /// Starts the check for [product] when none is under way for it.
  void start(PaywallProduct product) {
    if (_product == product && _model != null) return;
    discard();
    final model = _make(product);
    if (model == null) return;
    _product = product;
    _model = model;
    _loading = _load(model);
  }

  /// What the store has said for [product], read at once. Unknown while no
  /// check was started for it or while the store has not answered.
  OfferSaleAnswer answerFor(PaywallProduct product) {
    final model = _model;
    if (_product != product || model == null) return OfferSaleAnswer.unknown;
    if (_hasFailed) return OfferSaleAnswer.notOnSale;
    return _answerOf(model.state.status, timedOut: false);
  }

  /// The buy model for [product] once the store says it is on sale, or null,
  /// with the model closed, when it cannot be sold or the store does not
  /// answer in [wait].
  ///
  /// It takes over the model [start] made and loaded, so an answer that is
  /// already in costs no wait. With no check started it makes the model and
  /// loads it, as a replay does. The probe forgets the model either way: the
  /// caller owns it.
  Future<PaywallBuyCubit?> takeOnSale(
    PaywallProduct product, {
    Duration wait = offerSaleWait,
  }) async {
    PaywallBuyCubit? model;
    Future<bool>? loading;
    if (_product == product && _model != null) {
      model = _model;
      loading = _loading;
      _forget();
    } else {
      discard();
      model = _make(product);
      if (model != null) loading = _load(model);
    }
    if (model == null) return null;
    final canSell = await _waitForSale(model, loading, wait);
    if (canSell) return model;
    unawaited(model.close());
    return null;
  }

  /// Closes the model the probe holds, if any.
  void discard() {
    final model = _model;
    _forget();
    if (model != null) unawaited(model.close());
  }

  void _forget() {
    _product = null;
    _model = null;
    _loading = null;
    _hasFailed = false;
  }

  /// A buy model that cannot be made is a store that cannot sell.
  PaywallBuyCubit? _make(PaywallProduct product) {
    try {
      return makeBuyModel(product);
    } on Object {
      return null;
    }
  }

  Future<bool> _load(PaywallBuyCubit model) async {
    try {
      await model.load();
      return true;
    } on Object {
      if (identical(_model, model)) _hasFailed = true;
      return false;
    }
  }

  static OfferSaleAnswer _answerOf(
    PaywallBuyStatus status, {
    required bool timedOut,
  }) => switch (offerSaleDecision(
    status == PaywallBuyStatus.loading ? null : status,
    timedOut: timedOut,
  )) {
    OfferSaleDecision.goOn => OfferSaleAnswer.onSale,
    OfferSaleDecision.skip => OfferSaleAnswer.notOnSale,
    OfferSaleDecision.keepWaiting => OfferSaleAnswer.unknown,
  };

  /// True once the store says [model] is on sale, false for anything else,
  /// including a failed [loading] and no answer within [wait].
  static Future<bool> _waitForSale(
    PaywallBuyCubit model,
    Future<bool>? loading,
    Duration wait,
  ) async {
    try {
      final answer = Completer<bool>();
      void check({required bool timedOut}) {
        if (answer.isCompleted) return;
        final decision = _answerOf(model.state.status, timedOut: timedOut);
        if (decision == OfferSaleAnswer.unknown) return;
        answer.complete(decision == OfferSaleAnswer.onSale);
      }

      final changes = model.stream.listen((_) => check(timedOut: false));
      final timer = Timer(wait, () => check(timedOut: true));
      if (loading != null) {
        unawaited(
          loading.then((didLoad) {
            if (!didLoad && !answer.isCompleted) answer.complete(false);
            check(timedOut: false);
          }),
        );
      }
      check(timedOut: false);
      final canSell = await answer.future;
      timer.cancel();
      await changes.cancel();
      return canSell;
    } on Object {
      return false;
    }
  }
}
