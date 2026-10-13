import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hosted_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/pro_paywall_buy_cubit.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../pro_pack/pro_pack_fakes.dart';

Package _package(String id, PackageType type, String price, double amount) =>
    Package(
      id,
      type,
      StoreProduct(
        id,
        '',
        id,
        amount,
        price,
        'USD',
        pricePerMonthString: type == PackageType.annual ? 'S-PER-MONTH' : null,
      ),
      const PresentedOfferingContext('default', null, null),
    );

Offerings _offeringsOf(List<Package> packages) {
  final offering = Offering(
    'default',
    'Default',
    const <String, Object>{},
    packages,
    annual: packages
        .where((p) => p.packageType == PackageType.annual)
        .firstOrNull,
    monthly: packages
        .where((p) => p.packageType == PackageType.monthly)
        .firstOrNull,
  );
  return Offerings(<String, Offering>{'default': offering}, current: offering);
}

final Package _storeYearly = _package(
  r'$rc_annual',
  PackageType.annual,
  'S-YEAR',
  80,
);
final Package _storeMonthly = _package(
  r'$rc_monthly',
  PackageType.monthly,
  'S-MONTH',
  10,
);

/// A store whose offerings can change between two reads.
class _Store extends InMemorySubscriptionRepository {
  _Store(this.packages);

  List<Package> packages;
  int reads = 0;
  final List<String> purchased = [];

  @override
  Future<AppResult<Offerings>> getOfferings() async {
    reads++;
    return Success(_offeringsOf(packages));
  }

  @override
  Future<AppResult<CustomerInfo>> purchasePackage(Package package) async {
    purchased.add(package.identifier);
    return super.purchasePackage(package);
  }
}

