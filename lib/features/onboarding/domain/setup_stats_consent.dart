import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// The one analytics switch setup shows, on its last step.
///
/// It writes the same choice as Settings > Privacy: the saved preference,
/// then the collection itself. A switch that was never touched writes
/// nothing.
///
/// It does not stand in for the consent ask on Home. That sheet also
/// offers crash reports, which this switch does not, so it still gets its
/// turn later, and shows analytics as on for a user who turned it on here.
class SetupStatsConsent {
  const SetupStatsConsent({
    required this._privacy,
    required this._telemetry,
    this.onAnswered,
  });

  final PrivacyRepository _privacy;
  final TelemetryGate _telemetry;

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
    await onAnswered?.call(isOn: isOn);
    return true;
  }
}
