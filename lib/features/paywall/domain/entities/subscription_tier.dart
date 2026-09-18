import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Subscription tiers offered by Crit Alarm.
enum SubscriptionTier {
  lifetime,
  yearly,
  monthly;

  /// The paid entitlement in the RevenueCat dashboard. Both `hosted` store
  /// products hand it out, and the relay webhook turns it into
  /// `accounts.tier = 'hosted'`. The dashboard also has a `relay` entitlement
  /// with no products attached, so it never fires and the app never reads it.
  static const String proEntitlement = 'hosted';

  /// RevenueCat package identifiers in the `default` offering. The standard
  /// durations keep their `$rc_` names, so a comparison against
  /// `Package.identifier` has to use these and not 'monthly' or 'yearly'.
  /// `$rc_lifetime` exists in the offering editor with no product behind it,
  /// because nothing lifetime is sold at launch.
  static const String lifetimeId = r'$rc_lifetime';
  static const String yearlyId = r'$rc_annual';
  static const String monthlyId = r'$rc_monthly';

  /// Display title for the tier.
  String get displayName {
    switch (this) {
      case SubscriptionTier.lifetime:
        return LocaleKeys.paywall_tier_lifetime.tr();
      case SubscriptionTier.yearly:
        return LocaleKeys.paywall_tier_yearly.tr();
      case SubscriptionTier.monthly:
        return LocaleKeys.paywall_tier_monthly.tr();
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
