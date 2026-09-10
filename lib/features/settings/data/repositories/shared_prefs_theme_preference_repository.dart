import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the theme preference in `SharedPreferences`. Unknown/absent
/// values fall back to [AppThemeMode.system].
class SharedPrefsThemePreferenceRepository
    implements ThemePreferenceRepository {
  const SharedPrefsThemePreferenceRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  @override
  Future<AppResult<AppThemeMode>> getThemeMode() async {
    final raw = _prefs.getString(_key);
    final mode = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
    return mode.toSuccess();
  }

  @override
  Future<AppResult<Unit>> setThemeMode(AppThemeMode mode) async {
    final saved = await _prefs.setString(_key, mode.name);
    if (!saved) {
      return const Failure.unexpected(
        message: 'Could not save theme preference',
      ).toFailure<Unit>();
    }
    return unit.toSuccess();
  }
}
