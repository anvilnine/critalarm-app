import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';

/// Domain contract for persisting the user's theme choice. Implemented in
/// data/ and selected in DI via `Env` — never referenced from presentation.
abstract interface class ThemePreferenceRepository {
  Future<AppResult<AppThemeMode>> getThemeMode();
  Future<AppResult<Unit>> setThemeMode(AppThemeMode mode);
}
