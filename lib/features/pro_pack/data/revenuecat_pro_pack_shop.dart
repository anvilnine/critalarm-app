import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// The identifier of the RevenueCat offering that holds Pro. What is inside
/// it is set in the store dashboards and read as it comes.
const proPackOfferingId = 'pro';

/// [ProPackShop] over RevenueCat. It reads one offering by id and shows the
/// store's own title and price strings for each package in it.
final class RevenueCatProPackShop implements ProPackShop {
  RevenueCatProPackShop(this._service);

  final RevenueCatService _service;

  /// The packages behind the offers last read, by their handle.
  final Map<String, Package> _packages = {};

  @override
  Future<List<ProPackOffer>> readOffers() async {
    _packages.clear();
    if (!_service.isConfigured) return const [];
    try {
      final offerings = await _service.getOfferings();
      final offering = offerings.all[proPackOfferingId];
      if (offering == null) return const [];
      final offers = <ProPackOffer>[];
      for (final package in offering.availablePackages) {
        _packages[package.identifier] = package;
        offers.add(
          ProPackOffer(
            handle: package.identifier,
            title: package.storeProduct.title,
            price: package.storeProduct.priceString,
          ),
        );
      }
      return offers;
    } on Object catch (_) {
      // A store that cannot be asked offers nothing to tap.
      _packages.clear();
      return const [];
    }
  }

  @override
  Future<ProPackStoreResult> buy(ProPackOffer offer) async {
    final package = _packages[offer.handle];
    if (package == null) return ProPackStoreResult.problem;
    try {
      await _service.purchasePackage(package);
      return ProPackStoreResult.done;
    } on PlatformException catch (error) {
      return PurchasesErrorHelper.getErrorCode(error) ==
              PurchasesErrorCode.purchaseCancelledError
          ? ProPackStoreResult.cancelled
          : ProPackStoreResult.problem;
    } on Object catch (_) {
      return ProPackStoreResult.problem;
    }
  }

  @override
  Future<ProPackStoreResult> restore() async {
    if (!_service.isConfigured) return ProPackStoreResult.problem;
    try {
      await _service.restorePurchases();
      return ProPackStoreResult.done;
    } on Object catch (_) {
      return ProPackStoreResult.problem;
    }
  }
}
