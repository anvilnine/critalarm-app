import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('setupFaceSizeFor', () {
    test('keeps the base size at the default text size on any screen', () {
      expect(setupFaceSizeFor(textScale: 1, viewportHeight: 667), 80);
      expect(setupFaceSizeFor(textScale: 1, viewportHeight: 300), 80);
      expect(setupFaceSizeFor(textScale: 0.85, viewportHeight: 667), 80);
    });

    test('shrinks as the text grows', () {
      final at13 = setupFaceSizeFor(textScale: 1.3, viewportHeight: 844);
      final at2 = setupFaceSizeFor(textScale: 2, viewportHeight: 932);
      expect(at13, closeTo(80 / 1.3, 0.001));
      expect(at2, 40);
      expect(at2, lessThan(at13));
    });

    test('never goes below the floor while it is drawn', () {
      final size = setupFaceSizeFor(textScale: 2.7, viewportHeight: 932);
      expect(size, 32);
    });

    test('goes away when the screen is short for the text', () {
      expect(setupFaceSizeFor(textScale: 2, viewportHeight: 667), 0);
      expect(setupFaceSizeFor(textScale: 3.1, viewportHeight: 932), 0);
    });

    test('follows the base it is given', () {
      expect(
        setupFaceSizeFor(textScale: 2, viewportHeight: 932, base: 96),
        48,
      );
    });
  });

  group('intro hero room', () {
    test('keeps 380 at the default size and none above it', () {
      expect(introHeroMinHeightFor(1), 380);
      expect(introHeroMinHeightFor(0.9), 380);
      expect(introHeroMinHeightFor(1.01), 0);
      expect(introHeroMinHeightFor(2), 0);
    });

    test('is drawn only when it has room', () {
      expect(introHeroFits(380), isTrue);
      expect(introHeroFits(120), isTrue);
      expect(introHeroFits(119.9), isFalse);
      expect(introHeroFits(0), isFalse);
    });
  });

  group('setupButtonHeightFor', () {
    test('is the minimum height at the default size', () {
      expect(
        setupButtonHeightFor(minHeight: 60, fontSize: 19, textScale: 1),
        60,
      );
      expect(
        setupButtonHeightFor(minHeight: 36, fontSize: 14, textScale: 1),
        36,
      );
    });

    test('grows once the label needs more than the minimum', () {
      expect(
        setupButtonHeightFor(minHeight: 36, fontSize: 14, textScale: 2),
        44,
      );
      expect(
        setupButtonHeightFor(minHeight: 60, fontSize: 19, textScale: 3),
        73,
      );
    });
  });

  group('setupPinsFirstMessageRow', () {
    test('pins the row up to a moderately large size', () {
      expect(setupPinsFirstMessageRow(1), isTrue);
      expect(setupPinsFirstMessageRow(1.3), isTrue);
      expect(setupPinsFirstMessageRow(1.5), isTrue);
    });

    test('moves the row into the page above that', () {
      expect(setupPinsFirstMessageRow(1.6), isFalse);
      expect(setupPinsFirstMessageRow(2), isFalse);
    });
  });
}
