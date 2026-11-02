import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:flutter/foundation.dart';

enum PaywallStatus { initial, loading, success, failure }

/// State for subscription interactions.
@immutable
class PaywallState {
  const PaywallState({
    this.status = PaywallStatus.initial,
    this.isPro = false,
    this.feedbackMessage,
    this.errorMessage,
    this.offerings,
    this.customerInfo,
    this.selectedTier = SubscriptionTier.yearly,
    this.selectedPackage,
  });

  final PaywallStatus status;
  final bool isPro;
  final String? feedbackMessage;
  final String? errorMessage;
  final StoreOfferings? offerings;
  final StoreCustomer? customerInfo;
  final SubscriptionTier selectedTier;
  final StoreCatalogEntry? selectedPackage;

  PaywallState copyWith({
    PaywallStatus? status,
    bool? isPro,
    String? feedbackMessage,
    String? errorMessage,
    StoreOfferings? offerings,
    StoreCustomer? customerInfo,
    SubscriptionTier? selectedTier,
    StoreCatalogEntry? selectedPackage,
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
    offerings,
    customerInfo,
    selectedTier,
    selectedPackage,
  );
}
