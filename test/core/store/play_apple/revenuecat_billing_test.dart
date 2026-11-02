import 'package:critalarm/core/store/play_apple/revenuecat_billing.dart';
import 'package:critalarm/core/store/play_apple/revenuecat_service.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// The mock packages the paywall tests use (paywall_buy_cubit_test.dart and
// paywall_cubit_integration_test.dart). Made-up prices.
const _yearlyPackage = Package(
  r'$rc_annual',
  PackageType.annual,
  StoreProduct(
    'yearly',
    'Yearly',
    'Yearly',
    80, // l10n-ok: demo data
    'Y-PRICE',
    'XXX',
    pricePerMonthString: 'Y-PER-MONTH',
  ),
  PresentedOfferingContext('default', null, null),
);
const _monthlyPackage = Package(
  r'$rc_monthly',
  PackageType.monthly,
  StoreProduct(
    'monthly',
    'Monthly',
    'Monthly',
    10, // l10n-ok: demo data
    'M-PRICE',
    'XXX',
  ),
  PresentedOfferingContext('default', null, null),
);
const _proPackage = Package(
  r'$rc_lifetime',
  PackageType.lifetime,
  StoreProduct('pro', 'Pro', 'Pro pack', 20, 'P-PRICE', 'XXX'),
  PresentedOfferingContext('pro', null, null),
);
const _offering = Offering(
  'default',
  'Default',
  <String, Object>{},
  <Package>[_yearlyPackage, _monthlyPackage],
  annual: _yearlyPackage,
  monthly: _monthlyPackage,
);
const _pro = Offering('pro', 'Pro', <String, Object>{}, <Package>[_proPackage]);
const _offerings = Offerings(
  <String, Offering>{'default': _offering, 'pro': _pro},
  current: _offering,
);

Package _withIntro(IntroductoryPrice intro) => Package(
  r'$rc_annual',
  PackageType.annual,
  StoreProduct(
    'yearly',
    'Yearly',
    'Yearly',
    80, // l10n-ok: demo data
    'Y-PRICE',
    'XXX',
    introductoryPrice: intro,
  ),
  const PresentedOfferingContext('default', null, null),
);

CustomerInfo _info({List<String> active = const []}) {
  Map<String, Object?> entitlement(String id) => {
    'identifier': id,
    'isActive': true,
    'willRenew': false,
    'periodType': 'NORMAL',
    'latestPurchaseDate': '2026-01-01T00:00:00Z',
    'originalPurchaseDate': '2026-01-01T00:00:00Z',
    'expirationDate': '2027-01-01T00:00:00Z',
    'store': 'PLAY_STORE',
    'productIdentifier': 'app.critalarm.hosted',
    'productPlanIdentifier': 'yearly',
    'isSandbox': true,
    'ownershipType': 'PURCHASED',
    'billingIssueDetectedAt': '2026-06-01T00:00:00Z',
  };
  return CustomerInfo.fromJson({
    'entitlements': {
      'all': {for (final id in active) id: entitlement(id)},
      'active': {for (final id in active) id: entitlement(id)},
    },
    'allPurchaseDates': const <String, String?>{},
    'activeSubscriptions': const <String>[],
    'allPurchasedProductIdentifiers': const <String>[],
    'nonSubscriptionTransactions': const <dynamic>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'u',
    'allExpirationDates': const <String, String?>{},
    'requestDate': '2026-01-01T00:00:00Z',
    'managementURL': 'https://play.google.com/store/account/subscriptions',
  });
}

PlatformException _error(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: code.name);

/// The SDK wrapper as a test scripts it. Records the package of every
/// purchase.
class _FakeService extends RevenueCatService {
  Offerings offerings = _offerings;
  Exception? purchaseError;
  Exception? logOutError;
  int logOuts = 0;
  final List<String> bought = [];

  @override
  bool get isConfigured => true;

  @override
  Future<Offerings> getOfferings() async => offerings;

  @override
  Future<CustomerInfo> purchasePackage(Package package) async {
    bought.add(
      '${package.presentedOfferingContext.offeringIdentifier}/'
      '${package.identifier}/${package.storeProduct.identifier}',
    );
    final error = purchaseError;
    if (error != null) throw error;
    return _info(active: ['hosted']);
  }

  @override
  Future<CustomerInfo> getCustomerInfo() async => _info(active: ['hosted']);

