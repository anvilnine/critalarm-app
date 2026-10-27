/// How long the way out of a challenge is held for.
const Duration holdToSkip = Duration(seconds: 10);

/// How far a hold has come, from 0 to 1.
double holdProgress(Duration held) {
  if (held <= Duration.zero) return 0;
  if (held >= holdToSkip) return 1;
  return held.inMicroseconds / holdToSkip.inMicroseconds;
}

/// The whole seconds still to hold, counted down as a person reads it: 10
/// at the start, 1 during the last second, 0 once done.
int holdSecondsLeft(Duration held) {
  if (held >= holdToSkip) return 0;
  if (held <= Duration.zero) return holdToSkip.inSeconds;
  final left = holdToSkip - held;
  return (left.inMicroseconds / Duration.microsecondsPerSecond).ceil();
}

/// Whether the hold is done and the challenge is left.
bool holdIsDone(Duration held) => held >= holdToSkip;
