import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/data/revenuecat_store_catalog.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/store_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Package _package(
  String id,
  PackageType type,
  String price,
  double amount, {
  String? perMonth,
}) => Package(
  id,
  type,
  StoreProduct(id, '', id, amount, price, 'USD', pricePerMonthString: perMonth),
  const PresentedOfferingContext('x', null, null),
);

Offering _offering(String id, List<Package> packages) =>
    Offering(id, id, const <String, Object>{}, packages);

/// A RevenueCat service that answers what the test scripted.
class _FakeService extends RevenueCatService {
  bool configured = true;
  Exception? offeringsError;
  Offerings offerings = const Offerings(<String, Offering>{});
  Exception? purchaseError;
  Exception? restoreError;
  final List<String> purchased = [];
  int restores = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<Offerings> getOfferings() async {
    final error = offeringsError;
    if (error != null) throw error;
    return offerings;
  }

  @override
  Future<CustomerInfo> purchasePackage(Package package) async {
    purchased.add(package.identifier);
    final error = purchaseError;
    if (error != null) throw error;
    return _info;
  }

  @override
  Future<CustomerInfo> restorePurchases() async {
    restores++;
    final error = restoreError;
    if (error != null) throw error;
    return _info;
  }
}

final _info = CustomerInfo.fromJson(const <String, dynamic>{
  'entitlements': <String, dynamic>{
    'all': <String, dynamic>{},
    'active': <String, dynamic>{},
  },
  'allPurchaseDates': <String, String?>{},
  'activeSubscriptions': <String>[],
  'allPurchasedProductIdentifiers': <String>[],
  'nonSubscriptionTransactions': <dynamic>[],
  'firstSeen': '2026-01-01T00:00:00Z',
  'originalAppUserId': 'u',
  'allExpirationDates': <String, String?>{},
  'requestDate': '2026-01-01T00:00:00Z',
});

void main() {
  late PriceBook book;
  late _FakeService service;
  late RevenueCatStoreCatalog catalog;

  final yearly = _package(
    r'$rc_annual',
    PackageType.annual,
    'S-YEAR',
    80,
    perMonth: 'S-PER-MONTH',
  );
  final monthly = _package(r'$rc_monthly', PackageType.monthly, 'S-MONTH', 10);
  final pro = _package('pro_once', PackageType.lifetime, 'S-PRO', 99);

  Offerings storeWith({List<Package> hosted = const [], bool hasPro = true}) {
    final current = _offering('default', hosted);
    return Offerings(<String, Offering>{
      'default': current,
      if (hasPro) 'pro': _offering('pro', [pro]),
    }, current: current);
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    book = await AssetPriceBook.load(rootBundle, locale: 'en_US');
  });

  setUp(() {
    service = _FakeService();
    catalog = RevenueCatStoreCatalog(service, book);
  });

  group('plans on sale', () {
    test("Hosted: both plans are found by the book's package ids", () async {
      service.offerings = storeWith(hosted: [monthly, yearly]);
      final plans = await catalog.plansFor(PaywallProduct.hosted);
      expect(plans.map((p) => p.id), [
        PriceBookPlan.hostedYearly,
        PriceBookPlan.hostedMonthly,
      ]);
      expect(plans.map((p) => p.kind), [
        StorePlanKind.yearly,
        StorePlanKind.monthly,
      ]);
      expect(plans.first.priceString, 'S-YEAR');
      expect(plans.first.price, 80);
      expect(plans.first.currency, 'USD');
      expect(plans.first.pricePerMonthString, 'S-PER-MONTH');
      expect(plans.last.pricePerMonthString, isNull);
    });

    test(
      "Pro: the only package of the book's offering is a one time plan",
      () async {
        service.offerings = storeWith();
        final plans = await catalog.plansFor(PaywallProduct.pro);
        expect(plans, hasLength(1));
        expect(plans.single.kind, StorePlanKind.oneTime);
        expect(plans.single.priceString, 'S-PRO');
      },
    );

    test('a plan the store does not have is left out', () async {
      service.offerings = storeWith(hosted: [monthly]);
      final plans = await catalog.plansFor(PaywallProduct.hosted);
      expect(plans.map((p) => p.id), [PriceBookPlan.hostedMonthly]);
    });

    test('an offering the store does not have gives no plan', () async {
      service.offerings = storeWith(hosted: [yearly], hasPro: false);
      expect(await catalog.plansFor(PaywallProduct.pro), isEmpty);
    });

    test(
      'a store that cannot be asked gives no plan and does not throw',
      () async {
        service.offeringsError = PlatformException(code: 'offline');
        expect(await catalog.plansFor(PaywallProduct.hosted), isEmpty);
        service
          ..offeringsError = null
          ..configured = false;
        expect(await catalog.plansFor(PaywallProduct.hosted), isEmpty);
      },
    );

    test('with an empty book nothing is looked for', () async {
      service.offerings = storeWith(hosted: [monthly, yearly]);
      final empty = RevenueCatStoreCatalog(service, const EmptyPriceBook());
      expect(await empty.plansFor(PaywallProduct.hosted), isEmpty);
    });
  });

  group('buying', () {
    test('a plan that was read is bought', () async {
      service.offerings = storeWith(hosted: [monthly, yearly]);
      final plans = await catalog.plansFor(PaywallProduct.hosted);
      expect(await catalog.buy(plans.first), StoreOutcome.done);
      expect(service.purchased, [r'$rc_annual']);
    });

    test('backing out is cancelled', () async {
      service.offerings = storeWith(hosted: [monthly, yearly]);
      final plans = await catalog.plansFor(PaywallProduct.hosted);
      service.purchaseError = PlatformException(
        code: '1',
        details: {
          'userCancelled': true,
          'readableErrorCode': 'PURCHASE_CANCELLED',
        },
      );
      expect(await catalog.buy(plans.first), StoreOutcome.cancelled);
    });

    test('any other error is a problem', () async {
      service.offerings = storeWith(hosted: [monthly, yearly]);
      final plans = await catalog.plansFor(PaywallProduct.hosted);
      service.purchaseError = Exception('no account');
      expect(await catalog.buy(plans.first), StoreOutcome.problem);
    });

    test('a plan that was never read is a problem and asks nobody', () async {
      const unread = StorePlan(
        id: PriceBookPlan.hostedYearly,
        product: PaywallProduct.hosted,
        kind: StorePlanKind.yearly,
        priceString: 'x',
        price: 1,
        currency: 'USD',
      );
      expect(await catalog.buy(unread), StoreOutcome.problem);
      expect(service.purchased, isEmpty);
    });
  });

  group('restoring', () {
    test('done', () async {
      expect(await catalog.restore(), StoreOutcome.done);
      expect(service.restores, 1);
    });

    test('a store that fails is a problem', () async {
      service.restoreError = Exception('no account');
      expect(await catalog.restore(), StoreOutcome.problem);
    });

    test('a store that is not set up is a problem and is not asked', () async {
      service.configured = false;
      expect(await catalog.restore(), StoreOutcome.problem);
      expect(service.restores, 0);
    });
  });
}
