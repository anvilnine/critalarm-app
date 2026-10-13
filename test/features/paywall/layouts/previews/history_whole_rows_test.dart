import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizes = [
    Size.square(120),
    Size.square(160),
    Size.square(197),
    Size.square(200),
    Size(350, 300),
  ];

  /// The tops of every row and of the line, in the card, for a list that has
  /// been scrolled by [scroll].
  List<double> rowTops(
    HistoryPreviewLayout layout,
    int inside,
    int beyond,
    double scroll,
  ) => [
    for (var i = 0; i < inside; i++) layout.rowTop(i) - scroll,
    for (var j = 0; j < beyond; j++) layout.beyondRowTop(j, inside) - scroll,
  ];

  group('a history card at rest', () {
    test('starts on a whole row below the tag', () {
      for (final size in sizes) {
        final layout = historyPreviewLayoutFor(size);
        for (final inside in [0, 1, 2, 3, 7]) {
          for (final beyond in [1, 4, 7]) {
            final scroll = layout.restScrollFor(inside);
            final tops = rowTops(layout, inside, beyond, scroll);
            // No row is cut by the line the tag ends on.
            for (final top in tops) {
              final isCut =
                  top < historyPreviewTagRoom - 0.001 &&
                  top + layout.rowHeight > historyPreviewTagRoom + 0.001;
              expect(
                isCut,
                isFalse,
                reason: '$size, $inside inside, $beyond past: row at $top',
              );
            }
          }
        }
      }
    });

    test('the first row shown stands exactly at the tag room', () {
      for (final size in sizes) {
        final layout = historyPreviewLayoutFor(size);
        for (final (inside, beyond) in [(2, 4), (3, 7), (7, 7), (1, 4)]) {
          final scroll = layout.restScrollFor(inside);
          final tops = rowTops(layout, inside, beyond, scroll)
            ..removeWhere((t) => t < historyPreviewTagRoom - 0.001);
          expect(tops.first, closeTo(historyPreviewTagRoom, 0.001));
        }
      }
    });

    test('keeps the line in the card with a row each side of it', () {
      for (final size in sizes) {
        final layout = historyPreviewLayoutFor(size);
        const inside = 3;
        final scroll = layout.restScrollFor(inside);
        final line =
            layout.listOffset(inside) + layout.lineTop(inside) - scroll;
        expect(line, greaterThanOrEqualTo(historyPreviewTagRoom));
        expect(line + layout.lineSlot, lessThan(size.height));
      }
    });
  });

  group('a history card at the top of its loop', () {
    test('starts on a whole row below the tag', () {
      for (final size in sizes) {
        final layout = historyPreviewLayoutFor(size);
        // Nothing is scrolled: the first row is where the list starts.
        expect(layout.rowTop(0), historyPreviewTagRoom);
      }
    });
  });
}
