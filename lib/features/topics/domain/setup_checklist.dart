import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:flutter/foundation.dart';

/// The three things a user who left setup early still has to do, in order.
enum SetupChecklistRow {
  /// A server connection is saved.
  server,

  /// At least one topic has Critical delivery switched on. The user turns
  /// that switch on. Nothing here does it for them.
  criticalTopic,

  /// A message from the user's own tool has reached this phone. Read from
  /// `FirstMessageStore.isReceived`, never from a topic's last message, so
  /// it stays true when the topic is deleted.
  firstMessage,
}

/// The setup checklist Home draws at the top of its list sheet.
///
/// Home content: it is not an In-App Notice and not an ask, and it never
/// opens anything on its own.
@immutable
class SetupChecklist {
  const SetupChecklist({
    required this.isVisible,
    required this.hasServer,
    required this.hasTopics,
    required this.hasCriticalTopic,
    required this.hasFirstMessage,
  });

  /// Nothing to draw.
  static const hidden = SetupChecklist(
    isVisible: false,
    hasServer: false,
    hasTopics: false,
    hasCriticalTopic: false,
    hasFirstMessage: false,
  );

  /// Whether Home draws it at all.
  final bool isVisible;

  final bool hasServer;

  /// The user owns a topic of any kind. Not a row: it picks the words and
  /// the tap of the critical-topic row.
  final bool hasTopics;

  final bool hasCriticalTopic;
  final bool hasFirstMessage;

  bool isTicked(SetupChecklistRow row) => switch (row) {
    SetupChecklistRow.server => hasServer,
    SetupChecklistRow.criticalTopic => hasCriticalTopic,
    SetupChecklistRow.firstMessage => hasFirstMessage,
  };

  /// All three rows are true.
  bool get isComplete => hasServer && hasCriticalTopic && hasFirstMessage;

  /// How many rows are ticked, for the "2 of 3" line.
  int get tickedCount => SetupChecklistRow.values.where(isTicked).length;

  @override
  bool operator ==(Object other) =>
      other is SetupChecklist &&
      other.isVisible == isVisible &&
      other.hasServer == hasServer &&
      other.hasTopics == hasTopics &&
      other.hasCriticalTopic == hasCriticalTopic &&
      other.hasFirstMessage == hasFirstMessage;

  @override
  int get hashCode => Object.hash(
    isVisible,
    hasServer,
    hasTopics,
    hasCriticalTopic,
    hasFirstMessage,
  );

  @override
  String toString() =>
      'SetupChecklist(visible: $isVisible, server: $hasServer, '
      'topics: $hasTopics, critical: $hasCriticalTopic, '
      'message: $hasFirstMessage)';
}

/// The checklist for what is true right now.
///
/// - [isRetired]: the checklist finished once, or was never needed on this
///   phone. It never shows again, whatever the user deletes afterwards.
/// - [hasServer] false: nothing is drawn. The no-server card on Home
///   already carries the first row.
/// - [isLoaded] false: the topic list is not on screen yet (loading, failed
///   or an old copy), so the rows could say something that is not true.
/// - [topicCritical]: one entry per topic the user owns, true where
///   Critical delivery is on.
/// - [isFirstMessageReceived]: the stored flag.
///
/// It stays visible while topics exist, until all three rows are true.
SetupChecklist setupChecklistFor({
  required bool isRetired,
  required bool hasServer,
  required bool isLoaded,
  required Iterable<bool> topicCritical,
  required bool isFirstMessageReceived,
}) {
  if (isRetired || !hasServer || !isLoaded) return SetupChecklist.hidden;
  return SetupChecklist(
    isVisible: true,
    hasServer: true,
    hasTopics: topicCritical.isNotEmpty,
    hasCriticalTopic: topicCritical.any((isCritical) => isCritical),
    hasFirstMessage: isFirstMessageReceived,
  );
}

