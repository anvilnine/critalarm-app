// The two buy models over the real RevenueCat classes the composition root
// hands them in a store build: RevenueCatSubscriptionRepository for Cloud and
// RevenueCatProPackShop for Pro. Only RevenueCatService is faked, so every
// store answer goes through the same mapping a phone runs.

import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/data/repositories/revenuecat_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hosted_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/pro_paywall_buy_cubit.dart';
import 'package:critalarm/features/pro_pack/data/revenuecat_pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../helpers/load_translations.dart';
import '../../pro_pack/pro_pack_fakes.dart';

// Made-up store prices. No plan costs these.
Package _package(
  String packageId,
  PackageType type,
  String productId,
  String price,
  double amount,
  String offeringId,
) => Package(
  packageId,
  type,
  StoreProduct(productId, productId, productId, amount, price, 'XXX'),
  PresentedOfferingContext(offeringId, null, null),
);

// The shape the dashboard has: Cloud's two plans in the current `default`
// offering, beside a lifetime package that only the Test Store fills, and
// Pro alone in the `pro` offering. Both lifetime packages share one id.
final Package _monthly = _package(
  r'$rc_monthly',
  PackageType.monthly,
  'app.critalarm.hosted.monthly',
  'M-PRICE',
  10,
  'default',
);
final Package _annual = _package(
  r'$rc_annual',
  PackageType.annual,
  'app.critalarm.hosted.annual',
  'Y-PRICE',
  80,
  'default',
);
final Package _testStoreLifetime = _package(
  r'$rc_lifetime',
  PackageType.lifetime,
  'test_store_lifetime',
  'T-PRICE',
  1,
  'default',
);
final Package _pro = _package(
  r'$rc_lifetime',
  PackageType.lifetime,
  'app.critalarm.pro',
  'P-PRICE',
  20,
  'pro',
);

Offering _offering(String id, List<Package> packages) => Offering(
  id,
  id,
  const <String, Object>{},
  packages,
  monthly: packages.where((p) => p.packageType == PackageType.monthly).first,
  annual: packages.where((p) => p.packageType == PackageType.annual).first,
);

Offerings _store({bool hasPro = true}) {
  final current = _offering('default', [_monthly, _annual, _testStoreLifetime]);
  return Offerings(<String, Offering>{
    'default': current,
    if (hasPro) 'pro': Offering('pro', 'pro', const <String, Object>{}, [_pro]),
  }, current: current);
}

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: code.name);

Map<String, dynamic> _entitlement(String id) => <String, dynamic>{
  'identifier': id,
  'isActive': true,
  'willRenew': true,
  'periodType': 'NORMAL',
  'latestPurchaseDate': '2026-01-01T00:00:00Z',
  'originalPurchaseDate': '2026-01-01T00:00:00Z',
  'expirationDate': null,
  'store': 'APP_STORE',
  'productIdentifier': 'x',
  'isSandbox': true,
  'ownershipType': 'PURCHASED',
};

CustomerInfo _info({List<String> active = const []}) =>
    CustomerInfo.fromJson(<String, dynamic>{
      'entitlements': <String, dynamic>{
        'all': {for (final id in active) id: _entitlement(id)},
        'active': {for (final id in active) id: _entitlement(id)},
      },
      'allPurchaseDates': const <String, String?>{},
      'activeSubscriptions': const <String>[],
      'allPurchasedProductIdentifiers': const <String>[],
      'nonSubscriptionTransactions': const <dynamic>[],
      'firstSeen': '2026-01-01T00:00:00Z',
      'originalAppUserId': 'acc_1',
      'allExpirationDates': const <String, String?>{},
      'requestDate': '2026-01-01T00:00:00Z',
    });

/// RevenueCat as the test scripts it. Records the store product of every
/// purchase, so a test can tell the two `$rc_lifetime` packages apart.
class _FakeService extends RevenueCatService {
  Offerings offerings = _store();
  Exception? offeringsError;
  Exception? purchaseError;
  Exception? restoreError;
  CustomerInfo restoreInfo = _info();
  final List<String> bought = [];
  int restores = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<Offerings> getOfferings() async {
    final error = offeringsError;
    if (error != null) throw error;
    return offerings;
  }

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
  Future<CustomerInfo> restorePurchases() async {
    restores++;
    final error = restoreError;
    if (error != null) throw error;
    return restoreInfo;
  }

  @override
  Future<CustomerInfo> getCustomerInfo() async => _info();
}

const _unknown = PacksRefreshAnswer(confirmed: false, packs: []);
const _held = PacksRefreshAnswer(confirmed: true, packs: [proPack]);

