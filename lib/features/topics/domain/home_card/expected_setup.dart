import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart';

/// A topic the phone already holds, as much as the setup guess needs of it.
typedef HeldTopic = ({String name, bool isCritical});

/// Where setup stands, as far as the phone's own records can tell before
/// Home's list and checklist have answered.
///
/// It is a guess, shown on the first frames only. The list and the checklist
/// have the last word.
@immutable
class ExpectedSetup {
  const ExpectedSetup({
    required this.checklist,
    this.firstTopic,
    this.watchedTopic,
  });

  /// The rows, as the checklist would have them.
  final SetupChecklist checklist;

  /// The first topic, for the route of the critical-topic row. Null while
  /// the phone holds no topic list.
  final String? firstTopic;

  /// The topic the first-message row opens. Null while the phone holds no
  /// topic list.
  final String? watchedTopic;

  @override
  bool operator ==(Object other) =>
      other is ExpectedSetup &&
      other.checklist == checklist &&
      other.firstTopic == firstTopic &&
      other.watchedTopic == watchedTopic;

  @override
  int get hashCode => Object.hash(checklist, firstTopic, watchedTopic);

  @override
  String toString() =>
      'ExpectedSetup($checklist, first: $firstTopic, watched: $watchedTopic)';
}

/// The setup the phone expects to be showing, or null when it expects none.
///
/// - [isOpen]: the flags say setup waits on the first message
///   (`firstMessageExpected`).
/// - [topics]: the topic list the app already holds in memory, or null when
///   it holds none. Setup reads and refreshes that list on its last steps, so
///   the first Home after setup has it, while a phone that was closed and
///   opened again does not.
///
/// With the list, the answer is the one the checklist will give: the setup
/// card while no topic has Critical delivery on, the waiting card once one
/// has. Without it nothing can tell which, so the waiting card is the guess.
/// A list with no topic in it expects nothing: the no-topics card is next.
ExpectedSetup? expectedSetupFor({
  required bool isOpen,
  required List<HeldTopic>? topics,
}) {
  if (!isOpen) return null;
  if (topics == null) {
    return const ExpectedSetup(
      checklist: SetupChecklist(
        isVisible: true,
        hasServer: true,
        hasTopics: true,
        hasCriticalTopic: true,
        hasFirstMessage: false,
      ),
    );
  }
  if (topics.isEmpty) return null;
  final watched = topicsToWatchForFirstMessage(topics);
  return ExpectedSetup(
    checklist: setupChecklistFor(
      isRetired: false,
      hasServer: true,
      isLoaded: true,
      topicCritical: [for (final topic in topics) topic.isCritical],
      isFirstMessageReceived: false,
    ),
    firstTopic: topics.first.name,
    watchedTopic: watched.isEmpty ? null : watched.first,
  );
}
