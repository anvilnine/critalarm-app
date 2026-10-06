import 'package:critalarm/features/incidents/domain/ringing_layout_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card of a short message at the default text size: a one-line title,
/// two lines of text and the line under them.
const double shortCard = 133;

/// How far into that card the title ends.
const double shortTitleBottom = 44;

void main() {
  group('ringingHeaderHeightFor', () {
    test('is the word, the topic and the ring time at the default size', () {
      // 32 above, the word 53, 8, the topic 27, 8, the ring time 24, and 16
      // down to the card.
      expect(ringingHeaderHeightFor(textScale: 1, openAlarms: 1), 168);
    });

    test('adds the pill once a second alarm is open', () {
      expect(ringingHeaderHeightFor(textScale: 1, openAlarms: 2), 168 + 39);
      expect(ringingHeaderHeightFor(textScale: 1, openAlarms: 0), 168);
    });

    test('grows with the text', () {
      final at1 = ringingHeaderHeightFor(textScale: 1, openAlarms: 1);
      final at2 = ringingHeaderHeightFor(textScale: 2, openAlarms: 1);
      final at3 = ringingHeaderHeightFor(textScale: 3.1, openAlarms: 1);
      expect(at2, greaterThan(at1));
      // The ring time runs to a second line by then.
      expect(at3, greaterThan(at2 + 24 * 3.1));
    });

    test('stops growing the word once it is as wide as the screen', () {
      final at15 = ringingHeaderHeightFor(textScale: 1.5, openAlarms: 1);
      final at2 = ringingHeaderHeightFor(textScale: 2, openAlarms: 1);
      // Only the topic and the ring time grew.
      expect(at2 - at15, closeTo((27 + 24) * 0.5, 0.001));
    });

    test('compact holds the text at 1.3 and halves the room above', () {
      final compact = ringingHeaderHeightFor(
        textScale: 3.1,
        openAlarms: 1,
        isCompact: true,
      );
      expect(compact, closeTo(16 + (53 + 27 + 24) * 1.3 + 8 + 8 + 16, 0.001));
      expect(
        compact,
        lessThan(ringingHeaderHeightFor(textScale: 3.1, openAlarms: 1)),
      );
    });

    test('compact never grows text that is smaller than its cap', () {
      expect(
        ringingHeaderHeightFor(textScale: 1, openAlarms: 1, isCompact: true),
        168 - 16,
      );
    });
  });

  group('ringingBarHeightFor', () {
    test('is three 48 buttons, 8 apart, with 12 under them', () {
      expect(ringingBarHeightFor(textScale: 1), 172);
      expect(ringingBarHeightFor(textScale: 2), 172);
    });

    test('a setup test has two buttons', () {
      expect(ringingBarHeightFor(textScale: 1, pinnedButtons: 2), 116);
    });

    test('grows once the label is taller than the button', () {
      expect(
        ringingBarHeightFor(textScale: 3.1),
        closeTo(3 * (16 * 3.1 + 16) + 16 + 12, 0.001),
      );
    });
  });

  group('ringingFaceSizeFor', () {
    double face({
      double height = 667,
      double textScale = 1,
      int openAlarms = 1,
      double cardHeight = shortCard,
      int pinnedButtons = 3,
    }) => ringingFaceSizeFor(
      viewportHeight: height,
      textScale: textScale,
      openAlarms: openAlarms,
      cardHeight: cardHeight,
      pinnedButtons: pinnedButtons,
    );

    test('is full size on a tall phone at the default text size', () {
      expect(face(height: 932), ringingFaceMax);
      expect(face(height: 932, openAlarms: 2), ringingFaceMax);
      expect(face(height: 844), ringingFaceMax);
    });

    test('shrinks on a small phone so the whole card is clear', () {
      final size = face();
      // 667 less the buttons 172, the room over them 16, the header 168,
      // the gap under the face 16 and the card 133.
      expect(size, 162);
      // The card then ends 16 above the buttons.
      final cardBottom = 168 + size + 16 + shortCard;
      expect(cardBottom, 667 - 172 - 16);
    });

    test('shrinks further when a second alarm adds the pill', () {
      expect(face(openAlarms: 2), 162 - 39);
      expect(face(openAlarms: 2), lessThan(face()));
    });

    test('shrinks as the message gets longer', () {
      expect(face(cardHeight: shortCard + 40), 122);
      expect(face(cardHeight: shortCard + 98), ringingFaceFloor);
    });

    test('is not drawn with less than the floor left', () {
      expect(face(cardHeight: shortCard + 99), 0);
      expect(face(cardHeight: 2000), 0);
      expect(face(height: 568), 0);
    });

    test('is not drawn on a small phone at large text', () {
      expect(face(textScale: 2, cardHeight: 400), 0);
      expect(face(textScale: 3.1, cardHeight: 779), 0);
    });

    test('is drawn smaller on a tall phone at large text', () {
      final size = face(height: 932, textScale: 2, cardHeight: 347);
      expect(size, greaterThan(ringingFaceFloor));
      expect(size, lessThan(ringingFaceMax));
    });

    test('a setup test, with two buttons, leaves the face more room', () {
      expect(face(pinnedButtons: 2), 162 + 56);
    });

    test('never comes out between nothing and the floor', () {
      for (var height = 400.0; height <= 1000; height += 7) {
        for (final scale in [1.0, 1.3, 2.0, 3.1]) {
          final size = face(height: height, textScale: scale);
          expect(
            size == 0 || (size >= ringingFaceFloor && size <= ringingFaceMax),
            isTrue,
            reason: 'height $height at $scale gave $size',
          );
        }
      }
    });
  });

  group('ringingHeaderIsCompact', () {
    bool compact({
      double height = 667,
      double textScale = 1,
      int openAlarms = 1,
      double titleBottom = shortTitleBottom,
    }) => ringingHeaderIsCompact(
      viewportHeight: height,
      textScale: textScale,
      openAlarms: openAlarms,
      titleBottom: titleBottom,
    );

    test('never at the default text size, whatever the title', () {
      expect(compact(), isFalse);
      expect(compact(titleBottom: 5000), isFalse);
      expect(compact(textScale: 1.3, titleBottom: 5000), isFalse);
      expect(compact(height: 480), isFalse);
    });

    test('not while the title fits above the buttons with the face gone', () {
      // A small phone at twice the text size: a three-line title.
      expect(compact(textScale: 2, titleBottom: 18 + 159), isFalse);
      expect(compact(height: 932, textScale: 3.1, titleBottom: 264), isFalse);
    });

    test('once the title would end under the buttons', () {
      // A small phone at the largest text size: a three-line title.
      expect(compact(textScale: 3.1, titleBottom: 18 + 246), isTrue);
      expect(compact(textScale: 2, titleBottom: 18 + 159 + 106), isTrue);
    });

    test('the pill takes room too', () {
      const titleBottom = 230.0;
      expect(compact(textScale: 2, titleBottom: titleBottom), isFalse);
      expect(
        compact(textScale: 2, openAlarms: 2, titleBottom: titleBottom),
        isTrue,
      );
    });

    test('a compact header means the face is already gone', () {
      for (final scale in [1.5, 2.0, 2.5, 3.1]) {
        for (var title = 40.0; title < 600; title += 20) {
          if (!compact(textScale: scale, titleBottom: title)) continue;
          expect(
            ringingFaceSizeFor(
              viewportHeight: 667,
              textScale: scale,
              openAlarms: 1,
              // A card is never shorter than its title.
              cardHeight: title,
            ),
            0,
          );
        }
      }
    });
  });
}