void main() {
  late PriceBook book;

  setUpAll(() async {
    await loadTestTranslations();
    book = await AssetPriceBook.load(rootBundle, locale: 'en_US');
  });

  group('Cloud over RevenueCat', () {
    late _FakeService service;
    late bool serverSaysPaid;

    HostedPaywallBuyCubit build({
      PriceBook priceBook = const EmptyPriceBook(),
    }) {
      final repository = RevenueCatSubscriptionRepository(service);
      return HostedPaywallBuyCubit(
        getOfferings: GetOfferingsUsecase(repository),
        purchasePackage: PurchasePackageUsecase(repository),
        restorePurchases: RestorePurchasesUsecase(repository),
        readIsPaid: () async => serverSaysPaid,
        readIsRegisteredPaid: () async => serverSaysPaid,
        refreshRegistration: () async {},
        priceBook: priceBook,
        wait: (_) async {},
      );
    }

    setUp(() {
      service = _FakeService();
      serverSaysPaid = false;
    });

    test('offers yearly and monthly from the current offering at the '
        "store's prices, and never the Test Store lifetime", () async {
      final cubit = build(priceBook: book);
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.options.map((o) => o.price), ['Y-PRICE', 'M-PRICE']);
      expect(cubit.state.selectedId, PaywallPlanOption.yearlyId);
    });

    test(r'buys $rc_annual and $rc_monthly from default', () async {
      var cubit = build();
      await cubit.load();
      serverSaysPaid = true;
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.done);

      serverSaysPaid = false;
      cubit = build();
      await cubit.load();
      cubit.select(PaywallPlanOption.monthlyId);
      serverSaysPaid = true;
      await cubit.buy();
      expect(service.bought, [
        r'default/$rc_annual/app.critalarm.hosted.annual',
        r'default/$rc_monthly/app.critalarm.hosted.monthly',
      ]);
    });

    test('backing out rests on the plans and says nothing', () async {
      service.purchaseError = _storeError(
        PurchasesErrorCode.purchaseCancelledError,
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.messageKey, isNull);
    });

    test('a held payment shows the pending line with Check again', () async {
      service.purchaseError = _storeError(
        PurchasesErrorCode.paymentPendingError,
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
    });

    test('a store error is failed with a line', () async {
      service.purchaseError = _storeError(PurchasesErrorCode.storeProblemError);
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_failed);
    });

    test('a restore that finds the hosted entitlement ends on done', () async {
      service.restoreInfo = _info(active: ['hosted']);
      final cubit = build();
      await cubit.load();
      serverSaysPaid = true;
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('a restore with only the old entitlement finds nothing', () async {
      service.restoreInfo = _info(active: ['crit_alarm_pro']);
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_kit_nothing_to_restore,
      );
    });

    test('a store that cannot be reached draws the book, and a buy then '
        'charges nothing and says the store is not ready', () async {
      service.offeringsError = _storeError(PurchasesErrorCode.networkError);
      final cubit = build(priceBook: book);
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.options, hasLength(2));
      await cubit.buy();
      expect(service.bought, isEmpty);
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_store_not_ready);
    });
  });

  group('Pro over RevenueCat', () {
    late _FakeService service;
    late FakePacksApi api;
    late MemoryProPackStore packs;
    var now = DateTime.utc(2026, 10, 16, 9);

    ProPaywallBuyCubit build({PriceBook priceBook = const EmptyPriceBook()}) =>
        ProPaywallBuyCubit(
          access: ProPackAccess(
            api: api,
            store: packs,
            readAccountId: () async => 'acc_1',
            override: const NoProPackOverride(),
            now: () => now,
          ),
          shop: RevenueCatProPackShop(service),
          priceBook: priceBook,
          wait: (d) async => now = now.add(d),
        );

    setUp(() {
      service = _FakeService();
      api = FakePacksApi();
      packs = MemoryProPackStore();
      now = DateTime.utc(2026, 10, 16, 9);
    });

    test("offers the pro offering's one package at the store's price, on "
        'the button', () async {
      final cubit = build(priceBook: book);
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.options.single.price, 'P-PRICE');
      expect(cubit.state.selectedId, r'$rc_lifetime');
    });

    test(r'buys $rc_lifetime from pro, never the one in default, and is '
        'done once the relay lists the pack', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(service.bought, [r'pro/$rc_lifetime/app.critalarm.pro']);
      expect(cubit.state.status, PaywallBuyStatus.done);
      expect(packs.pending, isNull);
    });

    test(
      'no pro offering and no book: not on sale, Restore still there',
      () async {
        service.offerings = _store(hasPro: false);
        final cubit = build();
        await cubit.load();
        expect(cubit.state.status, PaywallBuyStatus.notOnSale);
        expect(cubit.state.canRestore, isTrue);
      },
    );

    test('no pro offering with the book: a buy charges nothing and says '
        'the store is not ready', () async {
      service.offerings = _store(hasPro: false);
      final cubit = build(priceBook: book);
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      await cubit.buy();
      expect(service.bought, isEmpty);
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_store_not_ready);
      expect(packs.pending, isNull);
    });

    test('backing out rests on the offer and forgets the purchase', () async {
      service.purchaseError = _storeError(
        PurchasesErrorCode.purchaseCancelledError,
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.messageKey, isNull);
      expect(packs.pending, isNull);
      expect(api.refreshCalls, 0);
    });

    test('a held payment shows the pending line, not a failure', () async {
      service.purchaseError = _storeError(
        PurchasesErrorCode.paymentPendingError,
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
      expect(packs.pending, isNotNull);
    });

    test('a store error is failed with a line', () async {
      service.purchaseError = _storeError(PurchasesErrorCode.storeProblemError);
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_failed);
    });

    test('a store that cannot be reached offers nothing to buy', () async {
      service.offeringsError = _storeError(PurchasesErrorCode.networkError);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
    });

    test('a restore the relay confirms ends on done', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(service.restores, 1);
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('a restore the store fails is failed with a line', () async {
      service.restoreError = _storeError(PurchasesErrorCode.networkError);
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(api.refreshCalls, 0);
    });

    test(
      'a bought pack the relay has not listed yet pauses, never fails',
      () async {
        api.refreshes = [_unknown];
        final cubit = build();
        await cubit.load();
        await cubit.buy();
        expect(cubit.state.status, PaywallBuyStatus.checking);
        expect(cubit.state.isPaused, isTrue);
        expect(cubit.state.messageKey, LocaleKeys.paywall_kit_paused);
      },
    );
  });
}
