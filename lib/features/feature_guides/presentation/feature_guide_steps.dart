import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

/// Every spot on screen the guide can point at. A screen marks the widget with
/// a FeatureGuideAnchor carrying one of these.
enum FeatureGuideAnchorId {
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
  settingsFeatureGuides,
}

/// Which screen a step needs on the display before it can point at anything.
enum FeatureGuidePlace { home, createTopic, topic, settings }

/// One short Feature Guide per screen or feature. Each plays by
/// itself the first time the user reaches that screen, and only covers what
/// is on it. Settings can still replay every guide back to back.
enum FeatureGuide {
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
FeatureGuide? featureGuideForPath(String path) {
  if (path == '/') return FeatureGuide.home;
  if (path == '/topics/new') return FeatureGuide.createTopic;
  if (path == '/history') return FeatureGuide.history;
  if (path == '/settings') return FeatureGuide.settings;
  // A topic opened from Topics or from History. Its messages and sounds
  // pages go one level deeper and are not the topic screen.
  final segments = Uri.parse(path).pathSegments;
  final topicAt = segments.isNotEmpty && segments.first == 'history' ? 1 : 0;
  if (segments.length == topicAt + 2 && segments[topicAt] == 'topics') {
    return FeatureGuide.topic;
  }
  return null;
}

/// The route for [place]. [topicName] is the topic the topic steps open: the
/// user's first one, or the example one when they have none yet.
String featureGuidePath(FeatureGuidePlace place, String topicName) =>
    switch (place) {
      FeatureGuidePlace.home => '/',
      FeatureGuidePlace.createTopic => '/topics/new',
      FeatureGuidePlace.topic => '/topics/${Uri.encodeComponent(topicName)}',
      FeatureGuidePlace.settings => '/settings',
    };

@immutable
class FeatureGuideStep {
  const FeatureGuideStep({
    required this.guide,
    required this.place,
    required this.anchor,
    required this.titleKey,
    required this.bodyKey,
    this.exampleBodyKey,
    this.searchQuery,
  });

  /// The guide this step belongs to.
  final FeatureGuide guide;

  final FeatureGuidePlace place;
  final FeatureGuideAnchorId anchor;
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
const List<FeatureGuideStep> featureGuideSteps = [
  FeatureGuideStep(
    guide: FeatureGuide.home,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.homeStage,
    titleKey: LocaleKeys.tour_stage_title,
    bodyKey: LocaleKeys.tour_stage_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.home,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.topicList,
    titleKey: LocaleKeys.tour_topics_title,
    bodyKey: LocaleKeys.tour_topics_body,
    exampleBodyKey: LocaleKeys.tour_topics_body_example,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.home,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.compose,
    titleKey: LocaleKeys.tour_compose_title,
    bodyKey: LocaleKeys.tour_compose_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.createTopic,
    place: FeatureGuidePlace.createTopic,
    anchor: FeatureGuideAnchorId.createName,
    titleKey: LocaleKeys.tour_create_name_title,
    bodyKey: LocaleKeys.tour_create_name_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.createTopic,
    place: FeatureGuidePlace.createTopic,
    anchor: FeatureGuideAnchorId.createCritical,
    titleKey: LocaleKeys.tour_create_critical_title,
    bodyKey: LocaleKeys.tour_create_critical_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.createTopic,
    place: FeatureGuidePlace.createTopic,
    anchor: FeatureGuideAnchorId.createButton,
    titleKey: LocaleKeys.tour_create_button_title,
    bodyKey: LocaleKeys.tour_create_button_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.home,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.search,
    titleKey: LocaleKeys.tour_search_title,
    bodyKey: LocaleKeys.tour_search_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.search,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_settings_title,
    bodyKey: LocaleKeys.tour_search_settings_body,
    searchQuery: 'sound',
  ),
  FeatureGuideStep(
    guide: FeatureGuide.search,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_docs_title,
    bodyKey: LocaleKeys.tour_search_docs_body,
    searchQuery: 'uptime kuma',
  ),
  FeatureGuideStep(
    guide: FeatureGuide.topic,
    place: FeatureGuidePlace.topic,
    anchor: FeatureGuideAnchorId.topicCritical,
    titleKey: LocaleKeys.tour_topic_critical_title,
    bodyKey: LocaleKeys.tour_topic_critical_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.topic,
    place: FeatureGuidePlace.topic,
    anchor: FeatureGuideAnchorId.topicSound,
    titleKey: LocaleKeys.tour_topic_sound_title,
    bodyKey: LocaleKeys.tour_topic_sound_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.topic,
    place: FeatureGuidePlace.topic,
    anchor: FeatureGuideAnchorId.topicDelete,
    titleKey: LocaleKeys.tour_topic_delete_title,
    bodyKey: LocaleKeys.tour_topic_delete_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.history,
    place: FeatureGuidePlace.home,
    anchor: FeatureGuideAnchorId.historyTab,
    titleKey: LocaleKeys.tour_history_title,
    bodyKey: LocaleKeys.tour_history_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.settings,
    place: FeatureGuidePlace.settings,
    anchor: FeatureGuideAnchorId.settingsHealth,
    titleKey: LocaleKeys.tour_health_title,
    bodyKey: LocaleKeys.tour_health_body,
  ),
  FeatureGuideStep(
    guide: FeatureGuide.settings,
    place: FeatureGuidePlace.settings,
    anchor: FeatureGuideAnchorId.settingsFeatureGuides,
    titleKey: LocaleKeys.tour_replay_title,
    bodyKey: LocaleKeys.tour_replay_body,
  ),
];

/// The steps of [guide], in order. Null is the full replay: every step.
List<FeatureGuideStep> featureGuideStepsFor(FeatureGuide? guide) =>
    guide == null
    ? featureGuideSteps
    : [
        for (final step in featureGuideSteps)
          if (step.guide == guide) step,
      ];
