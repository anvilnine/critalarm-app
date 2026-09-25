import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';

/// Contract for reading and saving the reduce motion and haptics choices.
abstract interface class AppearanceSettingsRepository {
  /// Fetches the saved choices, or the defaults when nothing is saved.
  Future<AppResult<AppearanceSettings>> getAppearanceSettings();

  /// Saves whether the app cuts its animations regardless of the OS.
  Future<AppResult<Unit>> setReduceMotion({required bool enabled});

  /// Saves whether the app plays haptics for taps and confirmations.
  Future<AppResult<Unit>> setHapticsEnabled({required bool enabled});
}
