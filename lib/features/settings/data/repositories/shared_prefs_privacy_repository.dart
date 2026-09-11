import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences implementation of [PrivacyRepository].
///
/// Both analytics and crash reporting default to false (opt-in).
class SharedPrefsPrivacyRepository implements PrivacyRepository {
  const SharedPrefsPrivacyRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyAnalytics = 'privacy_analytics_enabled';
  static const _keyCrashlytics = 'privacy_crashlytics_enabled';

  @override
  Future<AppResult<PrivacySettings>> getPrivacySettings() async {
    try {
      final analytics = _prefs.getBool(_keyAnalytics) ?? false;
      final crashlytics = _prefs.getBool(_keyCrashlytics) ?? false;
      return PrivacySettings(
        analyticsEnabled: analytics,
        crashReportingEnabled: crashlytics,
      ).toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled}) async {
    try {
      final saved = await _prefs.setBool(_keyAnalytics, enabled);
      if (!saved) {
        return const Failure.unexpected(
          message: 'Could not save analytics preference',
        ).toFailure();
      }
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> setCrashReportingEnabled({
    required bool enabled,
  }) async {
    try {
      final saved = await _prefs.setBool(_keyCrashlytics, enabled);
      if (!saved) {
        return const Failure.unexpected(
          message: 'Could not save crash reporting preference',
        ).toFailure();
      }
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
