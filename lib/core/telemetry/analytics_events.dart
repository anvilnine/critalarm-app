import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// Event names for the push and alarm path. Opt-in only: nothing is sent
/// unless the user turned analytics on in Settings, which is what
/// [TelemetryGate.setAnalyticsEnabled] controls.
abstract final class AnalyticsEvents {
  static const alarmFired = 'alarm_fired';
  static const alarmAcked = 'alarm_acked';
  static const timeToAckMs = 'time_to_ack_ms';
  static const pushReceived = 'push_received';
  static const pushDropped = 'push_dropped';
  static const paywallViewed = 'paywall_viewed';
  static const paywallPlanSelected = 'paywall_plan_selected';
  static const paywallPurchaseStarted = 'paywall_purchase_started';
  static const paywallPurchaseCompleted = 'paywall_purchase_completed';
  static const paywallPurchaseFailed = 'paywall_purchase_failed';
}

/// Thin wrapper so callers name an event instead of building a params map.
final class PushAnalytics {
  const PushAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> pushReceived({required String kind, required int priority}) =>
      _gate.logEvent(AnalyticsEvents.pushReceived, {
        'kind': kind,
        'priority': priority,
      });

  Future<void> pushDropped({required String reason}) =>
      _gate.logEvent(AnalyticsEvents.pushDropped, {'reason': reason});

  Future<void> alarmFired({required String incidentId}) =>
      _gate.logEvent(AnalyticsEvents.alarmFired, {'incident_id': incidentId});

  Future<void> alarmAcked({
    required String incidentId,
    int? timeToAckMs,
  }) async {
    await _gate.logEvent(AnalyticsEvents.alarmAcked, {
      'incident_id': incidentId,
    });
    if (timeToAckMs != null) {
      await _gate.logEvent(AnalyticsEvents.timeToAckMs, {
        'incident_id': incidentId,
        'value': timeToAckMs,
      });
    }
  }
}
