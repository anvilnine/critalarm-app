import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hosted_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/pro_paywall_buy_cubit.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../pro_pack/pro_pack_fakes.dart';

// Made-up store products. No plan costs these.
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
const _offering = Offering(
  'default',
  'Default',
  <String, Object>{},
  <Package>[_yearlyPackage, _monthlyPackage],
  annual: _yearlyPackage,
  monthly: _monthlyPackage,
);
const _offerings = Offerings(
  <String, Offering>{'default': _offering},
  current: _offering,
);

/// A store whose purchase and restore answer what the test scripted.
class _Store extends InMemorySubscriptionRepository {
  _Store() : super(offerings: _offerings);

  Failure? purchaseFailure;
  Failure? restoreFailure;

  /// Whether a restore finds Hosted on the store account.
  bool restoreFindsHosted = true;
  final List<String> purchased = [];
  int restores = 0;

  @override
  Future<AppResult<CustomerInfo>> purchasePackage(Package package) async {
    purchased.add(package.identifier);
    final failure = purchaseFailure;
    if (failure != null) return failure.toFailure();
    return super.purchasePackage(package);
  }

  @override
  Future<AppResult<CustomerInfo>> restorePurchases() async {
    restores++;
    final failure = restoreFailure;
    if (failure != null) return failure.toFailure();
    return restoreFindsHosted ? super.restorePurchases() : getCustomerInfo();
  }
}

const _offer = ProPackOffer(handle: 'a', title: 'Store title A', price: 'P1');
const _unknown = PacksRefreshAnswer(confirmed: false, packs: []);
const _readEmpty = PacksRefreshAnswer(confirmed: true, packs: []);
const _held = PacksRefreshAnswer(confirmed: true, packs: [proPack]);

