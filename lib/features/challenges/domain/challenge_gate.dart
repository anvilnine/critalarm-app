import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';

/// Answers, for the alarm screen, whether "At my desk" owes a challenge.
///
/// It gathers what [challengeDueFor] needs and decides nothing itself. It
/// never throws: anything that goes wrong reads as no challenge, so an
/// incident can always be closed.
class ChallengeGate {
  ChallengeGate({
    required this._choices,
    required this._decide,
    required this._canRun,
    required Future<void> planRead,
  }) {
    unawaited(
      planRead.then<void>((_) => _isPlanRead = true, onError: (Object _) {}),
    );
  }

  final ChallengeChoices _choices;

  /// The access layer's answer for wake-up challenges, right now.
  final FeatureDecision Function() _decide;

  /// Whether the challenge of this kind can run for this alarm. False for
  /// a kind this build has no challenge for.
  final bool Function(ChallengeKind kind, ChallengeIncident incident) _canRun;

  bool _isPlanRead = false;

  /// [isCleared] is the alarm screen's own note that this incident's
  /// challenge was already passed or left since it was last acknowledged,
  /// so a close that failed is not asked for twice.
  ChallengeDue dueFor({
    required ChallengeIncident incident,
    required bool isScreenReaderOn,
    bool isCleared = false,
  }) {
    try {
      final choice = _choices.choiceFor(incident.topic);
      return challengeDueFor(
        choice: choice,
        decision: _decide(),
        isPlanRead: _isPlanRead,
        wasOwedWhenLastSure: _choices.isFlagged(incident.topic),
        canRun: choice != null && _canRun(choice, incident),
        isScreenReaderOn: isScreenReaderOn,
        isCleared: isCleared,
      );
    } on Object catch (_) {
      return const ChallengeNotOwed(NoChallengeReason.cannotRun);
    }
  }
}
