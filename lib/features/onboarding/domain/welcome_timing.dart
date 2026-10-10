// When things happen in the welcome stories, in seconds on each story's own
// clock. Every value is read by the drawings and by the haptic cues, so the
// two cannot drift.

// ---------------------------------------------------------------------------
// Story 2: only what matters rings. Three alerts, one per card.

/// How many cards the ladder has.
const int ladderCardCount = 3;

/// When the first ladder card starts to slide in.
const double ladderFirstCardAt = 0.2;

/// The gap between one card starting and the next.
const double ladderCardGap = 0.9;

/// How long one card takes to slide into place.
const double ladderCardTakes = 0.45;

/// The pause between the last card landing and its alarm starting to ring.
const double ladderRingPause = 0.25;

/// When the ringing card is acknowledged.
const double ladderRingEndsAt = 5.6;

/// How long the whole story plays.
const double ladderStoryTakes = 7.4;

/// When card [index] (0 is the first) starts to slide in.
double ladderCardStartsAt(int index) =>
    ladderFirstCardAt + index * ladderCardGap;

/// When card [index] is fully shown.
double ladderCardShownAt(int index) =>
    ladderCardStartsAt(index) + ladderCardTakes;

/// When the last card starts to ring.
double get ladderRingStartsAt =>
    ladderCardShownAt(ladderCardCount - 1) + ladderRingPause;

// ---------------------------------------------------------------------------
// The sleeping face. No longer part of first launch: Developer options still
// opens it as a preview.

/// How long the sleeping face waits for a tap before it wakes by itself.
const double welcomeAutoWakeAfter = 1;

/// How long the startled hop lasts.
const double welcomeWakeHopTakes = 0.45;