void main() {
  group('Hosted', () {
    late _Store store;
    late bool storeSaysPaid;
    late List<bool> serverSaysPaid;
    late int refreshes;
    late List<Duration> waits;

    HostedPaywallBuyCubit build() => HostedPaywallBuyCubit(
      getOfferings: GetOfferingsUsecase(store),
      purchasePackage: PurchasePackageUsecase(store),
      restorePurchases: RestorePurchasesUsecase(store),
      readIsPaid: () async => storeSaysPaid,
      // One answer per read of the plan. The last one repeats.
      readIsRegisteredPaid: () async => serverSaysPaid.length > 1
          ? serverSaysPaid.removeAt(0)
          : serverSaysPaid.first,
      refreshRegistration: () async => refreshes++,
      wait: (d) async => waits.add(d),
    );

    Future<List<PaywallBuyStatus>> seen(
      HostedPaywallBuyCubit cubit,
      Future<void> Function() act,
    ) async {
      final statuses = <PaywallBuyStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));
      await act();
      await settle();
      await sub.cancel();
      return statuses;
    }

    setUp(() {
      store = _Store();
      storeSaysPaid = false;
      serverSaysPaid = [false];
      refreshes = 0;
      waits = [];
    });

    tearDown(() => store.dispose());

    test('opens with two options, yearly first and picked', () async {
      final cubit = build();
      expect(cubit.state.status, PaywallBuyStatus.loading);
      await cubit.load();
      expect(cubit.state.product, PaywallProduct.hosted);
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.options.map((o) => o.id), [
        PaywallPlanOption.yearlyId,
        PaywallPlanOption.monthlyId,
      ]);
      expect(cubit.state.selectedId, PaywallPlanOption.yearlyId);
      expect(cubit.state.selected!.price, 'Y-PRICE');
      expect(cubit.state.selected!.savingLabel, 'Save 33%');
    });

    test('an account that is already paid opens on done', () async {
      storeSaysPaid = true;
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('a store with no offering is not on sale', () async {
      final empty = InMemorySubscriptionRepository();
      final cubit = HostedPaywallBuyCubit(
        getOfferings: GetOfferingsUsecase(empty),
        purchasePackage: PurchasePackageUsecase(empty),
        restorePurchases: RestorePurchasesUsecase(empty),
        readIsPaid: () async => false,
        readIsRegisteredPaid: () async => false,
        refreshRegistration: () async {},
      );
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
      expect(cubit.state.canRestore, isTrue);
      await empty.dispose();
    });

    test('select moves the pick and ignores an unknown id', () async {
      final cubit = build();
      await cubit.load();
      cubit.select(PaywallPlanOption.monthlyId);
      expect(cubit.state.selectedId, PaywallPlanOption.monthlyId);
      cubit.select('weekly');
      expect(cubit.state.selectedId, PaywallPlanOption.monthlyId);
      expect(cubit.state.status, PaywallBuyStatus.ready);
    });

    test('buy purchases the picked plan and ends on done once the server '
        'says paid', () async {
      serverSaysPaid = [false, true];
      final cubit = build();
      await cubit.load();
      cubit.select(PaywallPlanOption.monthlyId);
      final statuses = await seen(cubit, cubit.buy);
      expect(store.purchased, [r'$rc_monthly']);
      expect(statuses, [
        PaywallBuyStatus.purchasing,
        PaywallBuyStatus.checking,
        PaywallBuyStatus.done,
      ]);
      expect(refreshes, 2);
      expect(waits, [const Duration(seconds: 2)]);
    });

    test('the store saying paid is enough to say done at once', () async {
      final cubit = build();
      await cubit.load();
      storeSaysPaid = true;
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.done);
      expect(store.purchased, [r'$rc_annual']);
    });

    test('a purchase nobody confirms pauses, and is never a failure', () async {
      final cubit = build();
      await cubit.load();
      final statuses = await seen(cubit, cubit.buy);
      expect(statuses, isNot(contains(PaywallBuyStatus.failed)));
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_feedback_purchase_completed,
      );
      expect(refreshes, HostedPaywallBuyCubit.defaultConfirmWaits.length);

      serverSaysPaid = [true];
      await cubit.checkAgain();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('backing out of the store rests on the options, silently', () async {
      store.purchaseFailure = Failure.unexpected(
        message: LocaleKeys.purchase_errors_purchase_cancelled.tr(),
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.messageKey, isNull);
      expect(refreshes, 0);
    });

    test('a payment the store is holding shows the pending line with Check '
        'again, and is never a failure', () async {
      store.purchaseFailure = Failure.unexpected(
        message: LocaleKeys.purchase_errors_payment_pending.tr(),
      );
      final cubit = build();
      await cubit.load();
      final statuses = await seen(cubit, cubit.buy);
      expect(statuses, [
        PaywallBuyStatus.purchasing,
        PaywallBuyStatus.checking,
      ]);
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
      expect(cubit.state.canBuy, isFalse);
      expect(cubit.state.canRestore, isTrue);
      // Nothing was read: the store has not taken the money yet.
      expect(refreshes, 0);

      // The button does not go back to the store.
      await cubit.buy();
      expect(store.purchased, [r'$rc_annual']);
    });

    test('check again on a held payment reads the plan, and still says '
        'pending while nobody confirms it', () async {
      store.purchaseFailure = Failure.unexpected(
        message: LocaleKeys.purchase_errors_payment_pending.tr(),
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();

      final statuses = await seen(cubit, cubit.checkAgain);
      expect(statuses, isNot(contains(PaywallBuyStatus.failed)));
      expect(refreshes, HostedPaywallBuyCubit.defaultConfirmWaits.length);
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      // Never the line that says the payment went through.
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
      expect(store.purchased, hasLength(1));

      serverSaysPaid = [true];
      await cubit.checkAgain();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('a purchase after a held one pauses on its own line again', () async {
      store.purchaseFailure = Failure.unexpected(
        message: LocaleKeys.purchase_errors_payment_pending.tr(),
      );
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      store.restoreFindsHosted = false;
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_kit_nothing_to_restore,
      );

      store.purchaseFailure = null;
      await cubit.buy();
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_feedback_purchase_completed,
      );
    });

    test(
      'a store problem is failed with a line, and buy works again',
      () async {
        store.purchaseFailure = const Failure.unexpected(message: 'boom');
        final cubit = build();
        await cubit.load();
        await cubit.buy();
        expect(cubit.state.status, PaywallBuyStatus.failed);
        expect(cubit.state.messageKey, LocaleKeys.paywall_kit_failed);

        store.purchaseFailure = null;
        storeSaysPaid = true;
        await cubit.buy();
        expect(cubit.state.status, PaywallBuyStatus.done);
      },
    );

    test('a restore that finds nothing says so and asks nobody else', () async {
      store.restoreFindsHosted = false;
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(store.restores, 1);
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_kit_nothing_to_restore,
      );
      expect(refreshes, 0);
    });

    test('a restore that finds Hosted ends on done', () async {
      serverSaysPaid = [true];
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('nothing can be bought twice at once or after done', () async {
      storeSaysPaid = true;
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      await cubit.restore();
      cubit.select(PaywallPlanOption.monthlyId);
      expect(store.purchased, isEmpty);
      expect(store.restores, 0);
      expect(cubit.state.status, PaywallBuyStatus.done);
    });
  });

  group('Pro', () {
    late FakePacksApi api;
    late MemoryProPackStore packs;
    late FakeProPackShop shop;
    late List<Duration> waits;
    late DateTime now;

    ProPackAccess access() => ProPackAccess(
      api: api,
      store: packs,
      readAccountId: () async => 'acc_1',
      override: const NoProPackOverride(),
      now: () => now,
    );

    ProPaywallBuyCubit build([ProPackAccess? a]) => ProPaywallBuyCubit(
      access: a ?? access(),
      shop: shop,
      wait: (d) async {
        waits.add(d);
        now = now.add(d);
      },
    );

    setUp(() {
      api = FakePacksApi();
      packs = MemoryProPackStore();
      shop = FakeProPackShop(offers: const [_offer]);
      waits = [];
      now = DateTime.utc(2026, 10, 7, 9);
    });

    test('opens with the store title and price, as they come', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.product, PaywallProduct.pro);
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.options.single.title, 'Store title A');
      expect(cubit.state.options.single.price, 'P1');
      expect(cubit.state.selectedId, 'a');
    });

    test('nothing on sale: not on sale, with Restore', () async {
      shop.offers = const [];
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.notOnSale);
      expect(cubit.state.canRestore, isTrue);
      expect(cubit.state.canBuy, isFalse);
    });

    test('a pack already held opens on done', () async {
      final a = access();
      await a.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      final cubit = build(a);
      await cubit.load();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('bought and confirmed by the relay: done', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(shop.bought, ['a']);
      expect(cubit.state.status, PaywallBuyStatus.done);
      expect(packs.pending, isNull);
    });

    test('the purchase is written down before the store is asked', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      bool? wasPending;
      shop.onBuy = () => wasPending = packs.pending != null;
      await cubit.buy();
      expect(wasPending, isTrue);
    });

    test('bought, and the relay says nothing: checking, then paused, never '
        'failed and never "no pack"', () async {
      api.refreshes = [_unknown];
      final cubit = build();
      await cubit.load();
      final statuses = <PaywallBuyState>[];
      final sub = cubit.stream.listen(statuses.add);
      await cubit.buy();
      await settle();
      await sub.cancel();
      for (final state in statuses) {
        expect(
          state.status,
          isIn([PaywallBuyStatus.purchasing, PaywallBuyStatus.checking]),
          reason: '$state',
        );
      }
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_paused);
      expect(waits, ProPaywallBuyCubit.defaultConfirmWaits.skip(1));
    });

    test(
      'bought, and the relay read an empty store: still asks again',
      () async {
        api.refreshes = [_readEmpty, _readEmpty, _held];
        final cubit = build();
        await cubit.load();
        await cubit.buy();
        expect(cubit.state.status, PaywallBuyStatus.done);
        expect(api.refreshCalls, 3);
      },
    );

    test('check again asks once more and can end on done', () async {
      api.refreshes = [_unknown];
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.isPaused, isTrue);
      now = now.add(const Duration(minutes: 2));
      api
        ..refreshes = [_held]
        ..refreshCalls = 0;
      await cubit.checkAgain();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('backing out forgets the pending purchase and says nothing', () async {
      shop.buyResult = ProPackStoreResult.cancelled;
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(cubit.state.messageKey, isNull);
      expect(packs.pending, isNull);
      expect(api.refreshCalls, 0);
    });

    test('a store problem is failed with a line', () async {
      shop.buyResult = ProPackStoreResult.problem;
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_failed);
      expect(api.refreshCalls, 0);
    });

    test('a store problem keeps the purchase written down', () async {
      shop.buyResult = ProPackStoreResult.problem;
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      expect(cubit.state.status, PaywallBuyStatus.failed);
      expect(cubit.state.isPaused, isFalse);
      expect(packs.pending, isNotNull);
    });

    test('a payment the store is holding shows the pending line with Check '
        'again, and is never a failure', () async {
      shop.buyResult = ProPackStoreResult.pending;
      final cubit = build();
      await cubit.load();
      final statuses = <PaywallBuyStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));
      await cubit.buy();
      await settle();
      await sub.cancel();
      expect(statuses, [
        PaywallBuyStatus.purchasing,
        PaywallBuyStatus.checking,
      ]);
      expect(cubit.state.isPaused, isTrue);
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
      expect(cubit.state.canBuy, isFalse);
      expect(cubit.state.canRestore, isTrue);
      // Nothing was asked: the store has not taken the money yet.
      expect(api.refreshCalls, 0);
      // The purchase stays written down for the next launch.
      expect(packs.pending, isNotNull);

      // The button does not go back to the store.
      await cubit.buy();
      expect(shop.bought, ['a']);
    });

    test('check again on a held payment asks the relay, and still says '
        'pending while nobody confirms it', () async {
      shop.buyResult = ProPackStoreResult.pending;
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.load();
      await cubit.buy();

      await cubit.checkAgain();
      // A store read with nothing on it is not a no while a payment is held.
      expect(api.refreshCalls, ProPaywallBuyCubit.defaultConfirmWaits.length);
      expect(cubit.state.status, PaywallBuyStatus.checking);
      expect(cubit.state.isPaused, isTrue);
      // Never the line that says the store is done.
      expect(
        cubit.state.messageKey,
        LocaleKeys.purchase_errors_payment_pending,
      );
      expect(shop.bought, hasLength(1));
      expect(packs.pending, isNotNull);

      now = now.add(const Duration(minutes: 2));
      api
        ..refreshes = [_held]
        ..refreshCalls = 0;
      await cubit.checkAgain();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('a purchase after a held one pauses on its own line again', () async {
      shop.buyResult = ProPackStoreResult.pending;
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.load();
      await cubit.buy();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.ready);

      now = now.add(const Duration(minutes: 2));
      shop.buyResult = ProPackStoreResult.done;
      api
        ..refreshes = [_unknown]
        ..refreshCalls = 0;
      await cubit.buy();
      expect(cubit.state.isPaused, isTrue);
      expect(cubit.state.messageKey, LocaleKeys.paywall_kit_paused);
    });

    test('a restore the relay reads as empty: nothing to restore', () async {
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(shop.restores, 1);
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_kit_nothing_to_restore,
      );
      expect(api.refreshCalls, 1);
    });

    test('a restore that finds the pack: done', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('restore works with nothing on sale', () async {
      shop.offers = const [];
      api.refreshes = [_held];
      final cubit = build();
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });

    test('the relay saying held through another door ends on done', () async {
      final a = access();
      final cubit = build(a);
      await cubit.load();
      await a.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      await settle();
      expect(cubit.state.status, PaywallBuyStatus.done);
    });
  });

  group('a build that skips the store', () {
    DemoPaywallBuyCubit build(
      PaywallProduct product, {
      PaywallBuyStatus? startAs,
    }) => DemoPaywallBuyCubit(
      product,
      startAs: startAs,
      stepTime: Duration.zero,
    );

    test('draws two Hosted options and one Pro option', () async {
      final hosted = build(PaywallProduct.hosted);
      await hosted.load();
      expect(hosted.state.status, PaywallBuyStatus.ready);
      expect(hosted.state.options, hasLength(2));
      expect(hosted.state.selectedId, PaywallPlanOption.yearlyId);

      final pro = build(PaywallProduct.pro);
      await pro.load();
      expect(pro.state.status, PaywallBuyStatus.ready);
      expect(pro.state.options, hasLength(1));
    });

    test('buy walks the states of a real purchase', () async {
      final cubit = build(PaywallProduct.pro);
      await cubit.load();
      final statuses = <PaywallBuyStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));
      await cubit.buy();
      await settle();
      await sub.cancel();
      expect(statuses, [
        PaywallBuyStatus.purchasing,
        PaywallBuyStatus.checking,
        PaywallBuyStatus.done,
      ]);
    });

    test('restore finds nothing', () async {
      final cubit = build(PaywallProduct.hosted);
      await cubit.load();
      await cubit.restore();
      expect(cubit.state.status, PaywallBuyStatus.ready);
      expect(
        cubit.state.messageKey,
        LocaleKeys.paywall_kit_nothing_to_restore,
      );
    });

    test('opens in the state it is asked for', () async {
      for (final status in PaywallBuyStatus.values) {
        if (status == PaywallBuyStatus.loading) continue;
        final cubit = build(PaywallProduct.hosted, startAs: status);
        await cubit.load();
        expect(cubit.state.status, status, reason: status.name);
      }
      final paused = build(
        PaywallProduct.pro,
        startAs: PaywallBuyStatus.checking,
      );
      await paused.load();
      expect(paused.state.isPaused, isTrue);
      final notOnSale = build(
        PaywallProduct.pro,
        startAs: PaywallBuyStatus.notOnSale,
      );
      await notOnSale.load();
      expect(notOnSale.state.options, isEmpty);
    });
  });
}
