import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_tag_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const List<PaywallIntroTagSide> _above = [
  PaywallIntroTagSide.above,
  PaywallIntroTagSide.below,
];
const List<PaywallIntroTagSide> _below = [
  PaywallIntroTagSide.below,
  PaywallIntroTagSide.above,
];

// A 390 wide phone with its status bar taken out.
const _bounds = Rect.fromLTRB(0, 49, 390, 844);

// A mascot 120 across, in the middle, with air all round it.
const _mascot = Rect.fromLTWH(135, 300, 120, 120);

PaywallIntroTagPlace? _place({
  Rect mascot = _mascot,
  double width = 112,
  Rect bounds = _bounds,
  List<Rect> keepOut = const [],
  List<PaywallIntroTagSide> order = _above,
}) => paywallIntroTagPlace(
  mascot: mascot,
  width: width,
  bounds: bounds,
  keepOut: keepOut,
  order: order,
);

void main() {
  group('with nothing near the mascot', () {
    test('the tag stands over its head, its middle over the mascot', () {
      final place = _place()!;
      expect(place.side, PaywallIntroTagSide.above);
      expect(place.pill.center.dx, _mascot.center.dx);
      expect(place.tailX, _mascot.center.dx);
      // The tail's tip is the gap above the mascot.
      expect(place.box.bottom, _mascot.top - paywallIntroTagGap);
      expect(place.pill.height, paywallIntroTagHeight);
    });

    test('a layout with words over the head asks for under the foot', () {
      final place = _place(order: _below)!;
      expect(place.side, PaywallIntroTagSide.below);
      expect(place.box.top, _mascot.bottom + paywallIntroTagGap);
      expect(place.pill.top, place.tail.bottom);
      expect(place.pill.center.dx, _mascot.center.dx);
    });

    test('the tag is never wider than its largest', () {
      final place = _place(width: 400)!;
      expect(place.width, paywallIntroTagMaxWidth);
    });
  });

  group('the edges', () {
    test('over the head it does not reach the status bar', () {
      final low = _mascot.shift(const Offset(0, -240));
      // 60 points of air over the head is under the 38 the tag needs, but
      // the status bar takes it.
      expect(low.top, 60);
      expect(_place(mascot: low)!.side, PaywallIntroTagSide.below);
      expect(
        _place(mascot: low, order: const [PaywallIntroTagSide.above]),
        isNull,
      );
    });

    test('a mascot at the edge keeps the tag on screen', () {
      final place = _place(mascot: const Rect.fromLTWH(0, 300, 100, 100))!;
      expect(place.pill.left, greaterThanOrEqualTo(paywallIntroTagEdge));
      expect(place.tailX, inInclusiveRange(12, 88));
    });

    test('no room under the foot, and none over it, is no tag', () {
      final tall = _mascot.shift(const Offset(0, 480));
      expect(
        _place(mascot: tall, order: const [PaywallIntroTagSide.below]),
        isNull,
      );
    });
  });

  group('words and pictures', () {
    // The lead's line, right under a mascot that stands over it.
    final line = Rect.fromLTWH(20, _mascot.bottom + 8, 350, 40);
    // The headline, right over its head.
    final headline = Rect.fromLTWH(20, _mascot.top - 14 - 80, 350, 80);

    test('a line under the foot sends the tag over the head', () {
      final place = _place(order: _below, keepOut: [line])!;
      expect(place.side, PaywallIntroTagSide.above);
    });

    test('a headline over the head sends the tag under the foot', () {
      final place = _place(keepOut: [headline])!;
      expect(place.side, PaywallIntroTagSide.below);
    });

    test('words on both sides leave no tag', () {
      expect(_place(keepOut: [headline, line]), isNull);
      expect(_place(order: _below, keepOut: [headline, line]), isNull);
    });

    test('the tag keeps its distance from words', () {
      // The tag over the head starts at 262 and keeps 4 points clear.
      final above = _place()!;
      expect(above.pill.top, 262);
      final touching = Rect.fromLTRB(20, 200, 370, above.pill.top - 3);
      final clear = Rect.fromLTRB(20, 200, 370, above.pill.top - 4);
      expect(_place(keepOut: [touching])!.side, PaywallIntroTagSide.below);
      expect(_place(keepOut: [clear])!.side, PaywallIntroTagSide.above);
    });

    test('a card at the side slides the tag away from it', () {
      // A card over the right of the stage, its corner under the mascot.
      final card = Rect.fromLTWH(
        _mascot.center.dx + 20,
        _mascot.bottom - 40,
        160,
        160,
      );
      final centred = _place(order: _below)!;
      expect(centred.pill.overlaps(card), isTrue);

      final place = _place(order: _below, keepOut: [card])!;
      expect(place.side, PaywallIntroTagSide.below);
      expect(place.pill.inflate(paywallIntroTagClear).overlaps(card), isFalse);
      expect(place.pill.right, lessThan(card.left));
      // Still pointing at the mascot.
      expect(
        place.tailX,
        inInclusiveRange(_mascot.left + 12, _mascot.right - 12),
      );
      expect(place.tailX, inInclusiveRange(place.pill.left, place.pill.right));
    });

    test('a card the tag cannot slide clear of leaves no tag', () {
      final wide = Rect.fromLTWH(0, _mascot.bottom - 40, 390, 200);
      expect(
        _place(
          order: _below,
          keepOut: [wide, Rect.fromLTWH(0, 0, 390, _mascot.top)],
        ),
        isNull,
      );
    });

    test('words far from the mascot change nothing', () {
      const far = [
        Rect.fromLTWH(20, 700, 350, 40),
        Rect.fromLTWH(20, 60, 350, 40),
      ];
      final alone = _place()!;
      final place = _place(keepOut: far)!;
      expect(place.left, alone.left);
      expect(place.top, alone.top);
      expect(place.side, alone.side);
    });
  });

  group('whatever the layout', () {
    test('a tag that is shown never touches a rect it keeps clear of', () {
      final rects = <Rect>[
        for (var x = 0.0; x < 390; x += 65)
          for (var y = 100.0; y < 700; y += 55) Rect.fromLTWH(x, y, 90, 30),
      ];
      var shown = 0;
      for (var left = 0.0; left <= 270; left += 18) {
        for (var top = 80.0; top <= 640; top += 23) {
          final mascot = Rect.fromLTWH(left, top, 120, 120);
          for (var i = 0; i < rects.length; i += 7) {
            final keepOut = [rects[i], rects[(i + 11) % rects.length]];
            for (final order in [_above, _below]) {
              final place = _place(
                mascot: mascot,
                keepOut: keepOut,
                order: order,
              );
              if (place == null) continue;
              shown++;
              for (final rect in keepOut) {
                expect(rect.overlaps(place.pill), isFalse);
                expect(rect.overlaps(place.tail), isFalse);
              }
              expect(place.box.left, greaterThanOrEqualTo(_bounds.left));
              expect(place.box.top, greaterThanOrEqualTo(_bounds.top));
              expect(place.box.right, lessThanOrEqualTo(_bounds.right));
              expect(place.box.bottom, lessThanOrEqualTo(_bounds.bottom));
              expect(
                place.tailX,
                inInclusiveRange(mascot.left + 12, mascot.right - 12),
              );
            }
          }
        }
      }
      expect(shown, greaterThan(100), reason: 'the sweep tried real cases');
    });
  });
}
