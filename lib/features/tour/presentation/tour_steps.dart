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
    required this.place,
    required this.anchor,
    required this.titleKey,
    required this.bodyKey,
    this.exampleBodyKey,
    this.searchQuery,
  });

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

/// The whole tour, in order. Steps on one screen sit together, so the tour
/// moves between screens as few times as it can.
const List<TourStep> tourSteps = [
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.homeStage,
    titleKey: LocaleKeys.tour_stage_title,
    bodyKey: LocaleKeys.tour_stage_body,
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.topicList,
    titleKey: LocaleKeys.tour_topics_title,
    bodyKey: LocaleKeys.tour_topics_body,
    exampleBodyKey: LocaleKeys.tour_topics_body_example,
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.compose,
    titleKey: LocaleKeys.tour_compose_title,
    bodyKey: LocaleKeys.tour_compose_body,
  ),
  TourStep(
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createName,
    titleKey: LocaleKeys.tour_create_name_title,
    bodyKey: LocaleKeys.tour_create_name_body,
  ),
  TourStep(
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createCritical,
    titleKey: LocaleKeys.tour_create_critical_title,
    bodyKey: LocaleKeys.tour_create_critical_body,
  ),
  TourStep(
    place: TourPlace.createTopic,
    anchor: TourAnchorId.createButton,
    titleKey: LocaleKeys.tour_create_button_title,
    bodyKey: LocaleKeys.tour_create_button_body,
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.search,
    titleKey: LocaleKeys.tour_search_title,
    bodyKey: LocaleKeys.tour_search_body,
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_settings_title,
    bodyKey: LocaleKeys.tour_search_settings_body,
    searchQuery: 'sound',
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.searchResults,
    titleKey: LocaleKeys.tour_search_docs_title,
    bodyKey: LocaleKeys.tour_search_docs_body,
    searchQuery: 'uptime kuma',
  ),
  TourStep(
    place: TourPlace.topic,
    anchor: TourAnchorId.topicCritical,
    titleKey: LocaleKeys.tour_topic_critical_title,
    bodyKey: LocaleKeys.tour_topic_critical_body,
  ),
  TourStep(
    place: TourPlace.topic,
    anchor: TourAnchorId.topicSound,
    titleKey: LocaleKeys.tour_topic_sound_title,
    bodyKey: LocaleKeys.tour_topic_sound_body,
  ),
  TourStep(
    place: TourPlace.topic,
    anchor: TourAnchorId.topicDelete,
    titleKey: LocaleKeys.tour_topic_delete_title,
    bodyKey: LocaleKeys.tour_topic_delete_body,
  ),
  TourStep(
    place: TourPlace.home,
    anchor: TourAnchorId.historyTab,
    titleKey: LocaleKeys.tour_history_title,
    bodyKey: LocaleKeys.tour_history_body,
  ),
  TourStep(
    place: TourPlace.settings,
    anchor: TourAnchorId.settingsHealth,
    titleKey: LocaleKeys.tour_health_title,
    bodyKey: LocaleKeys.tour_health_body,
  ),
  TourStep(
    place: TourPlace.settings,
    anchor: TourAnchorId.settingsTour,
    titleKey: LocaleKeys.tour_replay_title,
    bodyKey: LocaleKeys.tour_replay_body,
  ),
];
