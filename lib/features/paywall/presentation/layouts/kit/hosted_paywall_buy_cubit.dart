import 'dart:async';

import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> _realWait(Duration d) => Future<void>.delayed(d);

/// Buys Hosted, through the same usecases the shipped paywall uses.
///
/// The store says a purchase went through before the server hears of it,
/// so after the store finishes this reads the plan again a few times.
class HostedPaywallBuyCubit extends PaywallBuyCubit {
  HostedPaywallBuyCubit({
    required this._getOfferings,
    required this._purchasePackage,
    required this._restorePurchases,
    required this._readIsPaid,
    required this._readIsRegisteredPaid,
    required this._refreshRegistration,
    List<Duration>? confirmWaits,
    Future<void> Function(Duration)? wait,
  }) : _confirmWaits = confirmWaits ?? defaultConfirmWaits,
       _wait = wait ?? _realWait,
       super(PaywallProduct.hosted);

  /// The waits before each read of the plan after the store finishes. Five
  /// reads over about 30 seconds, as the shipped paywall does.
  static const defaultConfirmWaits = <Duration>[
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  final GetOfferingsUsecase _getOfferings;
  final PurchasePackageUsecase _purchasePackage;
  final RestorePurchasesUsecase _restorePurchases;

  /// Whether the app treats this account as paid: the server's tier, or
  /// the store's answer while the server catches up.
  final Future<bool> Function() _readIsPaid;

  /// What the server alone says.
  final Future<bool> Function() _readIsRegisteredPaid;
  final Future<void> Function() _refreshRegistration;
  final List<Duration> _confirmWaits;
  final Future<void> Function(Duration) _wait;

  /// The store packages behind the options, by option id.
  final Map<String, Package> _packages = {};
  bool _afterPurchase = false;

  @override
  Future<void> load() async {
    if (await _readIsPaid()) {
      return show(state.copyWith(status: PaywallBuyStatus.done));
    }
    final offering = (await _getOfferings(const NoParams())).fold(
      (offerings) => offerings.current,
      (_) => null,
    );
    final yearly = _packageFor(offering, SubscriptionTier.yearly);
    final monthly = _packageFor(offering, SubscriptionTier.monthly);
    _packages
      ..clear()
      ..addAll({
        PaywallPlanOption.yearlyId: ?yearly,
        PaywallPlanOption.monthlyId: ?monthly,
      });
    show(
      restingState(
        state,
        options: hostedPlanOptions(
          yearly: _quote(yearly),
          monthly: _quote(monthly),
        ),
      ),
    );
  }

  static Package? _packageFor(Offering? offering, SubscriptionTier tier) {
    if (offering == null) return null;
    final named = tier == SubscriptionTier.yearly
        ? offering.annual
        : offering.monthly;
    if (named != null) return named;
    for (final package in offering.availablePackages) {
      if (SubscriptionTier.fromPackage(package) == tier) return package;
    }
    return null;
  }

  static HostedPlanQuote? _quote(Package? package) {
    if (package == null) return null;
    final product = package.storeProduct;
    return HostedPlanQuote(
      priceString: product.priceString,
      price: product.price,
      pricePerMonthString: product.pricePerMonthString,
    );
  }

  @override
  Future<void> buy() async {
    final package = _packages[state.selectedId];
    if (!state.canBuy || package == null) return;
    began(PaywallBuyAction.purchase);
    _pausedKey = _confirmingKey;
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    final result = await _purchasePackage(package);
    await result.fold(
      (_) => _afterStore(PaywallStoreResult.done, afterPurchase: true),
      (failure) => _afterStore(
        storeResultOfPurchaseFailure(
          failure.message,
          cancelledText: LocaleKeys.purchase_errors_purchase_cancelled.tr(),
          pendingText: LocaleKeys.purchase_errors_payment_pending.tr(),
        ),
        afterPurchase: true,
      ),
    );
  }

  @override
  Future<void> restore() async {
    if (!state.canRestore) return;
    began(PaywallBuyAction.restore);
    _pausedKey = _confirmingKey;
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    final result = await _restorePurchases(const NoParams());
    await result.fold(
      (info) async {
        // The store was read. With no Hosted on it there is nothing to
        // wait for.
        final storeHasIt = info.entitlements.active.containsKey(
          SubscriptionTier.proEntitlement,
        );
        if (!storeHasIt && !await _readIsPaid()) {
          return show(
            afterConfirmStep(
              state,
              PaywallConfirmStep.nothingToRestore,
              pausedKey: _pausedKey,
            ),
          );
        }
        await _afterStore(PaywallStoreResult.done, afterPurchase: false);
      },
      (_) => _afterStore(PaywallStoreResult.problem, afterPurchase: false),
    );
  }

  @override
  Future<void> checkAgain() async {
    if (state.status != PaywallBuyStatus.checking || !state.isPaused) return;
    await _confirm(afterPurchase: _afterPurchase);
  }

  static const String _confirmingKey =
      LocaleKeys.paywall_feedback_purchase_completed;

  /// The line a paused check shows. After a payment the store is holding
  /// it stays the pending line, because no payment went through.
  String _pausedKey = _confirmingKey;

  Future<void> _afterStore(
    PaywallStoreResult result, {
    required bool afterPurchase,
  }) async {
    if (isClosed) return;
    if (result == PaywallStoreResult.pending) {
      // Check again reads the plan as it does after any purchase.
      _afterPurchase = afterPurchase;
      _pausedKey = LocaleKeys.purchase_errors_payment_pending;
    }
    show(afterStore(state, result));
    if (result == PaywallStoreResult.done) {
      await _confirm(afterPurchase: afterPurchase);
    }
  }

  Future<void> _confirm({required bool afterPurchase}) async {
    _afterPurchase = afterPurchase;
    show(state.copyWith(status: PaywallBuyStatus.checking));
    for (var i = 0; i < _confirmWaits.length; i++) {
      if (_confirmWaits[i] > Duration.zero) await _wait(_confirmWaits[i]);
      if (isClosed) return;
      await _refresh();
      final serverSaysPaid = await _readIsRegisteredPaid();
      final paid = serverSaysPaid || await _readIsPaid();
      final step = afterConfirm(
        paid ? PaywallConfirmAnswer.held : PaywallConfirmAnswer.unknown,
        afterPurchase: afterPurchase,
        hasTriesLeft: i < _confirmWaits.length - 1,
      );
      if (step == PaywallConfirmStep.askAgain) continue;
      // The store's word is enough to say done. The server still has to
      // hear of it, so keep reading in the background.
      if (paid && !serverSaysPaid) unawaited(_refreshUntilRegistered(i + 1));
      return show(afterConfirmStep(state, step, pausedKey: _pausedKey));
    }
  }

  Future<void> _refreshUntilRegistered(int from) async {
    for (var i = from; i < _confirmWaits.length; i++) {
      await _wait(_confirmWaits[i]);
      await _refresh();
      if (await _readIsRegisteredPaid()) return;
    }
  }

  Future<void> _refresh() async {
    try {
      await _refreshRegistration();
    } on Object catch (_) {
      // No network is a reason to read again later, not an error to show.
    }
  }
}