  @override
  Future<CustomerInfo> logOut() async {
    logOuts++;
    final error = logOutError;
    if (error != null) throw error;
    return _info();
  }
}

void main() {
  group('a RevenueCat package as a catalog entry', () {
    test('keeps the price string, the amount and the currency', () {
      final entry = storeCatalogEntryOf(_yearlyPackage, offeringId: 'default');
      expect(entry.offeringId, 'default');
      expect(entry.id, r'$rc_annual');
      expect(entry.productId, 'yearly');
      expect(entry.title, 'Yearly');
      expect(entry.priceString, 'Y-PRICE');
      expect(entry.price, 80);
      expect(entry.currency, 'XXX');
      expect(entry.pricePerMonthString, 'Y-PER-MONTH');
    });

    test('names the period from the package type', () {
      expect(
        storeCatalogEntryOf(_yearlyPackage, offeringId: 'default').period,
        StorePeriod.yearly,
      );
      expect(
        storeCatalogEntryOf(_monthlyPackage, offeringId: 'default').period,
        StorePeriod.monthly,
      );
      expect(
        storeCatalogEntryOf(_proPackage, offeringId: 'pro').period,
        StorePeriod.lifetime,
      );
      const weekly = Package(
        'w',
        PackageType.weekly,
        StoreProduct('w', 'W', 'W', 1, 'W-PRICE', 'XXX'),
        PresentedOfferingContext('default', null, null),
      );
      expect(
        storeCatalogEntryOf(weekly, offeringId: 'default').period,
        StorePeriod.other,
      );
    });

    test('has no trial and no intro when the store sends none', () {
      final entry = storeCatalogEntryOf(_yearlyPackage, offeringId: 'default');
      expect(entry.trial, isNull);
      expect(entry.intro, isNull);
      expect(entry.pricePerMonthString, isNotNull);
      expect(
        storeCatalogEntryOf(
          _monthlyPackage,
          offeringId: 'default',
        ).pricePerMonthString,
        isNull,
      );
    });

    test('a free introductory price is a trial', () {
      final entry = storeCatalogEntryOf(
        _withIntro(
          const IntroductoryPrice(0, 'FREE', 'P1W', 1, PeriodUnit.week, 1),
        ),
        offeringId: 'default',
      );
      expect(entry.intro, isNull);
      expect(
        entry.trial,
        const StoreIntroOffer(
          priceString: 'FREE',
          price: 0,
          period: 'P1W',
          cycles: 1,
        ),
      );
    });

    test('a paid introductory price is an intro, not a trial', () {
      final entry = storeCatalogEntryOf(
        _withIntro(
          const IntroductoryPrice(1, 'I-PRICE', 'P1M', 3, PeriodUnit.month, 1),
        ),
        offeringId: 'default',
      );
      expect(entry.trial, isNull);
      expect(
        entry.intro,
        const StoreIntroOffer(
          priceString: 'I-PRICE',
          price: 1,
          period: 'P1M',
          cycles: 3,
        ),
      );
    });
  });

  group('RevenueCat offerings as store offerings', () {
    test('keep current, every offering and the marked annual and monthly', () {
      final offerings = storeOfferingsOf(_offerings);
      final current = offerings.current!;
      expect(current.id, 'default');
      expect(current.entries.map((e) => e.id), [r'$rc_annual', r'$rc_monthly']);
      expect(current.annual?.priceString, 'Y-PRICE');
      expect(current.monthly?.priceString, 'M-PRICE');
      expect(offerings.all.keys, ['default', 'pro']);
      expect(offerings.all['pro']!.entries.single.offeringId, 'pro');
      expect(offerings.all['pro']!.annual, isNull);
    });

    test('an offering with nothing marked has no annual or monthly', () {
      const plain = Offering(
        'default',
        'Default',
        <String, Object>{},
        <Package>[_yearlyPackage],
      );
      final offering = storeOfferingOf(plain);
      expect(offering.entries, hasLength(1));
      expect(offering.annual, isNull);
      expect(offering.monthly, isNull);
    });
  });

  test('a RevenueCat customer keeps its entitlements and management url', () {
    final customer = storeCustomerOf(_info(active: ['hosted']));
    final hosted = customer.entitlements.active['hosted']!;
    expect(customer.entitlements.all.keys, ['hosted']);
    expect(hosted.isActive, isTrue);
    expect(hosted.willRenew, isFalse);
    expect(hosted.productId, 'app.critalarm.hosted');
    expect(hosted.productPlanId, 'yearly');
    expect(hosted.expirationDate, '2027-01-01T00:00:00Z');
    expect(hosted.billingIssueDetectedAt, '2026-06-01T00:00:00Z');
    expect(
      customer.managementUrl,
      'https://play.google.com/store/account/subscriptions',
    );
    expect(storeCustomerOf(_info()).entitlements.active, isEmpty);
  });

  group('RevenueCat errors', () {
    final cases = {
      PurchasesErrorCode.purchaseCancelledError: StoreBillingError.cancelled,
      PurchasesErrorCode.purchaseNotAllowedError: StoreBillingError.notAllowed,
      PurchasesErrorCode.paymentPendingError: StoreBillingError.pending,
      PurchasesErrorCode.productAlreadyPurchasedError:
          StoreBillingError.alreadyOwned,
      PurchasesErrorCode.networkError: StoreBillingError.network,
      PurchasesErrorCode.invalidCredentialsError:
          StoreBillingError.badConfiguration,
      PurchasesErrorCode.storeProblemError: StoreBillingError.storeProblem,
      PurchasesErrorCode.receiptAlreadyInUseError: StoreBillingError.other,
    };
    for (final MapEntry(key: code, value: error) in cases.entries) {
      test('${code.name} is ${error.name}', () {
        expect(storeBillingExceptionOf(_error(code)).error, error);
      });
    }

    test('an unnamed error keeps the store words, or names the code', () {
      expect(
        storeBillingExceptionOf(
          _error(PurchasesErrorCode.receiptAlreadyInUseError),
        ).message,
        'receiptAlreadyInUseError',
      );
      expect(
        storeBillingExceptionOf(
          PlatformException(
            code: '${PurchasesErrorCode.receiptAlreadyInUseError.index}',
          ),
        ).message,
        'RevenueCat error: receiptAlreadyInUseError',
      );
    });
  });

  group('RevenueCatBilling', () {
    late _FakeService service;
    late RevenueCatBilling billing;

    setUp(() {
      service = _FakeService();
      billing = RevenueCatBilling(service);
    });

    test('buys the exact package an entry came from', () async {
      final offerings = await billing.readOfferings();
      await billing.purchase(offerings.all['pro']!.entries.single);
      await billing.purchase(offerings.current!.monthly!);
      expect(service.bought, [
        r'pro/$rc_lifetime/pro',
        r'default/$rc_monthly/monthly',
      ]);
    });

    test('an entry no read handed out is never bought', () async {
      final entry = storeCatalogEntryOf(_yearlyPackage, offeringId: 'other');
      await expectLater(billing.purchase(entry), throwsStateError);
      expect(service.bought, isEmpty);
    });

    test('a store error comes back as a StoreBillingException', () async {
      service.purchaseError = _error(PurchasesErrorCode.paymentPendingError);
      final offerings = await billing.readOfferings();
      await expectLater(
        billing.purchase(offerings.current!.annual!),
        throwsA(
          isA<StoreBillingException>().having(
            (e) => e.error,
            'error',
            StoreBillingError.pending,
          ),
        ),
      );
    });

    test('reads the customer in neutral types', () async {
      final customer = await billing.readCustomer();
      expect(customer.entitlements.active.keys, ['hosted']);
    });

    group('logOut', () {
      test('logs the store user out', () async {
        await billing.logOut();
        expect(service.logOuts, 1);
      });

      test('an already anonymous store user is not an error', () async {
        service.logOutError = _error(
          PurchasesErrorCode.logOutWithAnonymousUserError,
        );
        await billing.logOut();
        expect(service.logOuts, 1);
      });

      test('a network error comes back as a StoreBillingException', () async {
        service.logOutError = _error(PurchasesErrorCode.networkError);
        await expectLater(
          billing.logOut(),
          throwsA(
            isA<StoreBillingException>().having(
              (e) => e.error,
              'error',
              StoreBillingError.network,
            ),
          ),
        );
      });

      test('a store code that is not a number is not the anonymous '
          'answer', () async {
        service.logOutError = PlatformException(code: 'not-a-number');
        await expectLater(
          billing.logOut(),
          throwsA(
            isA<StoreBillingException>().having(
              (e) => e.error,
              'error',
              StoreBillingError.other,
            ),
          ),
        );
      });

      test('an error that is not a store code passes through', () async {
        service.logOutError = const FormatException('boom');
        await expectLater(billing.logOut(), throwsFormatException);
      });
    });
  });
}
