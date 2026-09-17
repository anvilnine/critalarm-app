import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('SubscriptionTier', () {
    // These four strings are typed into the RevenueCat dashboard, so a rename
    // there has to land here too. `hosted` is the entitlement the two paid
    // products hand out; the other three are package identifiers in the
    // `default` offering.
    test('constants match the RevenueCat dashboard', () {
      expect(SubscriptionTier.proEntitlement, equals('hosted'));
      expect(SubscriptionTier.lifetimeId, equals(r'$rc_lifetime'));
      expect(SubscriptionTier.yearlyId, equals(r'$rc_annual'));
      expect(SubscriptionTier.monthlyId, equals(r'$rc_monthly'));
    });

    test('displayName returns user-friendly label', () {
      expect(SubscriptionTier.lifetime.displayName, equals('Lifetime'));
      expect(SubscriptionTier.yearly.displayName, equals('Yearly'));
      expect(SubscriptionTier.monthly.displayName, equals('Monthly'));
    });

    // The packages and store products the `default` offering really holds.
    test('fromPackage resolves the packages in the default offering', () {
      const lifetimePkg = Package(
        r'$rc_lifetime',
        PackageType.lifetime,
        StoreProduct('lifetime', 'L', 'L', 49.99, r'$49.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const annualPkg = Package(
        r'$rc_annual',
        PackageType.annual,
        StoreProduct(
          'app.critalarm.hosted.annual',
          'Y',
          'Y',
          19.99,
          r'$19.99',
          'USD',
        ),
        PresentedOfferingContext('default', null, null),
      );
      const monthlyPkg = Package(
        r'$rc_monthly',
        PackageType.monthly,
        StoreProduct(
          'app.critalarm.hosted.monthly',
          'M',
          'M',
          2.99,
          r'$2.99',
          'USD',
        ),
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
