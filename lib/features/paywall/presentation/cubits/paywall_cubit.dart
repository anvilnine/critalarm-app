import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
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
    this.getOfferingsUsecase,
    this.purchasePackageUsecase,
    this.restorePurchasesUsecase,
    this.getCustomerInfoUsecase,
    SubscriptionRepository? subscriptionRepository,
    ProOverride? proOverride,
    PaywallVariantOverride? variantOverride,
    this.analytics,
    List<Duration>? tierRefreshWaits,
  }) : _proOverride = proOverride ?? appProOverride,
       _variantOverride = variantOverride ?? appPaywallVariantOverride,
       _tierRefreshWaits = tierRefreshWaits ?? _defaultTierRefreshWaits,
       super(
         PaywallState(
           paywallEnabled: telemetryGate?.paywallEnabled ?? false,
           variant:
               (variantOverride ?? appPaywallVariantOverride).forcedVariant ??
               PaywallVariant.fromKey(telemetryGate?.paywallVariantKey),
         ),
       ) {
    if (subscriptionRepository != null) {
      _customerInfoSubscription = subscriptionRepository.customerInfoStream
          .listen(_onCustomerInfoUpdated);
    }
    _proOverride.listenable?.addListener(_onForceProChanged);
    _variantOverride.listenable?.addListener(_onVariantChanged);
  }

  /// How long to wait between the tries at re-reading the tier. Four waits
  /// after the first read, so five reads over about 30 seconds. Tests pass
  /// zeroes so they do not sit through it.
  static const _defaultTierRefreshWaits = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  final List<Duration> _tierRefreshWaits;
  final Future<void> Function()? refreshRegistration;
  final TelemetryGate? telemetryGate;
  final DeviceIdentityStore? identityStore;
  final ProOverride _proOverride;
  final PaywallVariantOverride _variantOverride;
  final PaywallAnalytics? analytics;
  Future<bool> _isPaid() async => AccountAccess(
    await identityStore?.readOrCreate(),
    proOverride: _proOverride,
  ).isPaid;

  /// The developer Force Pro switch moved, so the paywall has to say something
  /// different about this device.
  void _onForceProChanged() => unawaited(_refreshTier());

  /// The developer variant picker moved, so a different layout should be on
  /// screen. Counts as a fresh view, because that is what the reader sees.
  void _onVariantChanged() {
    final next = resolveVariant();
    if (next == state.variant) return;
    emit(state.copyWith(variant: next));
    unawaited(analytics?.viewed(variant: next));
  }

  /// The layout this device should show. A developer build wins, then Remote
  /// Config, then the default.
  PaywallVariant resolveVariant() =>
      _variantOverride.forcedVariant ??
      PaywallVariant.fromKey(telemetryGate?.paywallVariantKey);
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
    if (getOfferingsUsecase == null) {
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

    final variant = resolveVariant();

    emit(
      state.copyWith(
        status: PaywallStatus.initial,
        isPro: isPro,
        customerInfo: customerInfo,
        offerings: offerings,
        selectedPackage: selectedPackage,
        selectedTier: selectedTier,
        variant: variant,
      ),
    );

    if (!isPro) {
      await analytics?.viewed(variant: variant);
    }
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

    unawaited(
      analytics?.planSelected(
        variant: state.variant,
        plan: tier.analyticsKey,
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
    final plan = state.selectedTier.analyticsKey;
    final variant = state.variant;

    if (purchasePackageUsecase != null && targetPackage != null) {
      await analytics?.purchaseStarted(variant: variant, plan: plan);
      final result = await purchasePackageUsecase!(targetPackage);

      await result.fold(
        (customerInfo) async {
          await analytics?.purchaseCompleted(variant: variant, plan: plan);
          final isPro = await _refreshTierUntilPaid();
          if (isClosed) return;
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
          final cancelled =
              failure is UnexpectedFailure &&
              (failure.message?.contains('cancelled') ?? false);
          unawaited(
            analytics?.purchaseFailed(
              variant: variant,
              plan: plan,
              reason: cancelled ? 'cancelled' : 'failed',
            ),
          );
          if (cancelled) {
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
          final isPro = await _refreshTierUntilPaid();
          if (isClosed) return;
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
      if (!isClosed) emit(state.copyWith(errorMessage: error.toString()));
    }
  }

  /// Re-reads the tier from the server until it says this account is paid.
  ///
  /// The store tells the app a purchase went through before RevenueCat's
  /// webhook reaches our relay, and the tier only changes when that webhook
  /// lands (api.md §4.3). One read right after the purchase almost always
  /// still says `free`, so read again a few times. Gives up after the last
  /// wait and answers false, and the caller says so instead of claiming the
  /// upgrade happened.
  Future<bool> _refreshTierUntilPaid() async {
    await _refreshRegistration();
    if (await _isPaid()) return true;
    for (final wait in _tierRefreshWaits) {
      await Future<void>.delayed(wait);
      if (isClosed) return false;
      await _refreshRegistration();
      if (await _isPaid()) return true;
    }
    return false;
  }

  /// Presents the native RevenueCat Paywall UI.
  Future<PaywallResult> presentNativePaywall({Offering? offering}) async {
    final variant = state.variant;
    final plan = state.selectedTier.analyticsKey;
    await analytics?.purchaseStarted(variant: variant, plan: plan);

    final result = await RevenueCatUI.presentPaywall(
      offering: offering ?? state.offerings?.current,
      displayCloseButton: true,
    );

    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      await analytics?.purchaseCompleted(variant: variant, plan: plan);
      await _refreshTierUntilPaid();
      await loadSubscriptionData();
    } else {
      await analytics?.purchaseFailed(
        variant: variant,
        plan: plan,
        reason: result.name,
      );
    }
    return result;
  }

  /// Opens the RevenueCat dashboard paywall when that is the variant this
  /// device drew. Any other variant is drawn by this app and needs nothing.
  ///
  /// Called once after the screen loads. The Dart paywall stays underneath, so
  /// closing the RevenueCat sheet leaves a working screen rather than a blank
  /// one.
  Future<void> maybePresentHostedTemplate() async {
    if (state.variant != PaywallVariant.hostedTemplate || state.isPro) {
      return;
    }
    if (_hostedTemplateShown) return;
    _hostedTemplateShown = true;
    await presentNativePaywall();
  }

  bool _hostedTemplateShown = false;

  /// Presents the native RevenueCat Customer Center UI.
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter(
      onRestoreCompleted: (info) async {
        await _refreshTierUntilPaid();
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
    _proOverride.listenable?.removeListener(_onForceProChanged);
    _variantOverride.listenable?.removeListener(_onVariantChanged);
    await _customerInfoSubscription?.cancel();
    return super.close();
  }
}
