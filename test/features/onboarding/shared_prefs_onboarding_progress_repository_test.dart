import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
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
}
