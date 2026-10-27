/// What opened the Pro paywall. The wire value goes in the `?source=` of
/// the route and in the analytics event.
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

  // The Pro row in the Settings plan section.
  settingsPlan('settings_plan'),
  direct('direct');

  const ProPackSheetSource(this.wire);

  final String wire;

  /// A missing or unknown value reads as [direct].
  static ProPackSheetSource parse(String? value) => values.firstWhere(
    (source) => source.wire == value,
    orElse: () => ProPackSheetSource.direct,
  );
}
