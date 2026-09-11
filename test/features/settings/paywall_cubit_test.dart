import 'package:bloc_test/bloc_test.dart';
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
          feedbackMessage: 'Purchases restored successfully',
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
