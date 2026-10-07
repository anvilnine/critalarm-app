// When things happen in the three welcome stories, in seconds on each
// story's own clock. Every value is read by the drawings and by the haptic
// cues, so the two cannot drift.

// ---------------------------------------------------------------------------
// Story 1: it rings until you answer.

/// When the alert starts to slide onto the lock screen.
const double ringStoryAlertStartsAt = 0.25;

/// How long the alert takes to slide into place.
const double ringStoryAlertTakes = 0.35;

/// When the alert is in place.
const double ringStoryAlertLandsAt =
    ringStoryAlertStartsAt + ringStoryAlertTakes;

/// When the phone starts to ring and the alarm starts to take the screen.
const double ringStoryRingStartsAt = 1.1;

/// How long the alarm takes to cover the screen.
const double ringStoryTakeOverTakes = 0.3;

/// When the stop button presses itself, with no tap from the user.
const double ringStoryAutoStopAt = 5;

/// How long the acknowledged screen stays before the next story.
const double ringStoryAckHolds = 1.8;

/// When the alarm fills the screen and rings, with no tap. This is the first
/// full ring a new user sees after launch.
double get welcomeFirstRingAt => ringStoryRingStartsAt + ringStoryTakeOverTakes;

/// When the ring stops. [tappedAt] is when the user tapped the stop button,
/// or null when they did not. A tap before the phone rings, or after it
/// stopped by itself, changes nothing.
double ringStoryStopsAt({double? tappedAt}) =>
    tappedAt == null ||
        tappedAt < ringStoryRingStartsAt ||
        tappedAt > ringStoryAutoStopAt
    ? ringStoryAutoStopAt
    : tappedAt;

/// Whether the phone rings at [seconds].
bool ringStoryIsRinging(double seconds, {double? tappedAt}) =>
    seconds >= ringStoryRingStartsAt &&
    seconds < ringStoryStopsAt(tappedAt: tappedAt);

/// When the story is over and the next one starts.
double ringStoryEndsAt({double? tappedAt}) =>
    ringStoryStopsAt(tappedAt: tappedAt) + ringStoryAckHolds;

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
// Story 3: works with what you run. Three tools, one alert each.

/// How many tools send an alert.
const int toolsStoryToolCount = 3;

/// When the first tool sends.
const double toolsFirstSendAt = 0.6;

/// The gap between one tool sending and the next.
const double toolsSendGap = 1.3;

/// How long an alert travels from its tool to the phone.
const double toolsSendTakes = 0.7;

/// How long the whole story plays.
const double toolsStoryTakes = 6.4;

/// When tool [index] (0 is the first) sends its alert.
double toolsSendStartsAt(int index) => toolsFirstSendAt + index * toolsSendGap;

/// When the alert from tool [index] lands on the phone.
double toolsAlertLandsAt(int index) =>
    toolsSendStartsAt(index) + toolsSendTakes;

// ---------------------------------------------------------------------------
// The sleeping face. No longer part of first launch: Developer options still
// opens it as a preview.

/// How long the sleeping face waits for a tap before it wakes by itself.
const double welcomeAutoWakeAfter = 1;

/// How long the startled hop lasts.
const double welcomeWakeHopTakes = 0.45;
