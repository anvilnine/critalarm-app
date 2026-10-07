import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/pro_pack/data/revenuecat_pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// A made-up store product. Pro does not cost this.
const _package = Package(
  'pack',
  PackageType.custom,
  StoreProduct(
    'pro',
    'Pro',
    'Store title',
    1, // l10n-ok: demo data
    'P1',
    'XXX',
  ),
  PresentedOfferingContext(proPackOfferingId, null, null),
);
const _offering = Offering(
  proPackOfferingId,
  'Pro',
  <String, Object>{},
  <Package>[_package],
);
const _offerings = Offerings(<String, Offering>{proPackOfferingId: _offering});

/// A store that answers a purchase with what the test scripted.
class _Service extends RevenueCatService {
  /// What a purchase throws.
  Exception? purchaseError;
  int purchases = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<Offerings> getOfferings() async => _offerings;

  @override
  Future<CustomerInfo> purchasePackage(Package package) async {
    purchases++;
    final error = purchaseError;
    if (error != null) throw error;
    throw StateError('no customer info in this test');
  }
}

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}');

void main() {
  late _Service service;
  late RevenueCatProPackShop shop;

  Future<ProPackStoreResult> buy() async {
    final offers = await shop.readOffers();
    return shop.buy(offers.single);
  }

  setUp(() {
    service = _Service();
    shop = RevenueCatProPackShop(service);
  });

  test('a payment the store is holding is pending, not a problem', () async {
    service.purchaseError = _storeError(PurchasesErrorCode.paymentPendingError);
    expect(await buy(), ProPackStoreResult.pending);
    expect(service.purchases, 1);
  });

  test('backing out is cancelled', () async {
    service.purchaseError = _storeError(
      PurchasesErrorCode.purchaseCancelledError,
    );
    expect(await buy(), ProPackStoreResult.cancelled);
  });

  test('any other store error is a problem', () async {
    service.purchaseError = _storeError(PurchasesErrorCode.storeProblemError);
    expect(await buy(), ProPackStoreResult.problem);
    service.purchaseError = _storeError(PurchasesErrorCode.networkError);
    expect(await buy(), ProPackStoreResult.problem);
  });

  test('an error that is not the store speaking is a problem', () async {
    service.purchaseError = Exception('nothing the store said');
    expect(await buy(), ProPackStoreResult.problem);
  });
}
