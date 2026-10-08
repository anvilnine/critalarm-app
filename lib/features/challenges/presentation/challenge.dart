import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/presentation/ops_math_challenge.dart';
import 'package:critalarm/features/challenges/presentation/scratch_card_challenge.dart';
import 'package:critalarm/features/challenges/presentation/shake_challenge.dart';
import 'package:critalarm/features/challenges/presentation/type_alert_title_challenge.dart';
import 'package:critalarm/features/challenges/presentation/type_topic_name_challenge.dart';
import 'package:flutter/widgets.dart';

/// One run of a challenge: the alarm it is for, and how it says it was
/// passed.
@immutable
final class ChallengeRun {
  const ChallengeRun({
    required this.incident,
    required this.onPassed,
    this.isPicture = false,
  });

  /// The words the acknowledged screen already shows. A sample on the
  /// Personalize page.
  final ChallengeIncident incident;

  /// Call once, when the task is done. The step around the challenge does
  /// the rest: on the alarm screen it closes the incident, in a try it
  /// closes nothing.
  final VoidCallback onPassed;

  /// True when the challenge is drawn as a still picture in the Personalize
  /// preview: it takes no focus, opens no keyboard and starts no sensor.
  final bool isPicture;
}

/// The room a challenge keeps clear around its text field when the field
/// is brought into view over the keyboard.
///
/// Above: the words to copy. Below: the one line under the field, then the
/// way out pinned over the keyboard with the soft edge above it. At a
/// large text size the way out and that line come to about 170 points, and
/// less room than that left the line cut off on a small phone.
const EdgeInsets challengeFieldScrollPadding = EdgeInsets.fromLTRB(
  20,
  120,
  20,
  200,
);

/// A wake-up challenge: a small task before "At my desk" closes an
/// incident.
///
/// To add one:
///
/// 1. Add a value to [ChallengeKind]. Its id is saved on phones, so it
///    never changes once shipped.
/// 2. Write a class that implements this, in its own file here.
/// 3. Add it to [challenges].
/// 4. Add its two strings to `en.json` under `challenges.<id>`.
///
/// That is all. The picker on the topic page, the strip on Personalize,
/// the rule, the flag for native and the step on the alarm screen read
/// [challenges] and need no edit.
///
/// What a challenge must not do: it draws no way out and no close button
/// (the step has both, always on screen), it closes nothing itself, it
/// reads nothing but [ChallengeRun.incident], and it sends nothing.
abstract interface class Challenge {
  ChallengeKind get kind;

  /// The `LocaleKeys` key of its name: a chip on Personalize (two lines of
  /// 13 point type in 140 points at most) and a row in the picker sheet.
  String get nameKey;

  /// The `LocaleKeys` key of the one line over the task, which says what
  /// to do. One line at the default text size on a 375 point screen. It is
  /// the only instruction: the task under it does not say it again.
  String get promptKey;

  /// Whether it can run for this alarm. A challenge that needs an alert
  /// title says no when the screen shows none, and the incident then
  /// closes with no challenge.
  bool canRunFor(ChallengeIncident incident);

  /// The task itself, drawn under the prompt and over the way out. It gets
  /// the full width and scrolls with the step, so it sets no height of its
  /// own. With [ChallengeRun.isPicture] it draws its first frame and takes
  /// no input.
  Widget build(BuildContext context, ChallengeRun run);
}

/// Every challenge this build has, in the order the picker and the
/// Personalize strip list them.
const List<Challenge> challenges = [
  TypeTopicNameChallenge(),
  TypeAlertTitleChallenge(),
  OpsMathChallenge(),
  ScratchCardChallenge(),
  ShakeChallenge(),
];

/// The challenge of [kind], or null when this build has none for it.
Challenge? challengeOf(ChallengeKind? kind) {
  if (kind == null) return null;
  for (final challenge in challenges) {
    if (challenge.kind == kind) return challenge;
  }
  return null;
}
