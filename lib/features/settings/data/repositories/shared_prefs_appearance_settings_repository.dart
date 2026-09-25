import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences implementation of [AppearanceSettingsRepository].
///
/// Reduce motion defaults to off (follow the OS); haptics default to on.
class SharedPrefsAppearanceSettingsRepository
    implements AppearanceSettingsRepository {
  const SharedPrefsAppearanceSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyReduceMotion = 'appearance_reduce_motion';
  static const _keyHaptics = 'appearance_haptics_enabled';

  @override
  Future<AppResult<AppearanceSettings>> getAppearanceSettings() async {
    try {
      return AppearanceSettings(
        reduceMotion: _prefs.getBool(_keyReduceMotion) ?? false,
        hapticsEnabled: _prefs.getBool(_keyHaptics) ?? true,
      ).toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> setReduceMotion({required bool enabled}) => _save(
    _keyReduceMotion,
    enabled,
    LocaleKeys.storage_errors_save_reduce_motion_preference,
  );

  @override
  Future<AppResult<Unit>> setHapticsEnabled({required bool enabled}) => _save(
    _keyHaptics,
    enabled,
    LocaleKeys.storage_errors_save_haptics_preference,
  );

  Future<AppResult<Unit>> _save(String key, bool value, String error) async {
    try {
      final saved = await _prefs.setBool(key, value);
      if (!saved) {
        return Failure.unexpected(message: error.tr()).toFailure();
      }
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
