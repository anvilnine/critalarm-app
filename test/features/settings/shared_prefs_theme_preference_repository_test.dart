import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only behaviour the shell has of its own: the theme preference
/// round-trips through SharedPreferences, and anything unreadable
/// falls back to `system` instead of throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsThemePreferenceRepository> build(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPrefsThemePreferenceRepository(
      await SharedPreferences.getInstance(),
    );
  }

  test('defaults to system when nothing is stored', () async {
    final repository = await build({});

    final result = await repository.getThemeMode();

    expect(result.getOrNull(), AppThemeMode.system);
  });

  test('defaults to system when the stored value is unknown', () async {
    final repository = await build({'theme_mode': 'sepia'});

    final result = await repository.getThemeMode();

    expect(result.getOrNull(), AppThemeMode.system);
  });

  test('reads back every mode it writes', () async {
    for (final mode in AppThemeMode.values) {
      final repository = await build({});

      await repository.setThemeMode(mode);
      final result = await repository.getThemeMode();

      expect(result.getOrNull(), mode, reason: 'round trip for ${mode.name}');
    }
  });
}
