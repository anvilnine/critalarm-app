import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsOnboardingProgressRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SharedPrefsOnboardingProgressRepository(prefs);
  });

  group('OnboardingDraft', () {
    test('a fresh install starts at the permissions step', () async {
      final draft = (await repository.readDraft()).getOrNull()!;
      expect(draft.step, OnboardingStep.permissions);
      expect(draft.serverUrl, isEmpty);
      expect(draft.adminToken, isEmpty);
      expect(draft.isSelfHosting, isFalse);
      expect(draft.countdownEndsAt, isNull);
    });

    test('a half-typed self-hosted form survives a relaunch', () async {
      await repository.saveDraft(
        const OnboardingDraft(
          step: OnboardingStep.connect,
          serverUrl: 'https://alerts.example.com',
          adminToken: 'ad_half',
          isSelfHosting: true,
        ),
      );

      final draft = (await repository.readDraft()).getOrNull()!;
      expect(draft.step, OnboardingStep.connect);
      expect(draft.serverUrl, 'https://alerts.example.com');
      expect(draft.adminToken, 'ad_half');
      expect(draft.isSelfHosting, isTrue);
    });

    test('finishing onboarding leaves nothing behind', () async {
      await repository.saveDraft(
        const OnboardingDraft(
          step: OnboardingStep.test,
          serverUrl: 'https://alerts.example.com',
        ),
      );
      await repository.clearDraft();

      final draft = (await repository.readDraft()).getOrNull()!;
      expect(draft.step, OnboardingStep.permissions);
      expect(draft.serverUrl, isEmpty);
    });

    test('each step knows the screen it belongs to', () {
      expect(OnboardingStep.permissions.route, '/onboarding');
      expect(OnboardingStep.connect.route, '/onboarding/connect');
      expect(OnboardingStep.test.route, '/onboarding/connect');
    });

    test('an unknown saved step falls back to the first one', () {
      expect(OnboardingStep.fromName('nonsense'), OnboardingStep.permissions);
      expect(OnboardingStep.fromName(null), OnboardingStep.permissions);
      expect(OnboardingStep.fromName('test'), OnboardingStep.test);
    });
  });

  group('countdown left on the clock', () {
    test('no pending test alarm means no seconds to count', () {
      expect(const OnboardingDraft().secondsLeft, isNull);
    });

    test('a deadline in the future counts down to it', () {
      final draft = OnboardingDraft(
        countdownEndsAt: DateTime.now().add(const Duration(seconds: 20)),
      );
      expect(draft.secondsLeft, inInclusiveRange(18, 20));
    });

    test('a deadline already past reads zero, never negative', () {
      final draft = OnboardingDraft(
        countdownEndsAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(draft.secondsLeft, 0);
    });

    test('the deadline survives being written and read back', () async {
      final endsAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch + 30000,
      );
      await repository.saveDraft(
        OnboardingDraft(countdownEndsAt: endsAt),
      );

      final draft = (await repository.readDraft()).getOrNull()!;
      expect(draft.countdownEndsAt, endsAt);
    });
  });
}
