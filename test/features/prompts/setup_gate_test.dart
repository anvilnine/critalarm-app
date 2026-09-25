import 'package:critalarm/features/prompts/domain/setup_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool> gate({
    required bool onboardingDone,
    required bool tourSeen,
    bool tourActive = false,
  }) => SetupGate(
    isOnboardingDone: () async => onboardingDone,
    hasSeenTour: () => tourSeen,
    isTourActive: () => tourActive,
  ).isDone();

  test('done only once onboarding is finished and the tour seen', () async {
    expect(await gate(onboardingDone: false, tourSeen: false), isFalse);
    expect(await gate(onboardingDone: true, tourSeen: false), isFalse);
    expect(await gate(onboardingDone: false, tourSeen: true), isFalse);
    expect(await gate(onboardingDone: true, tourSeen: true), isTrue);
  });

  test('not done while a guide is up, so nothing shows over it', () async {
    expect(
      await gate(onboardingDone: true, tourSeen: true, tourActive: true),
      isFalse,
    );
  });

  test('with no guide callback, only onboarding and the tour count', () async {
    final done = await SetupGate(
      isOnboardingDone: () async => true,
      hasSeenTour: () => true,
    ).isDone();
    expect(done, isTrue);
  });
}
