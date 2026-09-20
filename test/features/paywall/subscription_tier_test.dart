import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('SubscriptionTier', () {
    // These three strings are typed into the RevenueCat dashboard, so a rename
    // there has to land here too. `hosted` is the entitlement the two paid
    // products hand out; the other two are package identifiers in the
    // `default` offering.
    test('constants match the RevenueCat dashboard', () {
      expect(SubscriptionTier.proEntitlement, equals('hosted'));
      expect(SubscriptionTier.yearlyId, equals(r'$rc_annual'));
      expect(SubscriptionTier.monthlyId, equals(r'$rc_monthly'));
    });

    test('there are two plans, because the stores hold two products', () {
      expect(SubscriptionTier.values, hasLength(2));
      expect(
        SubscriptionTier.values,
        containsAll([SubscriptionTier.yearly, SubscriptionTier.monthly]),
      );
    });

    test('analyticsKey names the plan for the A/B funnel', () {
      expect(SubscriptionTier.yearly.analyticsKey, equals('yearly'));
      expect(SubscriptionTier.monthly.analyticsKey, equals('monthly'));
    });

    // The packages and store products the `default` offering really holds.
    test('fromPackage resolves the packages in the default offering', () {
      const annualPkg = Package(
        r'$rc_annual',
        PackageType.annual,
        StoreProduct(
          'app.critalarm.hosted.annual',
          'Y',
          'Y',
          39.99,
          r'$39.99',
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
          4.99,
          r'$4.99',
          'USD',
        ),
        PresentedOfferingContext('default', null, null),
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

    // `$rc_lifetime` sits in the offering editor with no product behind it,
    // and neither store sells a lifetime product. Anything lifetime shaped has
    // to come back null so the paywall never draws a row nobody can buy.
    test('fromPackage answers null for a lifetime package', () {
      const lifetimePkg = Package(
        r'$rc_lifetime',
        PackageType.lifetime,
        StoreProduct('lifetime', 'L', 'L', 49.99, r'$49.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const customLifetime = Package(
        'my_lifetime_tier',
        PackageType.custom,
        StoreProduct('c1', 'C1', 'C1', 49.99, r'$49.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );

      expect(SubscriptionTier.fromPackage(lifetimePkg), isNull);
      expect(SubscriptionTier.fromPackage(customLifetime), isNull);
    });

    test('fromPackage resolves custom packages by identifier substring', () {
      const customYearly = Package(
        'crit_alarm_yearly',
        PackageType.custom,
        StoreProduct('c2', 'C2', 'C2', 39.99, r'$39.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );
      const customMonthly = Package(
        'crit_alarm_monthly_sub',
        PackageType.custom,
        StoreProduct('c3', 'C3', 'C3', 4.99, r'$4.99', 'USD'),
        PresentedOfferingContext('default', null, null),
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
