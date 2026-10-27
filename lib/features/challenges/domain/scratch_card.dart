import 'dart:math';

/// How many digits the code under the card has.
const int scratchCodeLength = 4;

/// The code shown on a Personalize picture, the same every time.
const String scratchCodeSample = '4827';

/// The code for [seed]: four digits, the first never zero, so it reads as
/// one number. The same seed always gives the same code, so a rebuild of
/// the screen never changes it.
String scratchCode(int seed) => '${1000 + Random(seed).nextInt(9000)}';

/// The code with a space between the digits, so a screen reader says four
/// digits and not one number in the thousands.
String scratchCodeSpelled(String code) => code.split('').join(' ');

/// What a typed code is: right, still short, or wrong.
enum ScratchCodeVerdict { right, waiting, wrong }

/// Judges [typed] against [code]. Right as soon as it is the code. Wrong
/// once it is as long as the code, or when [isFinal] (done pressed) and
/// something was typed. Until then it waits, so a correct start is never
/// cleared.
ScratchCodeVerdict scratchCodeJudge({
  required String typed,
  required String code,
  bool isFinal = false,
}) {
  if (scratchCodeMatches(typed: typed, code: code)) {
    return ScratchCodeVerdict.right;
  }
  final text = typed.trim();
  if (text.isEmpty) return ScratchCodeVerdict.waiting;
  if (isFinal || text.length >= code.length) return ScratchCodeVerdict.wrong;
  return ScratchCodeVerdict.waiting;
}

/// Whether [typed] is [code], digit for digit. Spaces around it do not
/// matter. A plain comparison of two numbers on screen: nothing is read
/// from a message and nothing is sent.
bool scratchCodeMatches({required String typed, required String code}) {
  if (!RegExp(r'^[0-9]+$').hasMatch(code)) return false;
  return typed.trim() == code;
}

/// The numbers of the scratch rule, in one place.
abstract final class ScratchRule {
  /// Cells across and down. At 16 by 8 a cell is about 21 by 16 points on
  /// the card (335 by 128 on a 375 point screen): smaller than a fingertip,
  /// so a stroke always clears whole cells, and few enough that a check is
  /// 128 comparisons.
  static const int columns = 16;
  static const int rows = 8;

  /// The part of the card the code is printed in, as fractions of its
  /// width and height. Four digits of 40 point mono type with their
  /// spacing are about 150 points wide and 48 tall, centred. The area is
  /// that plus a margin, so text at 1.3 times the size is still inside.
  static const double codeLeft = 0.2;
  static const double codeRight = 0.8;
  static const double codeTop = 0.2;
  static const double codeBottom = 0.8;

  /// The share of the code's cells that must be cleared. At 0.6 two
  /// strokes across the digits are enough and one thin swipe is not. The
  /// number is a judgement and wants a look on a real phone.
  static const double revealAt = 0.6;

  /// How far around the finger a stroke clears, in points. 22 is half of
  /// the 44 point touch target, about the width of a fingertip.
  static const double brushRadius = 22;

  /// How long the card is rubbed before the reveal button is offered.
  static const Duration revealButtonAfter = Duration(seconds: 5);
}

/// Which parts of the card have been rubbed off, on a coarse grid.
///
/// Positions are fractions of the card: 0 to 1 across and 0 to 1 down. The
/// widget divides by its own size, so the grid knows no points.
final class ScratchGrid {
  ScratchGrid()
    : _cleared = List<bool>.filled(
        ScratchRule.columns * ScratchRule.rows,
        false,
      );

  final List<bool> _cleared;

  static double _centerX(int column) => (column + 0.5) / ScratchRule.columns;

  static double _centerY(int row) => (row + 0.5) / ScratchRule.rows;

  /// Whether the cell at [column], [row] lies in the code's area.
  static bool isCodeCell(int column, int row) {
    final x = _centerX(column);
    final y = _centerY(row);
    return x > ScratchRule.codeLeft &&
        x < ScratchRule.codeRight &&
        y > ScratchRule.codeTop &&
        y < ScratchRule.codeBottom;
  }

