import 'dart:math';

import 'package:critalarm/features/local_reminders/domain/fire_drill_pool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never picks the same line twice in a row', () {
    for (var seed = 0; seed < 200; seed++) {
      final index = FireDrillPool.pick(
        random: Random(seed),
        lastIndex: 3,
        somethingRang: false,
      );
      expect(index, isNot(3));
    }
  });

  test('skips the "nothing rang" lines after a real alarm', () {
    for (var seed = 0; seed < 200; seed++) {
      final index = FireDrillPool.pick(
        random: Random(seed),
        lastIndex: null,
        somethingRang: true,
      );
      expect(FireDrillPool.nothingRangLines.contains(index), isFalse);
    }
  });

  test('skips the "last test" line for a topic never tested', () {
    for (var seed = 0; seed < 200; seed++) {
      final index = FireDrillPool.pick(
        random: Random(seed),
        lastIndex: null,
        somethingRang: false,
        neverTested: true,
      );
      expect(index, isNot(FireDrillPool.lastTestLine));
    }
  });

  test('reaches every line when nothing holds it back', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      seen.add(
        FireDrillPool.pick(
          random: Random(seed),
          lastIndex: null,
          somethingRang: false,
        ),
      );
    }
    expect(seen, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
  });

  test('the same fire day always gives the same line', () {
    final a = FireDrillPool.randomFor(DateTime(2026, 9, 26, 10));
    final b = FireDrillPool.randomFor(DateTime(2026, 9, 26, 18));
    expect(a.nextInt(1000), b.nextInt(1000));
  });
}
