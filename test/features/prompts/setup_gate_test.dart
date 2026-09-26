import 'package:critalarm/features/prompts/domain/setup_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool> gate({
    required bool onboardingDone,
    required bool guideSeen,
    bool guideActive = false,
  }) => SetupGate(
    isOnboardingDone: () async => onboardingDone,
    hasSeenFeatureGuide: () => guideSeen,
    isFeatureGuideActive: () => guideActive,
  ).isDone();

  test(
    'done only once onboarding is finished and the first Feature Guide seen',
    () async {
      expect(await gate(onboardingDone: false, guideSeen: false), isFalse);
      expect(await gate(onboardingDone: true, guideSeen: false), isFalse);
      expect(await gate(onboardingDone: false, guideSeen: true), isFalse);
      expect(await gate(onboardingDone: true, guideSeen: true), isTrue);
    },
  );

  test('not done while a guide is up, so nothing shows over it', () async {
    expect(
      await gate(onboardingDone: true, guideSeen: true, guideActive: true),
      isFalse,
    );
  });

  test(
    'with no guide callback, only onboarding and the first Feature Guide count',
    () async {
      final done = await SetupGate(
        isOnboardingDone: () async => true,
        hasSeenFeatureGuide: () => true,
      ).isDone();
      expect(done, isTrue);
    },
  );
}
