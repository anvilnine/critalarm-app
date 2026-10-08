import 'package:critalarm/features/challenges/domain/challenge_kind.dart';

/// Each topic's wake-up challenge, kept on this phone only. Nothing here
/// is sent to a server.
///
/// Three things are kept:
///
/// - `topic_challenge.<topic>`: the kind's id. No key means no challenge,
///   which is what every topic starts with.
/// - `topic_challenge_default`: what a topic made on this phone starts
///   with. No key means none.
/// - `topic_challenge_owed.<topic>`: the flag native code reads. See
///   [flaggedTopics].
abstract interface class ChallengeChoices {
  static const String choiceKeyPrefix = 'topic_challenge.';
  static const String defaultKey = 'topic_challenge_default';

  /// The prefix of the one flag per topic that native code reads, as
  /// `flutter.topic_challenge_owed.<topic>`: true while the topic owes a
  /// challenge. Android `ChallengeFlagStore` and iOS `ChallengeFlag` hold
  /// the same word. Keep the three in step.
  static const String owedKeyPrefix = 'topic_challenge_owed.';

  /// The challenge chosen for [topic], or null for none.
  ChallengeKind? choiceFor(String topic);

  /// Every topic that has one chosen.
  Map<String, ChallengeKind> get choices;

  /// Saves the choice. Null takes it away.
  Future<void> setChoice(String topic, ChallengeKind? kind);

  /// What a topic made on this phone starts with, or null for none.
  ChallengeKind? get defaultForNewTopics;

  Future<void> setDefaultForNewTopics(ChallengeKind? kind);

  /// Gives a topic that was just made the default, and takes away anything
  /// an earlier topic of the same name left behind.
  Future<void> applyDefaultTo(String newTopic);

  /// The topics flagged for native as owing a challenge. Only the flag
  /// writer changes them, and only on a sure answer.
  Set<String> get flaggedTopics;

  bool isFlagged(String topic);

  Future<void> writeFlag(String topic, {required bool isOwed});

  /// Fires after a choice or the default changed.
  Stream<void> get changes;
}
