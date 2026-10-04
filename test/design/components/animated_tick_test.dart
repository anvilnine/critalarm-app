import 'package:critalarm/design/components/animated_tick.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tickProgress', () {
    test('at 0 the ring is empty and no tick is drawn', () {
      final p = tickProgress(0);
      expect(p.fill, 0);
      expect(p.draw, 0);
    });

    test('at 1 the ring is full and the whole tick is drawn', () {
      final p = tickProgress(1);
      expect(p.fill, 1);
      expect(p.draw, 1);
    });

    test('the tick does not start while the ring is filling', () {
      for (var t = 0.0; t < tickFillEnds; t += 0.05) {
        expect(tickProgress(t).draw, 0, reason: 't = $t');
      }
    });

    test('the ring has finished by the time the tick starts', () {
      final landed = tickProgress(tickFillEnds);
      expect(landed.fill, 1);
      expect(landed.draw, 0);

      for (var t = tickFillEnds + 0.05; t < 1; t += 0.05) {
        final p = tickProgress(t);
        expect(p.fill, 1, reason: 't = $t');
        expect(p.draw, greaterThan(0), reason: 't = $t');
      }
    });

    test('the fill swells past the ring, a little, before it settles', () {
      var peak = 0.0;
      for (var t = 0.0; t <= tickFillEnds; t += 0.005) {
        final fill = tickProgress(t).fill;
        if (fill > peak) peak = fill;
      }
      expect(peak, greaterThan(1));
      expect(peak, lessThan(1.1));
    });

    test('the tick only ever grows', () {
      var last = 0.0;
      for (var t = tickFillEnds; t <= 1; t += 0.01) {
        final draw = tickProgress(t).draw;
        expect(draw, greaterThanOrEqualTo(last), reason: 't = $t');
        expect(draw, lessThanOrEqualTo(1), reason: 't = $t');
        last = draw;
      }
    });

    test('a time outside 0 to 1 is held at the nearest end', () {
      expect(tickProgress(-0.4), (fill: 0.0, draw: 0.0));
      expect(tickProgress(1.7), (fill: 1.0, draw: 1.0));
    });

    test('reduce motion jumps to the end', () {
      expect(tickProgress(0, reduceMotion: true), (fill: 0.0, draw: 0.0));
      for (final t in [0.01, 0.25, tickFillEnds, 0.75, 1.0]) {
        expect(
          tickProgress(t, reduceMotion: true),
          (fill: 1.0, draw: 1.0),
          reason: 't = $t',
        );
      }
    });
  });

  test('the whole tick takes two base transitions', () {
    expect(tickDuration, AppDurations.base * 2);
  });
}