/// What the first look at a phone's own data decides, once per install.
@immutable
class SetupChecklistSeed {
  const SetupChecklistSeed({
    required this.marksFirstMessage,
    required this.retiresChecklist,
  });

  /// Set the first-message flag: a message of the user's own is already
  /// here, from before the flag existed.
  final bool marksFirstMessage;

  /// Never show the checklist on this phone.
  final bool retiresChecklist;
}

/// Decides what a phone that has never run the checklist starts with.
///
/// The checklist is for someone who left setup early. A phone that already
/// holds a message from the user's own tool, or an alarm that was not a
/// setup test, belongs to someone who is past all of that, so the checklist
/// is retired before it is ever drawn and no celebration plays.
///
/// - [isFirstMessageReceived]: the flag is already set, which is how a
///   user who finished the last setup step arrives.
/// - [hasOwnMessage]: some topic holds a message that is not a test alarm.
/// - [incidentIds] and [setupIncidentIds]: an incident counts when
///   [countsAsRealUse] says so. A test setup sent never does.
///
/// - [hasTopics] and [wasSetUpHere]: an install that owns a topic and
///   finished setup before the checklist existed is a long-time user, even
///   when the server no longer holds any of their messages (a quiet account
///   past its retention window). It is retired, with nothing marked.
///
/// A phone with none of these gets the checklist, with nothing marked.
SetupChecklistSeed seedSetupChecklist({
  required bool isFirstMessageReceived,
  required bool hasOwnMessage,
  required Iterable<String> incidentIds,
  required Set<String> setupIncidentIds,
  bool hasTopics = false,
  bool wasSetUpHere = true,
}) {
  if (isFirstMessageReceived) {
    return const SetupChecklistSeed(
      marksFirstMessage: false,
      retiresChecklist: true,
    );
  }
  if (hasTopics && !wasSetUpHere) {
    return const SetupChecklistSeed(
      marksFirstMessage: false,
      retiresChecklist: true,
    );
  }
  final hasRealIncident = incidentIds.any(
    (id) => countsAsRealUse(incidentId: id, setupIncidentIds: setupIncidentIds),
  );
  final isInUse = hasOwnMessage || hasRealIncident;
  return SetupChecklistSeed(
    marksFirstMessage: isInUse,
    retiresChecklist: isInUse,
  );
}

/// Where a tap on [row] goes, or null when the row is not a button.
///
/// Every answer is a screen to open. No row changes a topic: Critical
/// delivery is turned on by the user's own tap on the switch, on the screen
/// this opens.
///
/// - The server row is always ticked where the checklist shows.
/// - The critical-topic row opens the new-topic screen while there is no
///   topic, and the first topic's page once there is one, because that is
///   where its Critical delivery switch is.
/// - The first-message row opens [watchedTopic] with its curl line, so the
///   user has something to send. With no topic there is nothing to send to.
String? setupChecklistRoute(
  SetupChecklistRow row, {
  required SetupChecklist checklist,
  required String? firstTopic,
  required String? watchedTopic,
}) {
  if (checklist.isTicked(row)) return null;
  switch (row) {
    case SetupChecklistRow.server:
      return null;
    case SetupChecklistRow.criticalTopic:
      if (firstTopic == null) return '/topics/new';
      return '/topics/${Uri.encodeComponent(firstTopic)}';
    case SetupChecklistRow.firstMessage:
      if (watchedTopic == null) return null;
      return '/topics/${Uri.encodeComponent(watchedTopic)}?curl=1';
  }
}

/// Whether Home is the screen the user is looking at.
///
/// Home lives at `/`, the root of the Topics tab. Anything else the router
/// shows covers it: another tab, a topic page, and the routes that sit on
/// the root navigator over the whole shell (an alarm, the new-topic screen,
/// the plans). [location] is the router's current path, the top of
/// anything pushed included. With the app in the background nobody is
/// looking at all.
///
/// The checklist ticks, celebrates and polls only while this is true.
bool isHomeFrontScreen({
  required String location,
  required bool isAppResumed,
}) {
  if (!isAppResumed) return false;
  final path = Uri.tryParse(location)?.path ?? location;
  return path.isEmpty || path == '/';
}

