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
///
/// All of it belongs to the account the phone is on. [forgetAll] is what a
/// sign-out, an account delete and a change of server call. The flags also
/// carry the tag of the account they were written for, in
/// `topic_challenge_owed_for`, because they say something about a plan:
/// see [keepFlagsOnlyFor].
abstract interface class ChallengeChoices {
  static const String choiceKeyPrefix = 'topic_challenge.';
  static const String defaultKey = 'topic_challenge_default';

  /// The prefix of the one flag per topic that native code reads, as
  /// `flutter.topic_challenge_owed.<topic>`: true while the topic owes a
  /// challenge. Android `ChallengeFlagStore` and iOS `ChallengeFlag` hold
  /// the same word. Keep the three in step.
  static const String owedKeyPrefix = 'topic_challenge_owed.';

  /// The tag of the account every flag was written for (`accountTagFor`).
  /// One key for all of them, and only Dart reads it: native keeps reading
  /// the plain booleans. It does not start with [owedKeyPrefix], so it is
  /// never taken for a topic's flag.
  static const String owedAccountKey = 'topic_challenge_owed_for';

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

  /// The topic was deleted on this phone: its choice goes. The flag writer
  /// hears the change and takes the flag away, which needs no plan.
  Future<void> forgetTopic(String topic);

  /// Everything here belongs to an account that this phone has left:
  /// every choice, the default, every flag and the flags' tag all go.
  Future<void> forgetAll();

  /// Says which account this phone is on, and takes every flag away when
  /// they were written for another one. True when a flag was taken away,
  /// so the copy the iOS Live Activity reads has to be made again.
  ///
  /// With no account known ([accountTag] null) nothing is taken away, and
  /// [flaggedTopics] answers none until an account is known.
  Future<bool> keepFlagsOnlyFor(String? accountTag);

  /// The topics flagged for native as owing a challenge, for the account
  /// this phone is on. Flags written for another account, or read before
  /// [keepFlagsOnlyFor] said which account that is, count as none. Only
  /// the flag writer changes them, and only on a sure answer.
  Set<String> get flaggedTopics;

  bool isFlagged(String topic);

  /// Writes or clears [topic]'s flag. Setting one throws when no account
  /// is known: there is nobody to write it for.
  Future<void> writeFlag(String topic, {required bool isOwed});

  /// Fires after a choice or the default changed.
  Stream<void> get changes;
}
