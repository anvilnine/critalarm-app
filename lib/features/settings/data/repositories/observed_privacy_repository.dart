import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// A [PrivacyRepository] that says so when the analytics choice is saved.
///
/// The setup switch, Settings > Privacy and the Home consent sheet all save
/// through the one repository, so this is the one place that hears every
/// answer. A fourth way to answer cannot forget to tell the listener.
class ObservedPrivacyRepository implements PrivacyRepository {
  const ObservedPrivacyRepository(
    this._inner, {
    required this.onAnalyticsChoice,
  });

  final PrivacyRepository _inner;

  /// Runs after the analytics choice was saved, with the choice. Not called
  /// when the save failed.
  final Future<void> Function({required bool isOn}) onAnalyticsChoice;

  @override
  Future<AppResult<PrivacySettings>> getPrivacySettings() =>
      _inner.getPrivacySettings();

  @override
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled}) async {
    final result = await _inner.setAnalyticsEnabled(enabled: enabled);
    if (result.getOrNull() != null) await onAnalyticsChoice(isOn: enabled);
    return result;
  }

  @override
  Future<AppResult<Unit>> setCrashReportingEnabled({required bool enabled}) =>
      _inner.setCrashReportingEnabled(enabled: enabled);
}
