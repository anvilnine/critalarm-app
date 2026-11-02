import 'package:flutter/foundation.dart';

/// One entitlement the store holds for this account, such as `hosted`.
@immutable
final class StoreEntitlement {
  const StoreEntitlement({
    required this.id,
    required this.isActive,
    required this.willRenew,
    required this.productId,
    this.productPlanId,
    this.expirationDate,
    this.billingIssueDetectedAt,
  });

  final String id;
  final bool isActive;
  final bool willRenew;

  /// The store product that grants it. App Store ids carry the period
  /// (`...annual`).
  final String productId;

  /// A Play base plan id (`yearly`). Null on the App Store.
  final String? productPlanId;

  /// ISO 8601, as the store sent it. Null for a purchase that never ends.
  final String? expirationDate;

  /// ISO 8601, when the store saw a payment fail. Null when none did.
  final String? billingIssueDetectedAt;

  @override
  bool operator ==(Object other) =>
      other is StoreEntitlement &&
      other.id == id &&
      other.isActive == isActive &&
      other.willRenew == willRenew &&
      other.productId == productId &&
      other.productPlanId == productPlanId &&
      other.expirationDate == expirationDate &&
      other.billingIssueDetectedAt == billingIssueDetectedAt;

  @override
  int get hashCode => Object.hash(
    id,
    isActive,
    willRenew,
    productId,
    productPlanId,
    expirationDate,
    billingIssueDetectedAt,
  );
}

/// The entitlements the store holds for this account.
@immutable
final class StoreEntitlements {
  const StoreEntitlements({this.all = const {}, this.active = const {}});

  /// Every entitlement the account ever held, by id.
  final Map<String, StoreEntitlement> all;

  /// The ones active now, by id.
  final Map<String, StoreEntitlement> active;

  @override
  bool operator ==(Object other) =>
      other is StoreEntitlements &&
      mapEquals(other.all, all) &&
      mapEquals(other.active, active);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(all.values),
    Object.hashAllUnordered(active.values),
  );
}

/// What the store knows about this account, in no store's types.
@immutable
final class StoreCustomer {
  const StoreCustomer({
    this.entitlements = const StoreEntitlements(),
    this.managementUrl,
  });

  final StoreEntitlements entitlements;

  /// Where the store lets the person manage or cancel the plan.
  final String? managementUrl;

  @override
  bool operator ==(Object other) =>
      other is StoreCustomer &&
      other.entitlements == entitlements &&
      other.managementUrl == managementUrl;

  @override
  int get hashCode => Object.hash(entitlements, managementUrl);
}
