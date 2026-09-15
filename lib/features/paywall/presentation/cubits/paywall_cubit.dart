import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/check_pro_entitlement_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Cubit managing Pro upgrade, offerings, and purchase restoration.
class PaywallCubit extends Cubit<PaywallState> {
  PaywallCubit({
    this.telemetryGate,
    this.identityStore,
    this.refreshRegistration,
    this.checkProEntitlementUsecase,
    this.getOfferingsUsecase,
    this.purchasePackageUsecase,
    this.restorePurchasesUsecase,
    this.getCustomerInfoUsecase,
    SubscriptionRepository? subscriptionRepository,
  }) : super(
         PaywallState(
           paywallEnabled: telemetryGate?.paywallEnabled ?? false,
         ),
       ) {
    if (subscriptionRepository != null) {
      _customerInfoSubscription = subscriptionRepository.customerInfoStream
          .listen(_onCustomerInfoUpdated);
    }
  }

  final Future<void> Function()? refreshRegistration;
  final TelemetryGate? telemetryGate;
  final DeviceIdentityStore? identityStore;
  Future<bool> _isPaid() async =>
      AccountAccess(await identityStore?.readOrCreate()).isPaid;
  final CheckProEntitlementUsecase? checkProEntitlementUsecase;
  final GetOfferingsUsecase? getOfferingsUsecase;
  final PurchasePackageUsecase? purchasePackageUsecase;
  final RestorePurchasesUsecase? restorePurchasesUsecase;
  final GetCustomerInfoUsecase? getCustomerInfoUsecase;
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;

  bool get isPaywallEnabled =>
      telemetryGate?.isPaywallEnabled ?? state.paywallEnabled;

  bool get paywallEnabled => isPaywallEnabled;

  /// Loads current entitlement status, customer info, and available offerings.
  Future<void> loadSubscriptionData() async {
    if (checkProEntitlementUsecase == null && getOfferingsUsecase == null) {
      return;
    }

    emit(state.copyWith(status: PaywallStatus.loading, clearError: true));

    final isPro = await _isPaid();

    var customerInfo = state.customerInfo;
    if (getCustomerInfoUsecase != null) {
      final infoResult = await getCustomerInfoUsecase!(const NoParams());
      infoResult.fold(
        (info) => customerInfo = info,
        (_) {},
      );
    }

    var offerings = state.offerings;
    var selectedPackage = state.selectedPackage;
    var selectedTier = state.selectedTier;

    if (getOfferingsUsecase != null) {
      final offeringsResult = await getOfferingsUsecase!(const NoParams());
      offeringsResult.fold(
        (loadedOfferings) {
          offerings = loadedOfferings;
          final currentOffering = loadedOfferings.current;
          if (currentOffering != null &&
              currentOffering.availablePackages.isNotEmpty) {
            final match =
                _findPackageForTier(currentOffering, selectedTier) ??
                currentOffering.annual ??
                currentOffering.availablePackages.first;
            selectedPackage = match;
            selectedTier = SubscriptionTier.fromPackage(match) ?? selectedTier;
          }
        },
        (_) {},
      );
    }

    emit(
      state.copyWith(
        status: PaywallStatus.initial,
        isPro: isPro,
        customerInfo: customerInfo,
        offerings: offerings,
        selectedPackage: selectedPackage,
        selectedTier: selectedTier,
      ),
    );
  }

  /// Selects a subscription tier and updates the chosen package.
  void selectTier(SubscriptionTier tier) {
    Package? matchingPackage;
    final currentOffering = state.offerings?.current;
    if (currentOffering != null) {
      matchingPackage = _findPackageForTier(currentOffering, tier);
    }

    emit(
      state.copyWith(
        selectedTier: tier,
        selectedPackage: matchingPackage ?? state.selectedPackage,
        clearError: true,
      ),
    );
  }

