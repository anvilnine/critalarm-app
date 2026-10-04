import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('isCompleted returns false when key is absent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPrefsOnboardingProgressRepository(prefs);

    final result = await repository.isCompleted();

    expect(result.isSuccess(), isTrue);
    expect(result.getOrNull(), isFalse);
  });

  test('markCompleted persists true', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPrefsOnboardingProgressRepository(prefs);

    final result = await repository.markCompleted();

    expect(result.isSuccess(), isTrue);
    expect((await repository.isCompleted()).getOrNull(), isTrue);
  });

  test('completion remains true when server keys are removed', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://alerts.example.com',
      'admin_token': 'ad_token',
      'onboarding_completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPrefsOnboardingProgressRepository(prefs);

    await prefs.remove('server_url');
    await prefs.remove('admin_token');

    expect((await repository.isCompleted()).getOrNull(), isTrue);
  });

  group('SharedPrefsOnboardingFlowRepository', () {
    const flow = OnboardingFlow(id: 'custom', steps: ['welcome', 'connect']);

    test(
      'reads nothing pinned and nothing completed on a fresh phone',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final progress = SharedPrefsOnboardingFlowRepository(prefs).read();

        expect(progress.pinned, isNull);
        expect(progress.completed, isEmpty);
      },
    );

    test(
      'the pinned flow and the completed steps survive a relaunch',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsOnboardingFlowRepository(prefs);

        await repository.pin(flow);
        await repository.saveCompleted({'welcome'});

        final progress = SharedPrefsOnboardingFlowRepository(prefs).read();
        expect(progress.pinned, flow);
        expect(progress.completed, {'welcome'});
        expect(prefs.getString('onboarding_flow_id'), 'custom');
        expect(prefs.getStringList('onboarding_flow_steps'), flow.steps);
        expect(prefs.getStringList('onboarding_flow_completed'), ['welcome']);
      },
    );

    test(
      'clear drops the flow, the completed steps and the old step key',
      () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_step': 'connect',
          'onboarding_completed': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsOnboardingFlowRepository(prefs);
        await repository.pin(flow);
        await repository.saveCompleted({'welcome'});

        await repository.clear();

        expect(repository.read().pinned, isNull);
        expect(repository.read().completed, isEmpty);
        expect(repository.readLegacyStep(), isNull);
        expect(prefs.getBool('onboarding_completed'), isTrue);
      },
    );

    test('the old step key is read, then removed', () async {
      SharedPreferences.setMockInitialValues({'onboarding_step': 'test'});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsOnboardingFlowRepository(prefs);

      expect(repository.readLegacyStep(), 'test');
      await repository.removeLegacyStep();

      expect(prefs.containsKey('onboarding_step'), isFalse);
    });
  });
}