void main() {
  late PriceBook book;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    book = await AssetPriceBook.load(rootBundle, locale: 'en_US');
  });

  group('Hosted prices', () {
    HostedPaywallBuyCubit build(
      _Store store, {
      PriceBook? priceBook,
    }) => HostedPaywallBuyCubit(
      getOfferings: GetOfferingsUsecase(store),
      purchasePackage: PurchasePackageUsecase(store),
      restorePurchases: RestorePurchasesUsecase(store),
      readIsPaid: () async => false,
      readIsRegisteredPaid: () async => false,
      refreshRegistration: () async {},
      priceBook: priceBook ?? book,
      wait: (_) async {},
    );

    test(
      'the store returns both plans: its strings show, the book does not',
      () async {
        final store = _Store([_storeYearly, _storeMonthly]);
        final cubit = build(store);
        await cubit.load();
        final prices = cubit.state.options.map((o) => o.price).toList();
        expect(prices, ['S-YEAR', 'S-MONTH']);
        expect(
          cubit.state.options.first.perPeriodLine,
          contains('S-PER-MONTH'),
        );
        expect(
          cubit.state.options.first.perPeriodLine,
          isNot(contains(r'$3.33')),
        );
        await store.dispose();
      },
    );

    test(
      'the store returns nothing: the book fills in and the button is live',
      () async {
        final store = _Store([]);
        final cubit = build(store);
        await cubit.load();
        expect(cubit.state.status, PaywallBuyStatus.ready);
        expect(cubit.state.canBuy, isTrue);
        expect(cubit.state.options.map((o) => o.id), [
          PaywallPlanOption.yearlyId,
          PaywallPlanOption.monthlyId,
        ]);
        expect(cubit.state.options.map((o) => o.price), [r'$39.99', r'$4.99']);
        expect(cubit.state.options.first.perPeriodLine, contains(r'$3.33'));
        expect(cubit.state.options.first.savingLabel, 'Save 33%');
        await store.dispose();
      },
    );

    test('the store returns only monthly: monthly from the store, yearly from '
        'the book', () async {
      final store = _Store([_storeMonthly]);
      final cubit = build(store);
      await cubit.load();
      expect(cubit.state.options.map((o) => o.price), [r'$39.99', 'S-MONTH']);
      // The saving is worked out from the two numbers on screen.
      expect(cubit.state.options.first.savingLabel, 'Save 67%');
      await store.dispose();
    });

    test('the store and the book are both empty: not on sale', () async {
      final store = _Store([]);
      final cubit = build(store, priceBook: const EmptyPriceBook());
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
      expect(cubit.state.options, isEmpty);
      await store.dispose();
    });

    test(
      'buying a plan the store did not send fails plainly and rests',
      () async {
        final store = _Store([]);
        final cubit = build(store);
        await cubit.load();
        final statuses = <PaywallBuyStatus>[];
        final sub = cubit.stream.listen((s) => statuses.add(s.status));
        await cubit.buy();
        await sub.cancel();
        expect(store.purchased, isEmpty);
        expect(store.reads, 2, reason: 'one read to open, one before failing');
        expect(statuses, [
          PaywallBuyStatus.purchasing,
          PaywallBuyStatus.failed,
        ]);
        expect(
          cubit.state.messageKey,
          LocaleKeys.paywall_kit_store_not_ready,
        );
        expect(
          LocaleKeys.paywall_kit_store_not_ready.tr(),
          'The store is not ready yet. Try again later.',
        );
        expect(cubit.state.canBuy, isTrue, reason: 'back on the paywall');
        expect(cubit.state.isBusy, isFalse);
        await store.dispose();
      },
    );

    test(
      'a store that has the plan by the time it is bought sells it',
      () async {
        final store = _Store([]);
        final cubit = build(store);
        await cubit.load();
        store.packages = [_storeYearly, _storeMonthly];
        await cubit.buy();
        expect(store.purchased, [r'$rc_annual']);
        expect(
          cubit.state.messageKey,
          isNot(LocaleKeys.paywall_kit_store_not_ready),
        );
      },
    );

    test('a plan the store did send is bought with no second read', () async {
      final store = _Store([_storeYearly, _storeMonthly]);
      final cubit = build(store);
      await cubit.load();
      await cubit.buy();
      expect(store.reads, 1);
      expect(store.purchased, [r'$rc_annual']);
    });
  });

  group('Pro prices', () {
    late FakePacksApi api;
    late MemoryProPackStore packs;
    late FakeProPackShop shop;

    ProPaywallBuyCubit build({PriceBook? priceBook}) => ProPaywallBuyCubit(
      access: ProPackAccess(
        api: api,
        store: packs,
        readAccountId: () async => 'acc_1',
        override: const NoProPackOverride(),
        now: () => DateTime.utc(2026, 10, 14, 9),
      ),
      shop: shop,
      priceBook: priceBook ?? book,
      wait: (_) async {},
    );

    setUp(() {
      api = FakePacksApi();
      packs = MemoryProPackStore();
      shop = FakeProPackShop();
    });

    test('the store sends an offer: its price shows', () async {
      shop.offers = const [
        ProPackOffer(handle: 'a', title: 'Store title', price: 'S-PRO'),
      ];
      final cubit = build();
      await cubit.load();
      expect(cubit.state.options.single.price, 'S-PRO');
      expect(cubit.state.options.single.title, 'Store title');
    });

    test(
      'the store sends nothing: the book prices Pro and the button is live',
      () async {
        final cubit = build();
        await cubit.load();
        expect(cubit.state.status, PaywallBuyStatus.ready);
        expect(cubit.state.canBuy, isTrue);
        expect(cubit.state.options.single.price, r'$49.99');
        expect(cubit.state.options.single.title, 'Pro');
      },
    );

    test('the store and the book are both empty: not on sale', () async {
      final cubit = build(priceBook: const EmptyPriceBook());
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
    });

    test('buying with no store offer fails plainly, writes nothing down and '
        'rests', () async {
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(shop.bought, isEmpty);
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_store_not_ready);
      expect(cubit.state.canBuy, isTrue);
      expect(packs.writes, 0);
    });

    test('an offer that arrives before the buy is bought', () async {
      final cubit = build();
      await cubit.load();
      shop.offers = const [
        ProPackOffer(handle: 'a', title: 'Store title', price: 'S-PRO'),
      ];
      await cubit.buy();
      expect(shop.bought, ['a']);
    });
  });

  group('the store not being ready', () {
    const buying = PaywallBuyState(
      product: PaywallProduct.hosted,
      status: PaywallBuyStatus.purchasing,
    );

    test('sounds like a store problem', () {
      final after = afterStore(buying, PaywallStoreResult.notReady);
      expect(
        paywallBuyCue(buying, after, action: PaywallBuyAction.purchase),
        PaywallCue.error,
      );
    });

    test('with no plan to rest on, rests as not on sale', () {
      final after = afterStore(buying, PaywallStoreResult.notReady);
      expect(after.status, PaywallBuyStatus.notOnSale);
    });
  });

  group('the demo buy model', () {
    test("shows the book's prices for Hosted", () async {
      final cubit = DemoPaywallBuyCubit(
        PaywallProduct.hosted,
        priceBook: book,
      );
      await cubit.load();
      expect(cubit.state.options.map((o) => o.price), [r'$39.99', r'$4.99']);
      expect(cubit.state.options.first.perPeriodLine, contains(r'$3.33'));
      expect(cubit.state.options.first.savingLabel, 'Save 33%');
    });

    test("shows the book's price for Pro", () async {
      final cubit = DemoPaywallBuyCubit(PaywallProduct.pro, priceBook: book);
      await cubit.load();
      expect(cubit.state.options.single.price, r'$49.99');
    });

    test('with an empty book it is not on sale', () async {
      final cubit = DemoPaywallBuyCubit(
        PaywallProduct.hosted,
        priceBook: const EmptyPriceBook(),
      );
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
    });

    test('with no book given it reads the book the app runs on', () async {
      final cubit = DemoPaywallBuyCubit(PaywallProduct.hosted);
      await cubit.load();
      expect(cubit.state.options.first.price, r'$39.99');
    });
  });
}