/// How long Home waits before it looks at this phone's data again after a
/// look that failed: 15 seconds, doubling, at most 5 minutes.
Duration setupSeedRetryDelay(int failures) {
  const first = Duration(seconds: 15);
  const longest = Duration(minutes: 5);
  if (failures <= 1) return first;
  final delay = first * (1 << (failures - 1).clamp(0, 6));
  return delay > longest ? longest : delay;
}

/// Which of the topics Home is not polling get one read on this sweep.
///
/// Home polls a few topics (see [topicsToWatchForFirstMessage]). A first
/// message on any other topic still has to tick the row, so each sweep
/// reads up to [limit] of the rest, starting at [offset] and wrapping, and
/// the next sweep carries on where this one stopped. Every topic gets its
/// turn however long the list is.
({List<String> topics, int nextOffset}) topicsToSweepForFirstMessage({
  required List<String> all,
  required List<String> watched,
  required int offset,
  int limit = 5,
}) {
  final rest = [
    for (final topic in all)
      if (!watched.contains(topic)) topic,
  ];
  if (rest.isEmpty) return (topics: const [], nextOffset: 0);
  final start = offset % rest.length;
  final count = rest.length < limit ? rest.length : limit;
  return (
    topics: [for (var i = 0; i < count; i++) rest[(start + i) % rest.length]],
    nextOffset: (start + count) % rest.length,
  );
}

/// The topics Home watches for the first message, most likely first.
///
/// Critical topics come first, because that is the one the checklist asked
/// for, then the rest in list order. Capped at [limit] so a long list does
/// not turn into a poll per topic every few seconds.
List<String> topicsToWatchForFirstMessage(
  Iterable<({String name, bool isCritical})> topics, {
  int limit = 3,
}) {
  final critical = [
    for (final topic in topics)
      if (topic.isCritical) topic.name,
  ];
  final rest = [
    for (final topic in topics)
      if (!topic.isCritical) topic.name,
  ];
  return [...critical, ...rest].take(limit).toList();
}

/// Whether this build has home screen widgets to add: iOS and Android.
bool homeScreenWidgetsExist({
  required TargetPlatform platform,
  required bool isWeb,
}) =>
    !isWeb &&
    (platform == TargetPlatform.iOS || platform == TargetPlatform.android);

/// How this user gets home screen widgets.
enum HomeWidgetsPlan {
  /// On Crit Alarm Cloud with Hosted: widgets work.
  hosted,

  /// On Crit Alarm Cloud without Hosted: widgets show locked.
  needsHosted,

  /// On the user's own server, which has no plans: widgets work.
  selfHosted,
}

/// Whether Home draws the widgets card.
///
/// Home content, shown once after the checklist is finished for good.
///
/// - [isChecklistRetired]: the checklist is done, or was never needed.
/// - [isSeen]: the user opened the how-to sheet or dismissed the card.
/// - [widgetsExist]: [homeScreenWidgetsExist].
/// - [isGuideOfferAnswered]: the Feature Guides offer was taken or
///   declined. Until then the card waits, so two things never compete.
/// - [isGuideActive]: the offer or a guide is on screen.
/// - [celebratedThisVisit]: the celebration just played here. The card
///   waits for the next visit, so it does not land on top of the moment.
bool showsHomeWidgetsCard({
  required bool isChecklistRetired,
  required bool isSeen,
  required bool widgetsExist,
  required bool isGuideOfferAnswered,
  required bool isGuideActive,
  required bool celebratedThisVisit,
}) =>
    isChecklistRetired &&
    !isSeen &&
    widgetsExist &&
    isGuideOfferAnswered &&
    !isGuideActive &&
    !celebratedThisVisit;
