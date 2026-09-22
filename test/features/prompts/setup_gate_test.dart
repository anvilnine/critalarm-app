import 'package:critalarm/features/prompts/domain/setup_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool> gate({
    required bool onboardingDone,
    required bool tourSeen,
  }) => SetupGate(
    isOnboardingDone: () async => onboardingDone,
    hasSeenTour: () => tourSeen,
  ).isDone();

  test('done only once onboarding is finished and the tour seen', () async {
    expect(await gate(onboardingDone: false, tourSeen: false), isFalse);
    expect(await gate(onboardingDone: true, tourSeen: false), isFalse);
    expect(await gate(onboardingDone: false, tourSeen: true), isFalse);
    expect(await gate(onboardingDone: true, tourSeen: true), isTrue);
  });
}