  /// How many cells the code's area has.
  static final int codeCells = () {
    var count = 0;
    for (var row = 0; row < ScratchRule.rows; row++) {
      for (var column = 0; column < ScratchRule.columns; column++) {
        if (isCodeCell(column, row)) count++;
      }
    }
    return count;
  }();

  bool isCleared(int column, int row) =>
      _cleared[row * ScratchRule.columns + column];

  /// Clears every cell whose centre the finger passed over on its way from
  /// ([fromX], [fromY]) to ([toX], [toY]), with a brush [radiusX] wide and
  /// [radiusY] tall. A tap is a stroke from a point to itself.
  ///
  /// A fast finger gives few points far apart, so the line between them is
  /// walked in steps of half a cell and nothing is jumped over.
  void rub({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required double radiusX,
    required double radiusY,
  }) {
    if (radiusX <= 0 || radiusY <= 0) return;
    final values = [fromX, fromY, toX, toY, radiusX, radiusY];
    if (values.any((value) => !value.isFinite)) return;
    final acrossCells = (toX - fromX).abs() * ScratchRule.columns;
    final downCells = (toY - fromY).abs() * ScratchRule.rows;
    // Never more steps than a stroke from one corner to the other needs.
    final steps = min(
      (max(acrossCells, downCells) * 2).ceil(),
      (ScratchRule.columns + ScratchRule.rows) * 2,
    );
    for (var step = 0; step <= steps; step++) {
      final t = steps == 0 ? 0.0 : step / steps;
      _dab(
        fromX + (toX - fromX) * t,
        fromY + (toY - fromY) * t,
        radiusX,
        radiusY,
      );
    }
  }

  void _dab(double x, double y, double radiusX, double radiusY) {
    for (var row = 0; row < ScratchRule.rows; row++) {
      final dy = (_centerY(row) - y) / radiusY;
      if (dy.abs() > 1) continue;
      for (var column = 0; column < ScratchRule.columns; column++) {
        final dx = (_centerX(column) - x) / radiusX;
        if (dx * dx + dy * dy <= 1) {
          _cleared[row * ScratchRule.columns + column] = true;
        }
      }
    }
  }

  /// The share of the code's area that is cleared, from 0 to 1.
  double get codeShareCleared {
    var count = 0;
    for (var row = 0; row < ScratchRule.rows; row++) {
      for (var column = 0; column < ScratchRule.columns; column++) {
        if (isCodeCell(column, row) && isCleared(column, row)) count++;
      }
    }
    return count / codeCells;
  }

  /// Whether enough of the code shows for the card to count as revealed.
  bool get isRevealed => codeShareCleared >= ScratchRule.revealAt;
}

/// Adds up how long a finger has been on the card, over as many touches as
/// it takes. Times are readings of one clock that only runs forward.
final class ScratchRub {
  Duration _before = Duration.zero;
  Duration? _downAt;

  /// The finger came down at [now]. A second finger changes nothing.
  void down(Duration now) => _downAt ??= now;

  /// The finger left at [now].
  void up(Duration now) {
    final downAt = _downAt;
    if (downAt == null) return;
    if (now > downAt) _before += now - downAt;
    _downAt = null;
  }

  /// How long the card has been rubbed in all, as of [now].
  Duration rubbed(Duration now) {
    final downAt = _downAt;
    if (downAt == null || now <= downAt) return _before;
    return _before + (now - downAt);
  }

  /// How much more rubbing until the reveal button is offered, as of
  /// [now]. Zero once it is.
  Duration untilButton(Duration now) {
    final left = ScratchRule.revealButtonAfter - rubbed(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the reveal button is offered, as of [now].
  bool isButtonOffered(Duration now) => untilButton(now) == Duration.zero;
}
