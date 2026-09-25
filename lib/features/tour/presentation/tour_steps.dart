import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

/// Every spot on screen the tour can point at. A screen marks the widget with
/// a TourAnchor carrying one of these.
enum TourAnchorId {
  homeStage,
  topicList,
  compose,
  createName,
  createCritical,
  createButton,
  search,
  searchResults,
  topicCritical,
  topicSound,
  topicDelete,
  historyTab,
  settingsHealth,
  settingsTour,
}

/// Which screen a step needs on the display before it can point at anything.
enum TourPlace { home, createTopic, topic, settings }

/// One short "How to use the app" guide per screen or feature. Each plays by
/// itself the first time the user reaches that screen, and only covers what
/// is on it. Settings can still replay every guide back to back.
enum TourGuide {
  /// The Topics tab: the status face, the list, making and finding things.
  home,

  /// The search panel, the first time the user opens it.
  search,

  /// Making a topic.
  createTopic,

  /// A topic's own screen.
  topic,

  /// The History tab.
  history,

  /// The Settings tab.
  settings,
}

/// The guide that plays the first time [path] is on screen, or null when the
/// screen has none. Search is not a route: the shell asks for its guide when
/// the panel opens.
TourGuide? tourGuideForPath(String path) {
  if (path == '/') return TourGuide.home;
  if (path == '/topics/new') return TourGuide.createTopic;
  if (path == '/history') return TourGuide.history;
  if (path == '/settings') return TourGuide.settings;
  // A topic opened from Topics or from History. Its messages and sounds
  // pages go one level deeper and are not the topic screen.
  final segments = Uri.parse(path).pathSegments;
  final topicAt = segments.isNotEmpty && segments.first == 'history' ? 1 : 0;
  if (segments.length == topicAt + 2 && segments[topicAt] == 'topics') {
    return TourGuide.topic;
  }
  return null;
}

/// The route for [place]. [topicName] is the topic the topic steps open: the
/// user's first one, or the example one when they have none yet.
String tourPath(TourPlace place, String topicName) => switch (place) {
  TourPlace.home => '/',
  TourPlace.createTopic => '/topics/new',
  TourPlace.topic => '/topics/${Uri.encodeComponent(topicName)}',
  TourPlace.settings => '/settings',
};

@immutable
class TourStep {
  const TourStep({
    required this.guide,
    required this.place,
    required this.anchor,
    required this.titleKey,
    required this.bodyKey,
    this.exampleBodyKey,
    this.searchQuery,
  });

  /// The guide this step belongs to.
  final TourGuide guide;

  final TourPlace place;
  final TourAnchorId anchor;
  final String titleKey;
  final String bodyKey;

  /// Said instead of [bodyKey] while the example topics are on screen.
  final String? exampleBodyKey;

  /// Typed into search for this step, so the results are on screen while the
  /// step talks about them. Null keeps search closed.
  final String? searchQuery;

  String bodyKeyFor({required bool usingExamples}) =>
      usingExamples ? exampleBodyKey ?? bodyKey : bodyKey;
}

/// Every step of every guide, in the order the full replay from Settings
/// plays them. Steps on one screen sit together, so the replay moves between
/// screens as few times as it can. A guide on its own plays its steps in this
/// same order.
const List<TourStep> tourSteps = [
  TourStep(
    guide: TourGuide.home,
    place: TourPlace.home,
    anchor: TourAnchorId.homeStage,
    titleKey: LocaleKeys.tour_stage_title,
    bodyKey: LocaleKeys.tour_stage_body,
  ),
  TourStep(
    guide: TourGuide.home,
    place: TourPlace.home,
    anchor: TourAnchorId.topicList,
    titleKey: LocaleKeys.tour_topics_title,
    bodyKey: LocaleKeys.tour_topics_body,
    exampleBodyKey: LocaleKeys.tour_topics_body_example,
  ),
  TourStep(
    guide: TourGuide.home,
    place: TourPlace.home,
    anchor: TourAnchorId.compose,
    titleKey: LocaleKeys.tour_compose_title,
    bodyKey: LocaleKeys.tour_compose_body,
  ),
  TourStep(
    guide: TourGuide.createTopic,
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createName,
    titleKey: LocaleKeys.tour_create_name_title,
    bodyKey: LocaleKeys.tour_create_name_body,
  ),
  TourStep(
    guide: TourGuide.createTopic,
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createCritical,
    titleKey: LocaleKeys.tour_create_critical_title,
    bodyKey: LocaleKeys.tour_create_critical_body,
  ),
  TourStep(
    guide: TourGuide.createTopic,
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createButton,
    titleKey: LocaleKeys.tour_create_button_title,
    bodyKey: LocaleKeys.tour_create_button_body,
  ),
  TourStep(
    guide: TourGuide.home,
    place: TourPlace.home,
    anchor: TourAnchorId.search,
    titleKey: LocaleKeys.tour_search_title,
    bodyKey: LocaleKeys.tour_search_body,
  ),
  TourStep(
    guide: TourGuide.search,
    place: TourPlace.home,
    anchor: TourAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_settings_title,
    bodyKey: LocaleKeys.tour_search_settings_body,
    searchQuery: 'sound',
  ),
  TourStep(
    guide: TourGuide.search,
    place: TourPlace.home,
    anchor: TourAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_docs_title,
    bodyKey: LocaleKeys.tour_search_docs_body,
    searchQuery: 'uptime kuma',
  ),
  TourStep(
    guide: TourGuide.topic,
    place: TourPlace.topic,
    anchor: TourAnchorId.topicCritical,
    titleKey: LocaleKeys.tour_topic_critical_title,
    bodyKey: LocaleKeys.tour_topic_critical_body,
  ),
  TourStep(
    guide: TourGuide.topic,
    place: TourPlace.topic,
    anchor: TourAnchorId.topicSound,
    titleKey: LocaleKeys.tour_topic_sound_title,
    bodyKey: LocaleKeys.tour_topic_sound_body,
  ),
  TourStep(
    guide: TourGuide.topic,
    place: TourPlace.topic,
    anchor: TourAnchorId.topicDelete,
    titleKey: LocaleKeys.tour_topic_delete_title,
    bodyKey: LocaleKeys.tour_topic_delete_body,
  ),
  TourStep(
    guide: TourGuide.history,
    place: TourPlace.home,
    anchor: TourAnchorId.historyTab,
    titleKey: LocaleKeys.tour_history_title,
    bodyKey: LocaleKeys.tour_history_body,
  ),
  TourStep(
    guide: TourGuide.settings,
    place: TourPlace.settings,
    anchor: TourAnchorId.settingsHealth,
    titleKey: LocaleKeys.tour_health_title,
    bodyKey: LocaleKeys.tour_health_body,
  ),
  TourStep(
    guide: TourGuide.settings,
    place: TourPlace.settings,
    anchor: TourAnchorId.settingsTour,
    titleKey: LocaleKeys.tour_replay_title,
    bodyKey: LocaleKeys.tour_replay_body,
  ),
];

/// The steps of [guide], in order. Null is the full replay: every step.
List<TourStep> tourStepsFor(TourGuide? guide) => guide == null
    ? tourSteps
    : [
        for (final step in tourSteps)
          if (step.guide == guide) step,
      ];
