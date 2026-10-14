import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/store_catalog.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// [StoreCatalog] over RevenueCat's API (never its UI). It finds each
/// product by the offering and package ids in the price book.
final class RevenueCatStoreCatalog implements StoreCatalog {
  RevenueCatStoreCatalog(this._service, this._book);

  final RevenueCatService _service;
  final PriceBook _book;

  /// The packages behind the plans last read, by plan.
  final Map<PriceBookPlan, Package> _packages = {};

  @override
  Future<List<StorePlan>> plansFor(PaywallProduct product) async {
    final plans = [
      for (final plan in PriceBookPlan.values)
        if (plan.product == product) plan,
    ];
    _packages.removeWhere((plan, _) => plan.product == product);
    if (!_service.isConfigured) return const [];
    final Offerings offerings;
    try {
      offerings = await _service.getOfferings();
    } on Object catch (_) {
      return const [];
    }
    final found = <StorePlan>[];
    for (final plan in plans) {
      final entry = _book.priceOf(plan);
      if (entry == null) continue;
      final offering = entry.offeringId == null
          ? offerings.current
          : offerings.all[entry.offeringId];
      final package = _packageIn(offering, entry.packageId);
      if (package == null) continue;
      _packages[plan] = package;
      final store = package.storeProduct;
      found.add(
        StorePlan(
          id: plan,
          product: product,
          kind: switch (plan) {
            PriceBookPlan.hostedYearly => StorePlanKind.yearly,
            PriceBookPlan.hostedMonthly => StorePlanKind.monthly,
            PriceBookPlan.proOnce => StorePlanKind.oneTime,
          },
          priceString: store.priceString,
          price: store.price,
          currency: store.currencyCode,
          pricePerMonthString: store.pricePerMonthString,
        ),
      );
    }
    return found;
  }

  /// The package named [packageId] in [offering], or the offering's only
  /// package when no id is named.
  static Package? _packageIn(Offering? offering, String? packageId) {
    if (offering == null) return null;
    final packages = offering.availablePackages;
    if (packageId == null) return packages.length == 1 ? packages.single : null;
    for (final package in packages) {
      if (package.identifier == packageId) return package;
    }
    return null;
  }

  @override
  Future<StoreOutcome> buy(StorePlan plan) async {
    final package = _packages[plan.id];
    if (package == null) return StoreOutcome.problem;
    try {
      await _service.purchasePackage(package);
      return StoreOutcome.done;
    } on PlatformException catch (error) {
      return PurchasesErrorHelper.getErrorCode(error) ==
              PurchasesErrorCode.purchaseCancelledError
          ? StoreOutcome.cancelled
          : StoreOutcome.problem;
    } on Object catch (_) {
      return StoreOutcome.problem;
    }
  }

  @override
  Future<StoreOutcome> restore() async {
    if (!_service.isConfigured) return StoreOutcome.problem;
    try {
      await _service.restorePurchases();
      return StoreOutcome.done;
    } on Object catch (_) {
      return StoreOutcome.problem;
    }
  }
}
