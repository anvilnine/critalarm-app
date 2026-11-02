import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';

/// Contract for subscription, paywall, and customer entitlement operations.
///
/// It speaks in store-neutral types. The store behind it is the
/// `StoreBilling` that `lib/app/di.dart` picked for this build.
abstract interface class SubscriptionRepository {
  /// Returns whether the user currently has the `hosted` entitlement.
  Future<AppResult<bool>> isProActive();

  /// Retrieves the latest customer info from the store or its cache.
  Future<AppResult<StoreCustomer>> getCustomerInfo();

  /// Fetches the offerings on sale.
  Future<AppResult<StoreOfferings>> getOfferings();

  /// Buys [package], an entry from the last [getOfferings].
  Future<AppResult<StoreCustomer>> purchasePackage(StoreCatalogEntry package);

  /// Restores previous purchases for the current user.
  Future<AppResult<StoreCustomer>> restorePurchases();

  /// Stream of customer info updates emitted when purchases or entitlements
  /// change.
  Stream<StoreCustomer> get customerInfoStream;
}
