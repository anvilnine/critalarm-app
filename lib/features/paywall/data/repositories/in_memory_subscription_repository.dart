import 'dart:async';

import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// In-memory implementation of [SubscriptionRepository] for testing and
/// offline runs.
class InMemorySubscriptionRepository implements SubscriptionRepository {
  InMemorySubscriptionRepository({
    this.isPro = false,
    this.offerings,
    this.customerInfo,
  });

  bool isPro;
  final StoreOfferings? offerings;
  StoreCustomer? customerInfo;
  final _customerInfoController = StreamController<StoreCustomer>.broadcast();

  /// What a purchase or a restore leaves the account holding: Cloud, with
  /// nothing to renew or expire.
  static const _hosted = StoreEntitlement(
    id: SubscriptionTier.proEntitlement,
    isActive: true,
    willRenew: true,
    productId: 'lifetime',
  );

  @override
  Stream<StoreCustomer> get customerInfoStream =>
      _customerInfoController.stream;

  @override
  Future<AppResult<bool>> isProActive() async => Success(isPro);

  @override
  Future<AppResult<StoreCustomer>> getCustomerInfo() async =>
      Success(customerInfo ?? const StoreCustomer());

  @override
  Future<AppResult<StoreOfferings>> getOfferings() async =>
      Success(offerings ?? const StoreOfferings());

  @override
  Future<AppResult<StoreCustomer>> purchasePackage(
    StoreCatalogEntry package,
  ) async {
    isPro = true;
    const info = StoreCustomer(
      entitlements: StoreEntitlements(
        all: {SubscriptionTier.proEntitlement: _hosted},
        active: {SubscriptionTier.proEntitlement: _hosted},
      ),
    );
    customerInfo = info;
    _customerInfoController.add(info);
    return const Success(info);
  }

  @override
  Future<AppResult<StoreCustomer>> restorePurchases() async {
    const entry = StoreCatalogEntry(
      offeringId: 'default',
      id: 'lifetime',
      productId: 'lifetime',
      title: 'Crit Alarm Cloud Lifetime',
      priceString: r'$0.00',
      price: 0,
      currency: 'USD',
      period: StorePeriod.lifetime,
    );
    return purchasePackage(entry);
  }

  Future<void> dispose() async {
    await _customerInfoController.close();
  }
}
