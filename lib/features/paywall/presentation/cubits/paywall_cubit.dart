import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing Pro upgrade and purchase restoration interactions.
class PaywallCubit extends Cubit<PaywallState> {
  PaywallCubit({TelemetryGate? telemetryGate})
    : _telemetryGate = telemetryGate,
      super(
        PaywallState(
          paywallEnabled: telemetryGate?.paywallEnabled ?? false,
        ),
      );

  final TelemetryGate? _telemetryGate;

  bool get isPaywallEnabled =>
      _telemetryGate?.isPaywallEnabled ?? state.paywallEnabled;

  bool get paywallEnabled => isPaywallEnabled;

  Future<void> upgradeToPro() async {
    emit(state.copyWith(status: PaywallStatus.loading, clearFeedback: true));
    // Simulates purchase flow for paywall shell
    emit(
      state.copyWith(
        status: PaywallStatus.success,
        isPro: true,
        feedbackMessage: 'Upgraded to Crit Alarm Pro',
      ),
    );
  }

  Future<void> restorePurchases() async {
    emit(state.copyWith(status: PaywallStatus.loading, clearFeedback: true));
    // Simulates restore purchases flow for paywall shell
    emit(
      state.copyWith(
        status: PaywallStatus.success,
        feedbackMessage: 'Purchases restored successfully',
      ),
    );
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }
}
