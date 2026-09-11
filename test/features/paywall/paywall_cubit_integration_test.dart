import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/usecases/check_pro_entitlement_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('PaywallCubit with SubscriptionRepository', () {
    late InMemorySubscriptionRepository repository;
    late CheckProEntitlementUsecase checkProUsecase;
    late GetOfferingsUsecase getOfferingsUsecase;
    late PurchasePackageUsecase purchasePackageUsecase;
    late RestorePurchasesUsecase restorePurchasesUsecase;
    late GetCustomerInfoUsecase getCustomerInfoUsecase;

    const yearlyPackage = Package(
      'yearly',
      PackageType.annual,
      StoreProduct(
        'yearly',
        'Yearly Pro',
        'Yearly Pro',
        19.99,
        r'$19.99',
        'USD',
      ),
      PresentedOfferingContext('default', null, null),
    );

    const monthlyPackage = Package(
      'monthly',
      PackageType.monthly,
      StoreProduct(
        'monthly',
        'Monthly Pro',
        'Monthly Pro',
        2.99,
        r'$2.99',
        'USD',
      ),
      PresentedOfferingContext('default', null, null),
    );

    const defaultOffering = Offering(
      'default',
      'Standard Offerings',
      <String, Object>{},
      <Package>[yearlyPackage, monthlyPackage],
      annual: yearlyPackage,
      monthly: monthlyPackage,
    );

    const mockOfferings = Offerings(
      <String, Offering>{'default': defaultOffering},
      current: defaultOffering,
    );

    setUp(() {
      repository = InMemorySubscriptionRepository(offerings: mockOfferings);
      checkProUsecase = CheckProEntitlementUsecase(repository);
      getOfferingsUsecase = GetOfferingsUsecase(repository);
      purchasePackageUsecase = PurchasePackageUsecase(repository);
      restorePurchasesUsecase = RestorePurchasesUsecase(repository);
      getCustomerInfoUsecase = GetCustomerInfoUsecase(repository);
    });

    tearDown(() async {
      await repository.dispose();
    });

    PaywallCubit buildCubit() => PaywallCubit(
      checkProEntitlementUsecase: checkProUsecase,
      getOfferingsUsecase: getOfferingsUsecase,
      purchasePackageUsecase: purchasePackageUsecase,
      restorePurchasesUsecase: restorePurchasesUsecase,
      getCustomerInfoUsecase: getCustomerInfoUsecase,
      subscriptionRepository: repository,
    );

    test('selectTier updates selectedTier and finds matching package', () {
      final cubit = buildCubit()
        ..emit(
          const PaywallState(offerings: mockOfferings),
        )
        ..selectTier(SubscriptionTier.monthly);
      expect(cubit.state.selectedTier, equals(SubscriptionTier.monthly));
      expect(cubit.state.selectedPackage?.identifier, equals('monthly'));
    });

    blocTest<PaywallCubit, PaywallState>(
      'loadSubscriptionData loads offerings and initial entitlement status',
      build: buildCubit,
      act: (cubit) => cubit.loadSubscriptionData(),
      expect: () => [
        predicate<PaywallState>(
          (s) => s.status == PaywallStatus.loading,
        ),
        predicate<PaywallState>(
          (s) =>
              s.status == PaywallStatus.initial &&
              !s.isPro &&
              s.offerings != null &&
              s.selectedPackage?.identifier == 'yearly',
        ),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'upgradeToPro with real usecase purchases package and unlocks Pro',
      build: buildCubit,
      act: (cubit) => cubit.upgradeToPro(yearlyPackage),
      expect: () => [
        predicate<PaywallState>((s) => s.status == PaywallStatus.loading),
        predicate<PaywallState>((s) => s.isPro),
        predicate<PaywallState>(
          (s) =>
              s.status == PaywallStatus.success &&
              s.isPro &&
              s.feedbackMessage == 'Upgraded to Crit Alarm Pro',
        ),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'restorePurchases restores entitlement and sets feedback',
      build: buildCubit,
      act: (cubit) => cubit.restorePurchases(),
      expect: () => [
        predicate<PaywallState>((s) => s.status == PaywallStatus.loading),
        predicate<PaywallState>((s) => s.isPro),
        predicate<PaywallState>(
          (s) =>
              s.status == PaywallStatus.success &&
              s.isPro &&
              s.feedbackMessage == 'Crit Alarm Pro restored successfully',
        ),
      ],
    );
  });
}
