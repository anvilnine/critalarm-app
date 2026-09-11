import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('SubscriptionTier', () {
    test('constants match required RevenueCat configuration', () {
      expect(SubscriptionTier.proEntitlement, equals('crit_alarm_pro'));
      expect(SubscriptionTier.lifetimeId, equals('lifetime'));
      expect(SubscriptionTier.yearlyId, equals('yearly'));
      expect(SubscriptionTier.monthlyId, equals('monthly'));
    });

    test('displayName returns user-friendly label', () {
      expect(SubscriptionTier.lifetime.displayName, equals('Lifetime'));
      expect(SubscriptionTier.yearly.displayName, equals('Yearly'));
      expect(SubscriptionTier.monthly.displayName, equals('Monthly'));
    });

    test('fromPackage resolves predefined package types', () {
      const lifetimePkg = Package(
        'lifetime',
        PackageType.lifetime,
        StoreProduct('lifetime', 'L', 'L', 49.99, r'$49.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const annualPkg = Package(
        'yearly',
        PackageType.annual,
        StoreProduct('yearly', 'Y', 'Y', 19.99, r'$19.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const monthlyPkg = Package(
        'monthly',
        PackageType.monthly,
        StoreProduct('monthly', 'M', 'M', 2.99, r'$2.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );

      expect(
        SubscriptionTier.fromPackage(lifetimePkg),
        equals(SubscriptionTier.lifetime),
      );
      expect(
        SubscriptionTier.fromPackage(annualPkg),
        equals(SubscriptionTier.yearly),
      );
      expect(
        SubscriptionTier.fromPackage(monthlyPkg),
        equals(SubscriptionTier.monthly),
      );
    });

    test('fromPackage resolves custom packages by identifier substring', () {
      const customLifetime = Package(
        'my_lifetime_tier',
        PackageType.custom,
        StoreProduct('c1', 'C1', 'C1', 49.99, r'$49.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const customYearly = Package(
        'crit_alarm_yearly',
        PackageType.custom,
        StoreProduct('c2', 'C2', 'C2', 19.99, r'$19.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const customMonthly = Package(
        'crit_alarm_monthly_sub',
        PackageType.custom,
        StoreProduct('c3', 'C3', 'C3', 2.99, r'$2.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );

      expect(
        SubscriptionTier.fromPackage(customLifetime),
        equals(SubscriptionTier.lifetime),
      );
      expect(
        SubscriptionTier.fromPackage(customYearly),
        equals(SubscriptionTier.yearly),
      );
      expect(
        SubscriptionTier.fromPackage(customMonthly),
        equals(SubscriptionTier.monthly),
      );
    });
  });
}
