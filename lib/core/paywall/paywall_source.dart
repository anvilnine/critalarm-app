/// `source` for a paywall opened with none, or one the app does not know.
const String directPaywallSource = 'direct';

/// What opened the paywall. Every entry point names one, and the name goes on
/// the `paywall_viewed` event as `source`.
///
/// The wire names are on the analytics wire and in saved reminder routes, so
/// they never change once shipped.
enum PaywallSource {
  settingsPlan('settings_plan'),
  createTopicCard('create_topic_card'),
  askSheet('ask_sheet'),
  planSheetEnding('plan_sheet_ending'),
  planSheetEnded('plan_sheet_ended'),
  settingsSearch('settings_search'),
  widgetLocked('widget_locked'),
  homeWidgets('home_widgets'),
  appIcon('app_icon'),
  historyOlder('history_older'),
  history('history'),
  reminderMorningAfter('reminder_morning_after'),
  reminderProLater('reminder_pro_later'),
  homeDay0Card('home_day0_card'),

  /// Only the router uses this, when a link arrives with no source or one it
  /// does not know.
  direct(directPaywallSource);

  const PaywallSource(this.wire);

  final String wire;

  /// The source a `?source=` value names, or [direct] for a missing or
  /// unknown one.
  static PaywallSource parse(String? wire) {
    for (final source in values) {
      if (source.wire == wire) return source;
    }
    return direct;
  }
}

/// The paywall route.
const String paywallPath = '/paywall';

/// The location that opens the paywall for [source]. The one place a paywall
/// path is built.
String paywallLocation(PaywallSource source) =>
    '$paywallPath?source=${source.wire}';
