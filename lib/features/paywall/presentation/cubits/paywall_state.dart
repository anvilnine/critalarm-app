import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum PaywallStatus { initial, loading, success, failure }

/// State for PaywallScreen and subscription interactions.
@immutable
class PaywallState {
  const PaywallState({
    this.status = PaywallStatus.initial,
    this.isPro = false,
    this.feedbackMessage,
    this.errorMessage,
    this.paywallEnabled = false,
    this.offerings,
    this.customerInfo,
    this.selectedTier = SubscriptionTier.yearly,
    this.selectedPackage,
  });

  final PaywallStatus status;
  final bool isPro;
  final String? feedbackMessage;
  final String? errorMessage;
  final bool paywallEnabled;
  final Offerings? offerings;
  final CustomerInfo? customerInfo;
  final SubscriptionTier selectedTier;
  final Package? selectedPackage;

  PaywallState copyWith({
    PaywallStatus? status,
    bool? isPro,
    String? feedbackMessage,
    String? errorMessage,
    bool? paywallEnabled,
    Offerings? offerings,
    CustomerInfo? customerInfo,
    SubscriptionTier? selectedTier,
    Package? selectedPackage,
    bool clearFeedback = false,
    bool clearError = false,
  }) {
    return PaywallState(
      status: status ?? this.status,
      isPro: isPro ?? this.isPro,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paywallEnabled: paywallEnabled ?? this.paywallEnabled,
      offerings: offerings ?? this.offerings,
      customerInfo: customerInfo ?? this.customerInfo,
      selectedTier: selectedTier ?? this.selectedTier,
      selectedPackage: selectedPackage ?? this.selectedPackage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywallState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          isPro == other.isPro &&
          feedbackMessage == other.feedbackMessage &&
          errorMessage == other.errorMessage &&
          paywallEnabled == other.paywallEnabled &&
          offerings == other.offerings &&
          customerInfo == other.customerInfo &&
          selectedTier == other.selectedTier &&
          selectedPackage == other.selectedPackage;

  @override
  int get hashCode => Object.hash(
    status,
    isPro,
    feedbackMessage,
    errorMessage,
    paywallEnabled,
    offerings,
    customerInfo,
    selectedTier,
    selectedPackage,
  );
}
