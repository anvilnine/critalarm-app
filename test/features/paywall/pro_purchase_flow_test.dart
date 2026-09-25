import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _package = Package(
  'yearly',
  PackageType.annual,
  StoreProduct('yearly', 'Yearly Pro', 'Yearly Pro', 19.99, r'$19.99', 'USD'),
  PresentedOfferingContext('default', null, null),
);

const _known = DeviceIdentity(deviceId: 'dev-1', accountId: 'acct-1');

void main() {
  group('PlanChanges', () {
    test('tells listeners only when the store answer changes', () {
      final plan = PlanChanges();
      var calls = 0;
      plan
        ..addListener(() => calls++)
        ..setStoreSaysPro(value: false)
        ..setStoreSaysPro(value: true)
        ..setStoreSaysPro(value: true);
      expect(calls, 1);
      expect(plan.storeSaysPro, isTrue);
    });
  });

  group('AccountAccess with the store', () {
    test('a store purchase counts as Pro before the server knows', () {
      final plan = PlanChanges()..setStoreSaysPro(value: true);
      final access = AccountAccess(_known, planChanges: plan);
      expect(access.isRegisteredPaid, isFalse);
      expect(access.isPaid, isTrue);
      expect(access.isProPending, isTrue);
    });

    test('is not pending once the server says Pro', () {
      final plan = PlanChanges()..setStoreSaysPro(value: true);
      const identity = DeviceIdentity(
        deviceId: 'dev-1',
        accountId: 'acct-1',
        tier: 'hosted',
      );
      final access = AccountAccess(identity, planChanges: plan);
      expect(access.isPaid, isTrue);
      expect(access.isProPending, isFalse);
    });

    test('stays free with neither the store nor the server', () {
      final access = AccountAccess(_known, planChanges: PlanChanges());
      expect(access.isPaid, isFalse);
      expect(access.isProPending, isFalse);
    });
  });

  group('PaywallCubit after a purchase', () {
    test(
      'keeps asking the server even when the store already says Pro',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = DeviceIdentityStore(
          await SharedPreferences.getInstance(),
        );
        final repository = InMemorySubscriptionRepository();
        addTearDown(repository.dispose);
        var registrations = 0;
        final cubit = PaywallCubit(
          purchasePackageUsecase: PurchasePackageUsecase(repository),
          identityStore: store,
          planChanges: PlanChanges()..setStoreSaysPro(value: true),
          tierRefreshWaits: const [Duration.zero, Duration.zero],
          // The webhook never lands, so the server keeps saying free.
          refreshRegistration: () async => registrations++,
        );
        addTearDown(cubit.close);

        await cubit.upgradeToPro(_package);

        expect(registrations, 3);
        expect(cubit.state.isPro, isTrue);
      },
    );
  });

  group('ProStatusCubit', () {
    test('reads again when the plan changes', () async {
      final plan = PlanChanges();
      var paid = false;
      final cubit = ProStatusCubit(
        readIsPaid: () async => paid,
        planChanges: plan,
        identityChanges: AccountIdentityChanges(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, isFalse);

      paid = true;
      plan.bump();
      await pumpEventQueue();
      expect(cubit.state, isTrue);
    });

    test('shows no badge when the read fails', () async {
      final cubit = ProStatusCubit(
        readIsPaid: () async => throw StateError('offline'),
        planChanges: PlanChanges(),
        identityChanges: AccountIdentityChanges(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, isFalse);
    });
  });
}
