import 'package:critalarm/design/components/pass_stack.dart';
import 'package:flutter_test/flutter_test.dart';

PassStackLayout _phone({
  double width = 390,
  double height = 844,
  double textScale = 1,
  int count = 5,
  double safeTop = 47,
  double safeBottom = 34,
  double? contentHeight,
}) => PassStackLayout.of(
  width: width,
  height: height,
  textScale: textScale,
  count: count,
  safeTop: safeTop,
  safeBottom: safeBottom,
  contentHeight: contentHeight,
);

void main() {
  group('PassStackLayout on a 390 by 844 phone with a 47 point inset', () {
    final layout = _phone();

    test('puts the ring at 52 and the first card at 122', () {
      expect(layout.headerTop, 52);
      expect(layout.stackTop, 122);
    });

    test('steps the tops by 134', () {
      expect(layout.mode, PassStackMode.overlapped);
      expect(layout.step, 134);
      expect(layout.tops, [122, 256, 390, 524, 658]);
    });

    test('makes four cards 260 tall and the last 220', () {
      expect(layout.heights, [260, 260, 260, 260, 220]);
    });

    test('does not scroll, because the last card is meant to bleed', () {
      expect(layout.scrollExtent, 844);
    });

    test('sets the cards 12 points in from the column', () {
      expect(layout.cardLeft, 12);
      expect(layout.cardWidth, 366);
    });
  });

  group('the last card', () {
    test('with three passes reaches 34 points past the bottom edge', () {
      final layout = _phone(count: 3);
      expect(layout.tops, [122, 256, 390]);
      expect(layout.heights, [260, 260, 844 - 390 + 34]);
      expect(layout.tops.last + layout.heights.last, 844 + 34);
    });

    test('with one pass is as tall as the rest of the display', () {
      final layout = _phone(count: 1);
      expect(layout.heights, [844 - 122 + 34]);
    });

    test('is never under 220, so a short display scrolls', () {
      final layout = _phone(width: 375, height: 667, safeTop: 20);
      expect(layout.heights.last, 220);
      expect(layout.scrollExtent, greaterThan(667));
      expect(
        layout.scrollExtent,
        layout.tops.last + layout.heights.last - 34,
      );
    });

    test('on a phone on its side scrolls and keeps its size', () {
      final layout = _phone(width: 844, height: 390, safeTop: 0);
      expect(layout.stackTop, 75);
      expect(layout.heights, [260, 260, 260, 260, 220]);
      expect(layout.scrollExtent, greaterThan(390));
    });
  });

  group('the mode', () {
    test('overlaps under text scale 1.3', () {
      expect(_phone().mode, PassStackMode.overlapped);
      expect(_phone(textScale: 1.29).mode, PassStackMode.overlapped);
    });

    test('is flat from 1.3', () {
      expect(_phone(textScale: 1.3).mode, PassStackMode.flat);
      expect(_phone(textScale: 2).mode, PassStackMode.flat);
    });

    test('flat leaves the cards to size themselves', () {
      final layout = _phone(textScale: 2);
      expect(layout.tops, isEmpty);
      expect(layout.heights, isEmpty);
      expect(layout.stackTop, 122);
      expect(layout.bottomPadding, 34 + 24);
    });
  });

  group('the band step', () {
    test('is 134 for an ordinary value', () {
      expect(_phone(textScale: 1.2).step, 134);
    });

    test('grows when a two-line value needs more', () {
      final layout = _phone(contentHeight: 130);
      expect(layout.step, 160);
      expect(layout.tops, [122, 282, 442, 602, 762]);
    });

    test('is label plus gap plus two value lines for the default', () {
      // 11 * 1.2 + 4 + 2 * 30 * 1.05
      expect(passBandContentHeight(1), closeTo(80.2, 0.01));
      expect(
        passBandContentHeight(1.2),
        greaterThan(passBandContentHeight(1)),
      );
    });

    test('is the same label height past the chrome limit', () {
      final a = passBandContentHeight(1.3) - passBandContentHeight(1.5);
      const valueOnly = 2 * 30 * 1.05 * (1.3 - 1.5);
      expect(a, closeTo(valueOnly, 0.001));
    });
  });

  group('the column', () {
    test('is the whole width up to 560', () {
      expect(_phone(width: 320).columnWidth, 320);
      expect(_phone().columnWidth, 390);
      expect(_phone(width: 320).columnLeft, 0);
    });

    test('stops at 560 and centres', () {
      final wide = _phone(width: 600);
      expect(wide.columnWidth, 560);
      expect(wide.columnLeft, 20);
      final tablet = _phone(width: 1024, height: 768);
      expect(tablet.columnWidth, 560);
      expect(tablet.columnLeft, 232);
      expect(tablet.cardLeft, 244);
      expect(tablet.cardWidth, 536);
    });
  });
}
