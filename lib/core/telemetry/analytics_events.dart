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
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingStepCompleted = 'onboarding_step_completed';
  static const onboardingOfferShown = 'onboarding_offer_shown';
  static const onboardingOfferClosed = 'onboarding_offer_closed';
  static const onboardingOfferBought = 'onboarding_offer_bought';
  static const homeDay0CardShown = 'home_day0_card_shown';
  static const homeDay0CardDismissed = 'home_day0_card_dismissed';
  static const proPackSheetOpened = 'pro_pack_sheet_opened';
  static const proPackPurchaseFinished = 'pro_pack_purchase_finished';
  static const proPackRestoreFinished = 'pro_pack_restore_finished';

  // Sent by the paywall layouts alone. The shipped paywall and the Pro
  // sheet have no event for these moments.
  static const paywallRestoreFinished = 'paywall_restore_finished';
  static const paywallClosed = 'paywall_closed';
  static const proPackPurchaseStarted = 'pro_pack_purchase_started';
  static const proPackClosed = 'pro_pack_closed';
  static const paywallThanksShown = 'paywall_thanks_shown';
  static const paywallThanksLeft = 'paywall_thanks_left';
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

/// The two events every setup step sends. Each carries exactly three
/// parameters, and nothing the user typed or chose: the step id, the id of
/// the flow the step ran in, and the milliseconds since the previous step
/// event.
final class OnboardingAnalytics {
  const OnboardingAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> stepViewed({
    required String step,
    required String flowId,
    required int msSincePrevious,
  }) => _gate.logEvent(
    AnalyticsEvents.onboardingStepViewed,
    _params(step, flowId, msSincePrevious),
  );

  Future<void> stepCompleted({
    required String step,
    required String flowId,
    required int msSincePrevious,
  }) => _gate.logEvent(
    AnalyticsEvents.onboardingStepCompleted,
    _params(step, flowId, msSincePrevious),
  );

  static Map<String, Object?> _params(
    String step,
    String flowId,
    int msSincePrevious,
  ) => {'step': step, 'flow_id': flowId, 'ms_since_previous': msSincePrevious};

  /// The three events of the offer step. Each carries the product on offer,
  /// the layout that drew it and the flow id, and nothing else.
  Future<void> offerShown({
    required String product,
    required String layout,
    required String flowId,
  }) => _gate.logEvent(
    AnalyticsEvents.onboardingOfferShown,
    _offerParams(product, layout, flowId),
  );

  Future<void> offerClosed({
    required String product,
    required String layout,
    required String flowId,
  }) => _gate.logEvent(
    AnalyticsEvents.onboardingOfferClosed,
    _offerParams(product, layout, flowId),
  );

  Future<void> offerBought({
    required String product,
    required String layout,
    required String flowId,
  }) => _gate.logEvent(
    AnalyticsEvents.onboardingOfferBought,
    _offerParams(product, layout, flowId),
  );

  static Map<String, Object?> _offerParams(
    String product,
    String layout,
    String flowId,
  ) => {'product': product, 'layout': layout, 'flow_id': flowId};
}

/// The two events of the day-0 card on Home. They carry no parameters. The
/// paywall opened from the card names `PaywallSource.homeDay0Card` on
/// `paywall_viewed`.
final class Day0CardAnalytics {
  const Day0CardAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> shown() => _gate.logEvent(AnalyticsEvents.homeDay0CardShown);

  Future<void> dismissed() =>
      _gate.logEvent(AnalyticsEvents.homeDay0CardDismissed);
}
