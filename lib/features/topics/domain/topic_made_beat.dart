// The beat after setup makes the first topic: the topic becomes a card and
// drops into a small picture of Home, so the user sees where it lives. Then
// setup moves on by itself.
//
// The times and the maths live here, with no widget, so they test on their
// own. The widget is `TopicMadeBeat`.

/// The card fades in above the picture. `AppDurations.quick`.
const Duration topicCardAppearTakes = Duration(milliseconds: 150);

/// The card travels down to its row. `AppDurations.slow`.
const Duration topicCardDropTakes = Duration(milliseconds: 400);

/// The card rests in its row before setup moves on.
const Duration topicMadeHoldTakes = Duration(milliseconds: 650);

/// The whole beat: appear, drop, hold.
const Duration topicMadeBeatTakes = Duration(milliseconds: 1200);

/// When the card is felt to land. The drop eases out, so the card is within
/// a point of its row 60% of the way through the drop, well before the
/// curve ends. The tap goes with what the eye sees.
const Duration topicCardLandsAt = Duration(milliseconds: 390);

/// How long the finished picture stays up when the phone asks for reduced
/// motion. Nothing moves and nothing is felt.
const Duration topicMadeStillTakes = Duration(milliseconds: 800);

/// How far the card has faded in at [elapsed], from 0 to 1.
double topicCardShownAt(Duration elapsed) => _progress(
  elapsed,
  from: Duration.zero,
  takes: topicCardAppearTakes,
);

/// How far along its drop the card is at [elapsed], from 0 (above the
/// picture) to 1 (in its row). Linear: the widget puts the curve on it.
double topicCardDropAt(Duration elapsed) => _progress(
  elapsed,
  from: topicCardAppearTakes,
  takes: topicCardDropTakes,
);

/// Whether the card lands in the stretch of time after [from] up to and
/// including [to]. The widget asks once per frame, so the tap is felt once.
bool topicCardLandsBetween(Duration from, Duration to) =>
    from < topicCardLandsAt && topicCardLandsAt <= to;

double _progress(
  Duration elapsed, {
  required Duration from,
  required Duration takes,
}) {
  final done =
      (elapsed - from).inMicroseconds / takes.inMicroseconds.toDouble();
  if (done <= 0) return 0;
  if (done >= 1) return 1;
  return done;
}

/// The picture is drawn at this size and scaled to the room it gets, so a
/// large text size never changes what is in it.
const double topicMadePictureDesignWidth = 418;
const double topicMadePictureDesignHeight = 544;

/// The widest the picture is drawn, on any phone.
const double topicMadePictureMaxWidth = 320;

/// The share of the screen height the picture may take. The top bar and the
/// line above the picture need the rest, on a 667-high phone too.
const double topicMadePictureHeightShare = 0.62;

/// How wide to draw the picture in [roomWidth] of free width on a screen
/// [viewportHeight] high.
double topicMadePictureWidthFor({
  required double roomWidth,
  required double viewportHeight,
}) {
  final widthForHeight =
      viewportHeight *
      topicMadePictureHeightShare *
      topicMadePictureDesignWidth /
      topicMadePictureDesignHeight;
  var width = topicMadePictureMaxWidth;
  if (roomWidth < width) width = roomWidth;
  if (widthForHeight < width) width = widthForHeight;
  return width < 0 ? 0 : width;
}
