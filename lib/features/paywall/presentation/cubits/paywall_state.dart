import 'package:flutter/foundation.dart';

enum PaywallStatus { initial, loading, success, failure }

/// State for PaywallScreen.
@immutable
class PaywallState {
  const PaywallState({
    this.status = PaywallStatus.initial,
    this.isPro = false,
    this.feedbackMessage,
  });

  final PaywallStatus status;
  final bool isPro;
  final String? feedbackMessage;

  PaywallState copyWith({
    PaywallStatus? status,
    bool? isPro,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return PaywallState(
      status: status ?? this.status,
      isPro: isPro ?? this.isPro,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywallState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          isPro == other.isPro &&
          feedbackMessage == other.feedbackMessage;

  @override
  int get hashCode => Object.hash(status, isPro, feedbackMessage);
}
