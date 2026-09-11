import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';

/// Contract for accessing and saving privacy preferences.
abstract interface class PrivacyRepository {
  /// Fetches the user's current privacy choices.
  Future<AppResult<PrivacySettings>> getPrivacySettings();

  /// Updates whether anonymous usage analytics should be shared.
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled});

  /// Updates whether crash reports should be sent.
  Future<AppResult<Unit>> setCrashReportingEnabled({required bool enabled});
}
