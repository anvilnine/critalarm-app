import 'package:purchases_flutter/purchases_flutter.dart';

/// Subscription tiers offered by Crit Alarm.
enum SubscriptionTier {
  lifetime,
  yearly,
  monthly;

  /// Identifier for the Crit Alarm Pro entitlement in RevenueCat.
  static const String proEntitlement = 'crit_alarm_pro';

  /// Package / product identifiers used in RevenueCat.
  static const String lifetimeId = 'lifetime';
  static const String yearlyId = 'yearly';
  static const String monthlyId = 'monthly';

  /// Display title for the tier.
  String get displayName {
    switch (this) {
      case SubscriptionTier.lifetime:
        return 'Lifetime';
      case SubscriptionTier.yearly:
        return 'Yearly';
      case SubscriptionTier.monthly:
        return 'Monthly';
    }
  }

  /// Resolves the tier from a RevenueCat package.
  static SubscriptionTier? fromPackage(Package package) {
    switch (package.packageType) {
      case PackageType.lifetime:
        return SubscriptionTier.lifetime;
      case PackageType.annual:
        return SubscriptionTier.yearly;
      case PackageType.monthly:
        return SubscriptionTier.monthly;
      case PackageType.custom:
      case PackageType.unknown:
      case PackageType.weekly:
      case PackageType.twoMonth:
      case PackageType.threeMonth:
      case PackageType.sixMonth:
        if (package.identifier.toLowerCase().contains('lifetime')) {
          return SubscriptionTier.lifetime;
        } else if (package.identifier.toLowerCase().contains('year') ||
            package.identifier.toLowerCase().contains('annual')) {
          return SubscriptionTier.yearly;
        } else if (package.identifier.toLowerCase().contains('month')) {
          return SubscriptionTier.monthly;
        }
        return null;
    }
  }
}
