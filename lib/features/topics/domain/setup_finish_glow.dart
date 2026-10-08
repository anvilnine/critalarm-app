// The glow Home puts on the topic setup made, once, when setup hands over
// to Home.
//
// The rules and the times live here, with no widget, so they test on their
// own. The widget is `SetupGlow`.

/// Setup just ended and Home is about to open. Says which topic to point
/// at, once.
///
/// It lives in memory only and is never written to the phone, so it cannot
/// outlive the app run: a later launch finds nothing here.
class SetupFinishSignal {
  String? _topicName;

  /// Setup ended and [topicName] is the topic it made.
  // A call, not a setter: it reads as the moment something happened.
  // ignore: use_setters_to_change_properties
  void raise(String topicName) => _topicName = topicName;

  /// The topic to point at, or null when setup did not just end. Taking it
  /// clears it, so a second Home never glows.
  String? take() {
    final topicName = _topicName;
    _topicName = null;
    return topicName;
  }
}

/// The one signal of this app run.
final SetupFinishSignal setupFinishSignal = SetupFinishSignal();

/// The topic Home glows on after a step was finished, or null for no glow.
///
/// [endedSetup] is true only when finishing that step completed setup. A
/// replay from Settings completes nothing, and a run that made no topic has
/// nothing to point at.
String? setupGlowTopicFor({
  required bool endedSetup,
  required bool isReplay,
  required String? firstTopicName,
}) {
  if (!endedSetup || isReplay) return null;
  final name = firstTopicName?.trim() ?? '';
  return name.isEmpty ? null : name;
}

/// What Home does with a glow it is holding.
enum SetupGlowStep {
  /// Not yet. Home is covered, the list is loading, or a sheet is asking
  /// something.
  wait,

  /// Now.
  play,

  /// Never. The moment has passed.
  drop,
}

/// Whether the glow plays now, waits, or is dropped.
///
/// It plays only where it can be seen: Home in front, the list loaded and
/// the topic in it. The offer to be shown around is a sheet over the list,
/// so the glow waits behind it. A guide that runs points at the list
/// itself, with example rows in it, so the glow is dropped.
SetupGlowStep setupGlowStepFor({
  required bool isHomeInFront,
  required bool isGuideOffered,
  required bool isGuideRunning,
  required bool isListLoaded,
  required bool hasTopicRow,
}) {
  if (isGuideRunning) return SetupGlowStep.drop;
  if (!isListLoaded) return SetupGlowStep.wait;
  if (!hasTopicRow) return SetupGlowStep.drop;
  if (!isHomeInFront || isGuideOffered) return SetupGlowStep.wait;
  return SetupGlowStep.play;
}

/// The glow comes up. `AppDurations.base`.
const Duration setupGlowFadeInTakes = Duration(milliseconds: 300);

/// The glow stays at full.
const Duration setupGlowHoldTakes = Duration(milliseconds: 900);

/// The glow leaves. `AppDurations.slow`.
const Duration setupGlowFadeOutTakes = Duration(milliseconds: 400);

/// Under reduced motion the highlight is there at once and stays this long.
const Duration setupGlowStillHoldTakes = Duration(seconds: 2);

/// Under reduced motion the highlight then fades. `AppDurations.base`.
const Duration setupGlowStillFadeTakes = Duration(milliseconds: 300);

/// How long the glow is on screen from start to gone.
Duration setupGlowTakes({required bool isStill}) => isStill
    ? setupGlowStillHoldTakes + setupGlowStillFadeTakes
    : setupGlowFadeInTakes + setupGlowHoldTakes + setupGlowFadeOutTakes;

/// How strong the glow is at [elapsed], from 0 (gone) to 1 (full). Linear
/// in each part: the widget puts the curve on it.
///
/// [isStill] is the reduced motion version: full from the first frame,
/// held, then faded.
double setupGlowStrengthAt(Duration elapsed, {required bool isStill}) {
  if (elapsed < Duration.zero) return 0;
  final fadeIn = isStill ? Duration.zero : setupGlowFadeInTakes;
  final hold = isStill ? setupGlowStillHoldTakes : setupGlowHoldTakes;
  final fadeOut = isStill ? setupGlowStillFadeTakes : setupGlowFadeOutTakes;

  if (elapsed < fadeIn) {
    return elapsed.inMicroseconds / fadeIn.inMicroseconds;
  }
  final sinceFull = elapsed - fadeIn;
  if (sinceFull <= hold) return 1;
  final leaving = sinceFull - hold;
  if (leaving >= fadeOut) return 0;
  return 1 - leaving.inMicroseconds / fadeOut.inMicroseconds;
}
