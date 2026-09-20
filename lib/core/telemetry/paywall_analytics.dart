import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// The five paywall events an A/B test needs, each carrying the variant that
/// was on screen.
///
/// Every event names its variant, so a funnel in the Firebase console can read
/// views against completed purchases per layout. Nothing is sent unless the
/// user turned analytics on in Settings, which [TelemetryGate.logEvent]
/// already checks.
final class PaywallAnalytics {
  const PaywallAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> viewed({required PaywallVariant variant}) =>
      _gate.logEvent(AnalyticsEvents.paywallViewed, {'variant': variant.key});

  Future<void> planSelected({
    required PaywallVariant variant,
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPlanSelected, {
    'variant': variant.key,
    'plan': plan,
  });

  Future<void> purchaseStarted({
    required PaywallVariant variant,
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseStarted, {
    'variant': variant.key,
    'plan': plan,
  });

  Future<void> purchaseCompleted({
    required PaywallVariant variant,
    required String plan,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseCompleted, {
    'variant': variant.key,
    'plan': plan,
  });

  Future<void> purchaseFailed({
    required PaywallVariant variant,
    required String plan,
    required String reason,
  }) => _gate.logEvent(AnalyticsEvents.paywallPurchaseFailed, {
    'variant': variant.key,
    'plan': plan,
    'reason': reason,
  });
}
