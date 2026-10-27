import 'package:critalarm/design/components/status_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// How visible the words going out and the words coming in are, [progress] of
/// the way through a swap. The switcher runs the incoming controller from 0 to
/// 1 and the outgoing one from 1 to 0.
({double out, double inn}) _opacities(double progress) => (
  out: statusCardSwapOut.transform(1 - progress),
  inn: statusCardSwapIn.transform(progress),
);

void main() {
  group('the label and foot swap', () {
    test('the old words are fully there when the swap starts', () {
      final start = _opacities(0);
      expect(start.out, 1);
      expect(start.inn, 0);
    });

    test('the new words are fully there when the swap ends', () {
      final end = _opacities(1);
      expect(end.out, 0);
      expect(end.inn, 1);
    });

    test('two words are never on screen at the same time', () {
      for (var i = 0; i <= 200; i++) {
        final opacities = _opacities(i / 200);
        final smaller = opacities.out < opacities.inn
            ? opacities.out
            : opacities.inn;
        expect(smaller, 0, reason: 'at ${i / 200}');
      }
    });

    test('the old words are gone by the half and the new ones start there', () {
      expect(_opacities(0.5).out, 0);
      expect(_opacities(0.5).inn, 0);
      expect(_opacities(0.25).out, inInclusiveRange(0.01, 0.99));
      expect(_opacities(0.75).inn, inInclusiveRange(0.01, 0.99));
    });

    test('the old words only ever fade and the new ones only ever appear', () {
      var lastOut = 1.0;
      var lastIn = 0.0;
      for (var i = 0; i <= 100; i++) {
        final opacities = _opacities(i / 100);
        expect(opacities.out, lessThanOrEqualTo(lastOut));
        expect(opacities.inn, greaterThanOrEqualTo(lastIn));
        lastOut = opacities.out;
        lastIn = opacities.inn;
      }
    });
  });
}
