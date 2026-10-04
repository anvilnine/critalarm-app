import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// The one analytics switch setup shows, on its last step.
///
/// It writes the same choice as Settings > Privacy and the consent ask on
/// Home: the saved preference, then the collection itself. A tap on the
/// switch, either way, is an answer, so Home does not ask again. A switch
/// that was never touched is no answer, and Home keeps its turn.
class SetupStatsConsent {
  const SetupStatsConsent({
    required this._privacy,
    required this._telemetry,
    required this._notices,
    this.onAnswered,
  });

  final PrivacyRepository _privacy;
  final TelemetryGate _telemetry;
  final InAppNoticeRepository _notices;

  /// Runs after an answer is saved, with the answer. This is where setup
  /// events held back until the user chose are sent or thrown away.
  final Future<void> Function({required bool isOn})? onAnswered;

  /// Whether analytics is on now. Off when it was never chosen.
  Future<bool> isOn() async =>
      (await _privacy.getPrivacySettings()).getOrNull()?.analyticsEnabled ??
      false;

  /// The user tapped the switch. Returns false, with nothing changed, when
  /// the choice could not be saved.
  Future<bool> answer({required bool isOn}) async {
    final saved = await _privacy.setAnalyticsEnabled(enabled: isOn);
    if (saved.getOrNull() == null) return false;
    await _telemetry.setAnalyticsEnabled(isOn);
    await _notices.markConsentAsked();
    await onAnswered?.call(isOn: isOn);
    return true;
  }
}
