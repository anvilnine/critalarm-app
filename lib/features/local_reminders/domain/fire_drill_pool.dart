import 'dart:math';

/// Picks one of the ten fire drill lines (idea 20, folded into idea 1).
abstract final class FireDrillPool {
  static const int size = 10;

  /// Lines 3, 5 and 8 (zero-based 2, 4 and 7) say nothing rang. They are
  /// only true when no real alarm was acked on the topic since its last
  /// test.
  static const Set<int> nothingRangLines = {2, 4, 7};

  /// Line 1 (zero-based 0), "Last test alarm: {days} days ago". Only true
  /// once the topic was tested in the app.
  static const int lastTestLine = 0;

  static int pick({
    required Random random,
    required int? lastIndex,
    required bool somethingRang,
    bool neverTested = false,
  }) {
    final choices = [
      for (var i = 0; i < size; i++)
        if (i != lastIndex &&
            !(somethingRang && nothingRangLines.contains(i)) &&
            !(neverTested && i == lastTestLine))
          i,
    ];
    return choices[random.nextInt(choices.length)];
  }

  /// Seeded by the fire day, so re-planning on every resume keeps the same
  /// line for the same Saturday instead of reshuffling it.
  static Random randomFor(DateTime fireAt) =>
      Random(fireAt.year * 10000 + fireAt.month * 100 + fireAt.day);
}
