import 'package:critalarm/core/result/result.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Contract for subscription, paywall, and customer entitlement operations.
abstract interface class SubscriptionRepository {
  /// Returns whether the user currently has the `crit_alarm_pro` entitlement.
  Future<AppResult<bool>> isProActive();

  /// Retrieves the latest customer info from RevenueCat or cache.
  Future<AppResult<CustomerInfo>> getCustomerInfo();

  /// Fetches available offerings from RevenueCat.
  Future<AppResult<Offerings>> getOfferings();

  /// Initiates purchase of the given RevenueCat package.
  Future<AppResult<CustomerInfo>> purchasePackage(Package package);

  /// Restores previous purchases for the current user.
  Future<AppResult<CustomerInfo>> restorePurchases();

  /// Stream of customer info updates emitted when purchases or entitlements
  /// change.
  Stream<CustomerInfo> get customerInfoStream;
}
