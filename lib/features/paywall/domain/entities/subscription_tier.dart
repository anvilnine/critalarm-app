import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Subscription plans offered by Crit Alarm.
///
/// Two, because two is what the stores hold: `app.critalarm.hosted.monthly`
/// and `app.critalarm.hosted.annual` on Apple, `app.critalarm.hosted:monthly`
/// and `app.critalarm.hosted:yearly` on Play. There is no lifetime product in
/// either store, so there is no lifetime plan here.
enum SubscriptionTier {
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
  static const String yearlyId = r'$rc_annual';
  static const String monthlyId = r'$rc_monthly';

  /// Display title for the plan. Carries the product name as well as the
  /// duration, which App Store review guideline 3.1.2 asks for.
  String get displayName {
    switch (this) {
      case SubscriptionTier.yearly:
        return LocaleKeys.paywall_tier_yearly.tr();
      case SubscriptionTier.monthly:
        return LocaleKeys.paywall_tier_monthly.tr();
    }
  }

  /// How long one purchase lasts, and how often it renews.
  String get durationName {
    switch (this) {
      case SubscriptionTier.yearly:
        return LocaleKeys.paywall_duration_yearly.tr();
      case SubscriptionTier.monthly:
        return LocaleKeys.paywall_duration_monthly.tr();
    }
  }

  /// What the analytics events call this plan.
  String get analyticsKey {
    switch (this) {
      case SubscriptionTier.yearly:
        return 'yearly';
      case SubscriptionTier.monthly:
        return 'monthly';
    }
  }

  /// Resolves the plan from a RevenueCat package. Anything that is not a
  /// month or a year is not something this app sells, so it answers null and
  /// the caller keeps whatever was already selected.
  static SubscriptionTier? fromPackage(Package package) {
    switch (package.packageType) {
      case PackageType.annual:
        return SubscriptionTier.yearly;
      case PackageType.monthly:
        return SubscriptionTier.monthly;
      case PackageType.lifetime:
      case PackageType.custom:
      case PackageType.unknown:
      case PackageType.weekly:
      case PackageType.twoMonth:
      case PackageType.threeMonth:
      case PackageType.sixMonth:
        final identifier = package.identifier.toLowerCase();
        if (identifier.contains('year') || identifier.contains('annual')) {
          return SubscriptionTier.yearly;
        }
        if (identifier.contains('month')) {
          return SubscriptionTier.monthly;
        }
        return null;
    }
  }
}
