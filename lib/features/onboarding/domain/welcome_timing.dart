// When things happen on the welcome screen, in seconds. The face opens the
// screen asleep, wakes, and hands over to the priority ladder. Every value is
// read by the animations and by the haptic cues, so the two cannot drift.

/// How long the sleeping face waits for a tap before it wakes by itself.
const double welcomeAutoWakeAfter = 1;

/// From the moment the face wakes to the moment the ladder starts: the hop
/// (0.45 s) and a short beat.
const double welcomeWakeTakes = 0.5;

/// How long the startled hop lasts.
const double welcomeWakeHopTakes = 0.45;

/// How many cards the ladder has.
const int ladderCardCount = 3;

/// When the first ladder card starts to slide in, on the ladder's own clock.
const double ladderFirstCardAt = 0;

/// The gap between one card starting and the next.
const double ladderCardGap = 0.25;

/// How long one card takes to slide into place.
const double ladderCardTakes = 0.45;

/// The pause between the last card landing and its alarm starting to ring.
const double ladderRingPause = 0.25;

/// When the ringing card is acknowledged, on the ladder's own clock.
const double ladderRingEndsAt = 6.6;

/// When card [index] (0 is the first) starts to slide in, on the ladder's
/// own clock.
double ladderCardStartsAt(int index) =>
    ladderFirstCardAt + index * ladderCardGap;

/// When card [index] is fully shown, on the ladder's own clock.
double ladderCardShownAt(int index) =>
    ladderCardStartsAt(index) + ladderCardTakes;

/// When the last card starts to ring, on the ladder's own clock.
double get ladderRingStartsAt =>
    ladderCardShownAt(ladderCardCount - 1) + ladderRingPause;

/// When the face wakes, in seconds since it appeared. [tappedAt] is when the
/// user tapped it, or null when they did not. A tap after it woke by itself
/// changes nothing.
double welcomeWokeAt({double? tappedAt}) =>
    tappedAt == null || tappedAt > welcomeAutoWakeAfter
    ? welcomeAutoWakeAfter
    : tappedAt;

/// When the ladder starts, in seconds since the face appeared.
double welcomeLadderStartsAt({double? tappedAt}) =>
    welcomeWokeAt(tappedAt: tappedAt) + welcomeWakeTakes;

/// When ladder card [index] is fully shown on first launch, in seconds since
/// the face appeared.
double welcomeCardShownAt(int index, {double? tappedAt}) =>
    welcomeLadderStartsAt(tappedAt: tappedAt) + ladderCardShownAt(index);
