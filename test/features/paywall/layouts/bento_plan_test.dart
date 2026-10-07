import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every count the drawn plans cover, and some past them.
  const counts = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12];

  group('bentoPlan', () {
    for (final isCompact in [false, true]) {
      for (final count in counts) {
        final name = '$count tiles${isCompact ? ', compact' : ''}';
        final plan = bentoPlan(count, isCompact: isCompact);

        test('$name: one cell per benefit', () {
          expect(plan.cells, hasLength(count));
        });

        test('$name: fills the grid with no hole and no overlap', () {
          final covered = List<int>.filled(plan.columns * plan.rows, 0);
          for (final cell in plan.cells) {
            expect(cell.w, greaterThan(0));
            expect(cell.h, greaterThan(0));
            expect(cell.x, greaterThanOrEqualTo(0));
            expect(cell.y, greaterThanOrEqualTo(0));
            expect(cell.right, lessThanOrEqualTo(plan.columns));
            expect(cell.bottom, lessThanOrEqualTo(plan.rows));
            for (var y = cell.y; y < cell.bottom; y++) {
              for (var x = cell.x; x < cell.right; x++) {
                covered[y * plan.columns + x]++;
              }
            }
          }
          expect(covered.every((times) => times == 1), isTrue);
        });

        test('$name: the lead is first, top left and the largest', () {
          final lead = plan.cells.first;
          expect((lead.x, lead.y), (0, 0));
          for (final cell in plan.cells.skip(1)) {
            expect(
              lead.area / (plan.columns * plan.rows),
              greaterThanOrEqualTo(cell.area / (plan.columns * plan.rows)),
            );
          }
        });
      }
    }

    test('one benefit is the whole grid, full width', () {
      for (final isCompact in [false, true]) {
        final plan = bentoPlan(1, isCompact: isCompact);
        expect(plan.cells.single.w, plan.columns);
        expect(plan.cells.single.h, plan.rows);
      }
    });

    test('a count under one is drawn as one', () {
      expect(bentoPlan(0, isCompact: false).cells, hasLength(1));
    });

    test('seven is the drawn plan: lead, two beside it, four under', () {
      final plan = bentoPlan(7, isCompact: false);
      expect(plan.columns, 6);
      expect(plan.cells.first, const BentoCell(0, 0, 4, 26));
      expect(plan.cells[1], const BentoCell(4, 0, 2, 13));
      expect(plan.cells[2], const BentoCell(4, 13, 2, 23));
    });

    test('a compact phone gives the lead a smaller share of the height', () {
      for (final count in [4, 5]) {
        double share(BentoPlan plan) => plan.cells.first.h / plan.rows;
        expect(
          share(bentoPlan(count, isCompact: true)),
          lessThan(share(bentoPlan(count, isCompact: false))),
        );
      }
    });
  });

  group('bentoCellRect', () {
    const size = Size(350, 420);
    const gap = 8.0;

    test('tiles stay inside the grid and reach its edges', () {
      for (final count in counts) {
        final plan = bentoPlan(count, isCompact: false);
        final rects = [
          for (final cell in plan.cells) bentoCellRect(cell, plan, size, gap),
        ];
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(-0.001));
          expect(rect.top, greaterThanOrEqualTo(-0.001));
          expect(rect.right, lessThanOrEqualTo(size.width + 0.001));
          expect(rect.bottom, lessThanOrEqualTo(size.height + 0.001));
        }
        double most(double Function(Rect) of) =>
            rects.map(of).reduce((a, b) => a > b ? a : b);
        expect(most((r) => r.right), closeTo(size.width, 0.001));
        expect(most((r) => r.bottom), closeTo(size.height, 0.001));
      }
    });

    test('no two tiles touch: the gap is kept between neighbours', () {
      for (final count in counts) {
        final plan = bentoPlan(count, isCompact: true);
        final rects = [
          for (final cell in plan.cells) bentoCellRect(cell, plan, size, gap),
        ];
        for (var a = 0; a < rects.length; a++) {
          for (var b = a + 1; b < rects.length; b++) {
            // Grown by just under half a gap each, neighbours still miss.
            expect(
              rects[a]
                  .inflate(gap / 2 - 0.01)
                  .overlaps(
                    rects[b].inflate(gap / 2 - 0.01),
                  ),
              isFalse,
              reason: '$count tiles: $a and $b',
            );
          }
        }
      }
    });

    test('a side by side pair is one gap apart', () {
      final plan = bentoPlan(3, isCompact: false);
      final left = bentoCellRect(plan.cells[1], plan, size, gap);
      final right = bentoCellRect(plan.cells[2], plan, size, gap);
      expect(right.left - left.right, closeTo(gap, 0.001));
      expect(left.width, closeTo(right.width, 0.001));
    });
  });

  group('bentoEntranceOrder', () {
    test('gives every tile its own turn, the lead first', () {
      for (final count in counts) {
        final plan = bentoPlan(count, isCompact: false);
        final turns = bentoEntranceOrder(plan);
        expect(turns.first, 0);
        expect(turns.toSet(), {for (var i = 0; i < count; i++) i});
      }
    });

    test('runs top to bottom, then left to right', () {
      final plan = bentoPlan(5, isCompact: false);
      final turns = bentoEntranceOrder(plan);
      // Cells: lead, bottom left, bottom right, side top, side bottom.
      expect(turns, [0, 3, 4, 1, 2]);
    });
  });
}
