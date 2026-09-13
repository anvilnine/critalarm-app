import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaywallCubit', () {
    test('initial state has default paywall shell values', () {
      final cubit = PaywallCubit();

      expect(cubit.state.status, PaywallStatus.initial);
      expect(cubit.state.isPro, isFalse);
      expect(cubit.state.feedbackMessage, isNull);
      expect(cubit.state.paywallEnabled, isFalse);
      expect(cubit.isPaywallEnabled, isFalse);
      expect(cubit.paywallEnabled, isFalse);
    });

    test('initial state reads paywallEnabled from TelemetryGate', () {
      const gate = NoopTelemetryGate(paywallEnabled: true);
      final cubit = PaywallCubit(telemetryGate: gate);

      expect(cubit.state.paywallEnabled, isTrue);
      expect(cubit.isPaywallEnabled, isTrue);
      expect(cubit.paywallEnabled, isTrue);
    });

    blocTest<PaywallCubit, PaywallState>(
      'upgradeToPro emits loading then success with isPro true and feedback',
      build: PaywallCubit.new,
      act: (cubit) => cubit.upgradeToPro(),
      expect: () => [
        const PaywallState(status: PaywallStatus.loading),
        const PaywallState(
          status: PaywallStatus.success,
          isPro: true,
          feedbackMessage: 'Upgraded to Crit Alarm Pro',
        ),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'restorePurchases emits loading then success with feedback message',
      build: PaywallCubit.new,
      act: (cubit) => cubit.restorePurchases(),
      expect: () => [
        const PaywallState(status: PaywallStatus.loading),
        const PaywallState(
          status: PaywallStatus.success,
          feedbackMessage: 'Purchases restored.',
        ),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'clearFeedback clears the feedback message',
      build: PaywallCubit.new,
      seed: () => const PaywallState(
        status: PaywallStatus.success,
        feedbackMessage: 'Test feedback',
      ),
      act: (cubit) => cubit.clearFeedback(),
      expect: () => [
        const PaywallState(status: PaywallStatus.success),
      ],
    );
  });
}
