import 'package:critalarm/design/components/inputs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fittedInputTextScale', () {
    double fit(
      double width, {
      double system = 2,
      double max = 200,
      double floor = 1,
    }) => fittedInputTextScale(
      systemScale: system,
      widthAtSystemScale: width,
      maxWidth: max,
      floorScale: floor,
    );

    test('text that fits keeps the phone text scale', () {
      expect(fit(180), 2);
      expect(fit(200), 2);
    });

    test('an empty field keeps the phone text scale', () {
      expect(fit(0), 2);
    });

    test('text that is too wide steps down until it fits', () {
      // 250 wide at 2.0 needs 2.0 * 200 / 250.
      expect(fit(250), closeTo(1.6, 0.0001));
    });

    test('it never goes below the default size', () {
      expect(fit(1000), 1);
    });

    test('a floor of its own is kept', () {
      expect(fit(1000, floor: 1.2), 1.2);
    });

    test('a phone set below the floor keeps its own scale', () {
      expect(fit(1000, system: 0.85), 0.85);
      expect(fit(300, system: 0.85), 0.85);
    });

    test('it never grows past the phone text scale', () {
      expect(fit(100, system: 1.3), 1.3);
    });
  });
}
