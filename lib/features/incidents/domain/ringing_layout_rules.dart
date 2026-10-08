// How the ringing alarm screen gives room to the message.
//
// The screen is a face, the word, the topic and the ring time, then the card
// with the message, over three pinned buttons. Someone woken by it needs the
// message, so the message wins: the face shrinks first and can go away, and
// when the title still does not fit, the lines above the card drop to a
// smaller text size. A message longer than all of that scrolls.
//
// The numbers are the screen's own: its spacing and the line heights of its
// text styles at the default text size.

import 'dart:math' as math;

/// The face at its full size, on a phone with room for it.
const double ringingFaceMax = 264;

/// The smallest face that still reads as the face. With less room than this
/// it is not drawn.
const double ringingFaceFloor = 64;

/// The most the system text size grows the word, the topic and the ring time
/// once the header is compact. See [ringingHeaderIsCompact].
const double ringingCompactTextScale = 1.3;

/// The room above the face, or above the word once the face is gone.
const double ringingTopGap = 32;

/// The same room once the header is compact.
const double ringingCompactTopGap = 16;

/// The room between the face and the word.
const double ringingFaceGap = 16;

/// The room the page keeps between the card and the pinned buttons, the
/// same the list leaves at the end of its scroll.
const double ringingBarClearance = 16;

const double _wordLine = 53;
const double _topicLine = 27;
const double _ringTimeLine = 24;
const double _pillLine = 19;

/// The word is one line that shrinks to the width of the screen, so past
/// this text size it gets no taller.
const double _wordMaxTextScale = 1.5;

/// The ring time runs to a second line once the text is larger than this.
const double _ringTimeWrapsAbove = 2.2;

/// How tall the lines above the card are, from under the status bar to the
/// top of the card, with no face.
///
/// [textScale] is how much the system has grown the text (1 is the default).
/// [openAlarms] above 1 adds the pill that counts them. [isCompact] is the
/// smaller header of [ringingHeaderIsCompact].
double ringingHeaderHeightFor({
  required double textScale,
  required int openAlarms,
  bool isCompact = false,
}) {
  final scale = isCompact
      ? math.min(textScale, ringingCompactTextScale)
      : textScale;
  final word = _wordLine * math.min(scale, _wordMaxTextScale);
  final topic = _topicLine * scale;
  final pill = openAlarms > 1 ? 8 + 12 + _pillLine * scale : 0.0;
  final ringTime =
      _ringTimeLine * scale * (scale > _ringTimeWrapsAbove ? 2 : 1);
  return (isCompact ? ringingCompactTopGap : ringingTopGap) +
      word +
      8 +
      topic +
      pill +
      8 +
      ringTime +
      16;
}

/// How tall the pinned buttons are, with the room under them.
///
/// A button is 48 high and grows with its label, which is set at 16. Eight
/// between two buttons and twelve under the last.
double ringingBarHeightFor({
  required double textScale,
  int pinnedButtons = 3,
}) {
  final button = math.max(48, 16 * textScale + 16);
  return pinnedButtons * button + 8 * (pinnedButtons - 1) + 12;
}

/// The size of the ringing face, or 0 when it is not drawn.
///
/// The face takes the room that is left once the whole message card sits
/// clear of the pinned buttons. [viewportHeight] is the height of the screen
/// inside its safe areas and [cardHeight] is how tall the card comes out
/// with this message at this text size. With less than
/// [ringingFaceFloor] left the face goes, and its room goes to the message.
double ringingFaceSizeFor({
  required double viewportHeight,
  required double textScale,
  required int openAlarms,
  required double cardHeight,
  int pinnedButtons = 3,
}) {
  final room =
      viewportHeight -
      ringingBarHeightFor(textScale: textScale, pinnedButtons: pinnedButtons) -
      ringingBarClearance -
      ringingHeaderHeightFor(textScale: textScale, openAlarms: openAlarms) -
      ringingFaceGap -
      cardHeight;
  if (room < ringingFaceFloor) return 0;
  return math.min(room, ringingFaceMax);
}

/// Whether the word, the topic and the ring time drop to the compact text
/// size.
///
/// True when the title of the message would end under the pinned buttons
/// even with the face gone. [titleBottom] is how far below the top of the
/// card the title ends. At the default text size the header is already
/// that small, so this only ever changes a screen with large text.
bool ringingHeaderIsCompact({
  required double viewportHeight,
  required double textScale,
  required int openAlarms,
  required double titleBottom,
  int pinnedButtons = 3,
}) {
  if (textScale <= ringingCompactTextScale) return false;
  final room =
      viewportHeight -
      ringingBarHeightFor(textScale: textScale, pinnedButtons: pinnedButtons) -
      ringingHeaderHeightFor(textScale: textScale, openAlarms: openAlarms) -
      titleBottom;
  return room < 0;
}
