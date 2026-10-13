import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// The five paywall events. Nothing is sent unless the user turned analytics
/// on in Settings, which [TelemetryGate.logEvent] already checks.
final class PaywallAnalytics {
  const PaywallAnalytics(this._gate);

  final TelemetryGate _gate;

  /// `source` for a paywall opened from inside the app.
  static const String directSource = directPaywallSource;

  /// [source] names what opened the paywall, for example
  /// `reminder_morning_after`.
  Future<void> viewed({String source = directSource}) =>
      _gate.logEvent(AnalyticsEvents.paywallViewed, {
        'source': source,
      });

  Future<void> planSelected({
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPlanSelected, {
    'plan': plan,
  });

  Future<void> purchaseStarted({
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseStarted, {
    'plan': plan,
  });

  Future<void> purchaseCompleted({
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseCompleted, {
    'plan': plan,
  });

  Future<void> purchaseFailed({
    required String plan,
    required String reason,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseFailed, {
    'plan': plan,
    'reason': reason,
  });
}
