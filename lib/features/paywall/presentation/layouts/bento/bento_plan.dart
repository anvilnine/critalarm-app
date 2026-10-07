import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One tile's place on the bento grid, in grid units.
@immutable
class BentoCell {
  const BentoCell(this.x, this.y, this.w, this.h);

  final int x;
  final int y;
  final int w;
  final int h;

  int get right => x + w;
  int get bottom => y + h;
  int get area => w * h;

  @override
  bool operator ==(Object other) =>
      other is BentoCell &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'BentoCell($x, $y, $w, $h)';
}

/// Where every tile of a bento grid sits. The cells are in benefit order,
/// so the first cell is the lead tile.
@immutable
class BentoPlan {
  const BentoPlan({
    required this.columns,
    required this.rows,
    required this.cells,
  });

  final int columns;
  final int rows;
  final List<BentoCell> cells;
}

/// The grid for [count] benefits.
///
/// Every plan fills its grid: no hole and no overlap. The first benefit
/// gets the largest tile, in the top left. One benefit gets the whole grid,
/// so it reads as a lead with its text and never as a lonely square.
///
/// A compact phone gives the tiles under the lead a larger share of the
/// height, because a strip there still has to hold a title and a preview.
BentoPlan bentoPlan(int count, {required bool isCompact}) {
  final n = count < 1 ? 1 : count;
  return switch (n) {
    1 => const BentoPlan(columns: 1, rows: 1, cells: [BentoCell(0, 0, 1, 1)]),
    // The lead over one strip.
    2 => const BentoPlan(
      columns: 6,
      rows: 5,
      cells: [BentoCell(0, 0, 6, 3), BentoCell(0, 3, 6, 2)],
    ),
    // The lead over two halves.
    3 => const BentoPlan(
      columns: 6,
      rows: 5,
      cells: [
        BentoCell(0, 0, 6, 3),
        BentoCell(0, 3, 3, 2),
        BentoCell(3, 3, 3, 2),
      ],
    ),
    // The lead beside a tall tile, over two strips.
    4 => BentoPlan(
      columns: 5,
      rows: (isCompact ? 4 : 5) + 4,
      cells: [
        BentoCell(0, 0, 3, isCompact ? 4 : 5),
        BentoCell(3, 0, 2, isCompact ? 4 : 5),
        BentoCell(0, isCompact ? 4 : 5, 5, 2),
        BentoCell(0, (isCompact ? 4 : 5) + 2, 5, 2),
      ],
    ),
    // The lead beside two small tiles, over two halves. The second and
    // third benefits get the halves, which are the larger.
    5 => BentoPlan(
      columns: 6,
      rows: isCompact ? 13 : 16,
      cells: [
        BentoCell(0, 0, 4, isCompact ? 8 : 10),
        BentoCell(0, isCompact ? 8 : 10, 3, isCompact ? 5 : 6),
        BentoCell(3, isCompact ? 8 : 10, 3, isCompact ? 5 : 6),
        BentoCell(4, 0, 2, isCompact ? 4 : 5),
        BentoCell(4, isCompact ? 4 : 5, 2, isCompact ? 4 : 5),
      ],
    ),
    6 => const BentoPlan(
      columns: 6,
      rows: 46,
      cells: [
        BentoCell(0, 0, 4, 26),
        BentoCell(4, 0, 2, 13),
        BentoCell(4, 13, 2, 13),
        BentoCell(0, 26, 2, 20),
        BentoCell(2, 26, 4, 10),
        BentoCell(2, 36, 4, 10),
      ],
    ),
    7 => const BentoPlan(
      columns: 6,
      rows: 56,
      cells: [
        BentoCell(0, 0, 4, 26),
        BentoCell(4, 0, 2, 13),
        BentoCell(4, 13, 2, 23),
        BentoCell(0, 26, 4, 10),
        BentoCell(0, 36, 2, 20),
        BentoCell(2, 36, 4, 10),
        BentoCell(2, 46, 4, 10),
      ],
    ),
    _ => _leadOverRows(n),
  };
}

/// More benefits than the drawn plans cover: the lead across the top, then
/// rows of three, and a last row of one or two that still spans the width.
BentoPlan _leadOverRows(int count) {
  const leadHeight = 13;
  const rowHeight = 10;
  final cells = <BentoCell>[const BentoCell(0, 0, 6, leadHeight)];
  var left = count - 1;
  var y = leadHeight;
  while (left > 0) {
    final inRow = left >= 3 ? 3 : left;
    final width = 6 ~/ inRow;
    for (var i = 0; i < inRow; i++) {
      cells.add(BentoCell(i * width, y, width, rowHeight));
    }
    left -= inRow;
    y += rowHeight;
  }
  return BentoPlan(columns: 6, rows: y, cells: cells);
}

/// Where [cell] sits, in points, on a grid of [size] with [gap] between
/// tiles. Tiles on an edge of the plan touch the edge of the grid.
Rect bentoCellRect(BentoCell cell, BentoPlan plan, Size size, double gap) {
  double along(int unit, int units, double extent) =>
      unit / units * (extent + gap);

  final left = along(cell.x, plan.columns, size.width);
  final top = along(cell.y, plan.rows, size.height);
  final right = along(cell.right, plan.columns, size.width) - gap;
  final bottom = along(cell.bottom, plan.rows, size.height) - gap;
  return Rect.fromLTRB(left, top, right, bottom);
}

/// The order the tiles come in: top to bottom, then left to right. Entry
/// `i` is the turn of the tile at `plan.cells[i]`, from 0.
List<int> bentoEntranceOrder(BentoPlan plan) {
  final byPlace = [for (var i = 0; i < plan.cells.length; i++) i]
    ..sort((a, b) {
      final first = plan.cells[a];
      final second = plan.cells[b];
      return first.y != second.y
          ? first.y.compareTo(second.y)
          : first.x.compareTo(second.x);
    });
  final turns = List<int>.filled(plan.cells.length, 0);
  for (var turn = 0; turn < byPlace.length; turn++) {
    turns[byPlace[turn]] = turn;
  }
  return turns;
}
