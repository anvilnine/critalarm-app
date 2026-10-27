import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:flutter/foundation.dart';

/// How a person leaves a challenge without doing it. One of the two is
/// always on screen.
enum ChallengeWayOut {
  /// Hold the button for ten seconds (`holdToSkip`).
  hold,

  /// A plain tap. With a screen reader running that is a double tap, and a
  /// ten second hold is not something a screen reader can do.
  tap,
}

/// Why no challenge is asked for.
enum NoChallengeReason {
  /// The topic has none set. This is every topic until its owner picks one.
  noneSet,

  /// The plan that unlocks challenges is not held.
  locked,

  /// The plan could not be read, and the last sure answer was not "open".
  planUnread,

  /// The challenge needs something this alarm does not have.
  cannotRun,

  /// This incident's challenge was already passed or left on this screen.
  alreadyCleared,
}

/// The answer to "is a challenge owed before this incident is closed".
@immutable
sealed class ChallengeDue {
  const ChallengeDue();
}

final class ChallengeNotOwed extends ChallengeDue {
  const ChallengeNotOwed(this.reason);

  final NoChallengeReason reason;

  @override
  bool operator ==(Object other) =>
      other is ChallengeNotOwed && other.reason == reason;

  @override
  int get hashCode => Object.hash(ChallengeNotOwed, reason);

  @override
  String toString() => 'ChallengeNotOwed(${reason.name})';
}

final class ChallengeOwed extends ChallengeDue {
  const ChallengeOwed(this.kind, {required this.wayOut});

  final ChallengeKind kind;
  final ChallengeWayOut wayOut;

  @override
  bool operator ==(Object other) =>
      other is ChallengeOwed && other.kind == kind && other.wayOut == wayOut;

  @override
  int get hashCode => Object.hash(ChallengeOwed, kind, wayOut);

  @override
  String toString() => 'ChallengeOwed(${kind.id}, ${wayOut.name})';
}

/// Whether a challenge is owed before "At my desk" closes an incident, and
/// which.
///
/// This is about the second stage only. Nothing here is asked before "I'm
/// up", which stops the ring with one tap whatever this answers.
///
/// - [choice] is what the topic's owner picked, null for none.
/// - [decision] is the access layer's answer for wake-up challenges.
/// - [isPlanRead] is false until the access layer has read the plan and the
///   saved server. Before that a "locked" can be wrong, so it counts as
///   "could not be read".
/// - [wasOwedWhenLastSure] is the flag written for native: the last sure
///   answer for this topic was "a challenge is owed". While the plan cannot
///   be read, a challenge stays owed only then.
/// - [canRun] is the challenge's own answer for this alarm.
/// - [isCleared] is true once this incident's challenge was passed or left,
///   so a close that failed is not asked for twice.
/// - [isScreenReaderOn] picks the way out. It never removes the challenge.
///
/// When in doubt the answer is no challenge: the incident closes as it does
/// for everyone else.
ChallengeDue challengeDueFor({
  required ChallengeKind? choice,
  required FeatureDecision decision,
  required bool isPlanRead,
  required bool wasOwedWhenLastSure,
  required bool canRun,
  required bool isScreenReaderOn,
  bool isCleared = false,
}) {
  if (choice == null) {
    return const ChallengeNotOwed(NoChallengeReason.noneSet);
  }
  if (isCleared) {
    return const ChallengeNotOwed(NoChallengeReason.alreadyCleared);
  }
  if (!canRun) return const ChallengeNotOwed(NoChallengeReason.cannotRun);
  // Not offered on this server is as sure as a lock that was read.
  final isSureLocked =
      decision is FeatureNotOffered ||
      (decision is FeatureLocked && isPlanRead);
  if (isSureLocked) return const ChallengeNotOwed(NoChallengeReason.locked);
  final isUnknown = decision is FeatureUnread || decision is FeatureLocked;
  if (isUnknown && !wasOwedWhenLastSure) {
    return const ChallengeNotOwed(NoChallengeReason.planUnread);
  }
  return ChallengeOwed(
    choice,
    wayOut: isScreenReaderOn ? ChallengeWayOut.tap : ChallengeWayOut.hold,
  );
}

/// What the flag writer does with one topic's flag.
@immutable
final class ChallengeFlagChanges {
  const ChallengeFlagChanges({required this.set, required this.clear});

  /// Topics whose flag is written now.
  final Set<String> set;

  /// Topics whose flag is taken away now.
  final Set<String> clear;

  bool get isEmpty => set.isEmpty && clear.isEmpty;
}

/// Which per-topic flags change, given what each topic has chosen, what is
/// written and the access layer's answer.
///
/// The flag says "this topic owes a challenge", and native reads it to
/// decide what its Done button does. So it is written only when that is
/// sure:
///
/// - A topic with no challenge chosen never owes one, whatever the plan:
///   its flag is cleared.
/// - [decision] open, or a purchase being confirmed: every topic with a
///   challenge chosen is flagged.
/// - [decision] locked: every flag is cleared. Without the plan no flag is
///   ever set.
/// - [decision] null (nobody knows) or unread: flags for topics that still
///   have a choice stay exactly as they are.
ChallengeFlagChanges challengeFlagChangesFor({
  required Set<String> topicsWithChoice,
  required Set<String> written,
  required FeatureDecision? decision,
}) {
  final clear = written.difference(topicsWithChoice);
  final set = <String>{};
  switch (decision) {
    case FeatureOpen() || FeatureConfirming():
      set.addAll(topicsWithChoice.difference(written));
    case FeatureLocked() || FeatureNotOffered():
      clear.addAll(written);
    case FeatureUnread() || null:
      break;
  }
  return ChallengeFlagChanges(set: set, clear: clear);
}
