import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// What opened the Pro sheet. The wire value goes in the `?source=` of the
/// route and in the analytics event.
enum ProPackSheetSource {
  reliability('reliability'),

  // The places that sell Hosted today. Each has a name here too, so a
  // feature that moves to Pro opens the Pro paywall from the same place
  // with nothing else to change. The wire names match `PaywallSource`.
  createTopicCard('create_topic_card'),
  history('history'),
  historyOlder('history_older'),
  homeWidgets('home_widgets'),
  widgetLocked('widget_locked'),
  appIcon('app_icon'),
  personalizeSound('personalize_sound'),
  personalizeWidgets('personalize_widgets'),
  personalizeAppIcon('personalize_app_icon'),
  personalizeChallenge('personalize_challenge'),
  topicChallenge('topic_challenge'),
  personalizeLook('personalize_look'),
  topicLook('topic_look'),

  // An own alarm sound, from any of the ways in.
  sounds('sounds'),
  direct('direct');

  const ProPackSheetSource(this.wire);

  final String wire;

  /// A missing or unknown value reads as [direct].
  static ProPackSheetSource parse(String? value) => values.firstWhere(
    (source) => source.wire == value,
    orElse: () => ProPackSheetSource.direct,
  );
}

/// The three Pro pack events. Nothing is sent unless the user turned
/// analytics on, which [TelemetryGate.logEvent] checks.
///
/// No event carries what was offered or what it cost: a source or a result
/// word, and nothing else.
final class ProPackAnalytics {
  const ProPackAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> sheetOpened(ProPackSheetSource source) => _gate.logEvent(
    AnalyticsEvents.proPackSheetOpened,
    {'source': source.wire},
  );

  /// [result] is `held` or `checking`.
  Future<void> purchaseFinished({required String result}) => _gate.logEvent(
    AnalyticsEvents.proPackPurchaseFinished,
    {'result': result},
  );

  /// [result] is `held`, `none` or `checking`.
  Future<void> restoreFinished({required String result}) => _gate.logEvent(
    AnalyticsEvents.proPackRestoreFinished,
    {'result': result},
  );
}
