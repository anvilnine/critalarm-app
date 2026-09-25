import 'package:critalarm/features/settings/data/repositories/shared_prefs_appearance_settings_repository.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reduce motion and haptics round-trip through SharedPreferences, and a
/// fresh install follows the OS for motion and keeps haptics on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SharedPrefsAppearanceSettingsRepository, SharedPreferences)> build(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return (SharedPrefsAppearanceSettingsRepository(prefs), prefs);
  }

  test(
    'a fresh install follows the OS for motion and has haptics on',
    () async {
      final (repository, _) = await build({});

      final result = await repository.getAppearanceSettings();

      expect(result.getOrNull(), const AppearanceSettings());
      expect(result.getOrNull()?.reduceMotion, isFalse);
      expect(result.getOrNull()?.hapticsEnabled, isTrue);
    },
  );

  test('reduce motion reads back what it writes', () async {
    final (repository, prefs) = await build({});

    for (final enabled in [true, false]) {
      final saved = await repository.setReduceMotion(enabled: enabled);

      expect(saved.isSuccess(), isTrue);
      expect(prefs.getBool('appearance_reduce_motion'), enabled);
      expect(
        (await repository.getAppearanceSettings()).getOrNull()?.reduceMotion,
        enabled,
      );
    }
  });

  test('haptics read back what they write', () async {
    final (repository, prefs) = await build({});

    for (final enabled in [false, true]) {
      final saved = await repository.setHapticsEnabled(enabled: enabled);

      expect(saved.isSuccess(), isTrue);
      expect(prefs.getBool('appearance_haptics_enabled'), enabled);
      expect(
        (await repository.getAppearanceSettings()).getOrNull()?.hapticsEnabled,
        enabled,
      );
    }
  });

  test('one setting does not touch the other', () async {
    final (repository, _) = await build({});

    await repository.setHapticsEnabled(enabled: false);
    await repository.setReduceMotion(enabled: true);

    expect(
      (await repository.getAppearanceSettings()).getOrNull(),
      const AppearanceSettings(reduceMotion: true, hapticsEnabled: false),
    );
  });
}