  /// Initiates Pro upgrade for the selected or explicitly passed package.
  Future<void> upgradeToPro([Package? package]) async {
    emit(
      state.copyWith(
        status: PaywallStatus.loading,
        clearFeedback: true,
        clearError: true,
      ),
    );

    final targetPackage = package ?? state.selectedPackage;

    if (purchasePackageUsecase != null && targetPackage != null) {
      final result = await purchasePackageUsecase!(targetPackage);

      await result.fold(
        (customerInfo) async {
          await _refreshRegistration();
          final isPro = await _isPaid();
          emit(
            state.copyWith(
              status: PaywallStatus.success,
              isPro: isPro,
              customerInfo: customerInfo,
              feedbackMessage: isPro
                  ? LocaleKeys.paywall_feedback_upgraded.tr()
                  : LocaleKeys.paywall_feedback_purchase_completed.tr(),
            ),
          );
        },
        (failure) {
          if (failure is UnexpectedFailure &&
              (failure.message?.contains('cancelled') ?? false)) {
            emit(state.copyWith(status: PaywallStatus.initial));
            return;
          }
          emit(
            state.copyWith(
              status: PaywallStatus.failure,
              errorMessage: _errorMessageFromFailure(failure),
            ),
          );
        },
      );
      return;
    }

    // No offering is available to purchase.
    emit(
      state.copyWith(
        status: PaywallStatus.failure,
        errorMessage: 'No purchase is available.',
      ),
    );
  }

  /// Restores existing purchases.
  Future<void> restorePurchases() async {
    emit(
      state.copyWith(
        status: PaywallStatus.loading,
        clearFeedback: true,
        clearError: true,
      ),
    );

    if (restorePurchasesUsecase != null) {
      final result = await restorePurchasesUsecase!(const NoParams());

      await result.fold(
        (customerInfo) async {
          await _refreshRegistration();
          final isPro = await _isPaid();
          emit(
            state.copyWith(
              status: PaywallStatus.success,
              isPro: isPro,
              customerInfo: customerInfo,
              feedbackMessage: isPro
                  ? LocaleKeys.paywall_feedback_restored.tr()
                  : LocaleKeys.paywall_feedback_no_active_restored.tr(),
            ),
          );
        },
        (failure) {
          emit(
            state.copyWith(
              status: PaywallStatus.failure,
              errorMessage: _errorMessageFromFailure(failure),
            ),
          );
        },
      );
      return;
    }

    // No offering is available to purchase.
    emit(
      state.copyWith(
        status: PaywallStatus.success,
        feedbackMessage: LocaleKeys.paywall_feedback_purchases_restored.tr(),
      ),
    );
  }

  Future<void> _refreshRegistration() async {
    try {
      await refreshRegistration?.call();
    } on Object catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    }
  }

  /// Presents the native RevenueCat Paywall UI.
  Future<PaywallResult> presentNativePaywall({Offering? offering}) async {
    final result = await RevenueCatUI.presentPaywall(
      offering: offering ?? state.offerings?.current,
      displayCloseButton: true,
    );

    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      await _refreshRegistration();
      await loadSubscriptionData();
    }
    return result;
  }

  /// Presents the native RevenueCat Customer Center UI.
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter(
      onRestoreCompleted: (info) async {
        await _refreshRegistration();
        _onCustomerInfoUpdated(info);
      },
    );
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    emit(state.copyWith(customerInfo: customerInfo));
    unawaited(_refreshTier());
  }

  Future<void> _refreshTier() async {
    final isPro = await _isPaid();
    if (!isClosed) emit(state.copyWith(isPro: isPro));
  }

  Package? _findPackageForTier(Offering offering, SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.lifetime:
        return offering.lifetime ??
            offering.availablePackages.firstWhere(
              (p) =>
                  SubscriptionTier.fromPackage(p) == SubscriptionTier.lifetime,
              orElse: () => offering.availablePackages.first,
            );
      case SubscriptionTier.yearly:
        return offering.annual ??
            offering.availablePackages.firstWhere(
              (p) => SubscriptionTier.fromPackage(p) == SubscriptionTier.yearly,
              orElse: () => offering.availablePackages.first,
            );
      case SubscriptionTier.monthly:
        return offering.monthly ??
            offering.availablePackages.firstWhere(
              (p) =>
                  SubscriptionTier.fromPackage(p) == SubscriptionTier.monthly,
              orElse: () => offering.availablePackages.first,
            );
    }
  }

  String _errorMessageFromFailure(Failure failure) {
    if (failure is UnexpectedFailure && failure.message != null) {
      return failure.message!;
    }
    if (failure is UnsupportedFailure && failure.message != null) {
      return failure.message!;
    }
    if (failure is ConflictFailure && failure.message != null) {
      return failure.message!;
    }
    return LocaleKeys.paywall_error_subscription_failed.tr();
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() async {
    await _customerInfoSubscription?.cancel();
    return super.close();
  }
}
