import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_pips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heroPipsTopInsetFor', () {
    test('puts the pips 16 under the top of a screen with no status bar', () {
      // A 16 row centres 5 thick pips 5.5 down, so 10.5 goes above it.
      final inset = heroPipsTopInsetFor(safeTop: 0, gap: 16);
      expect(inset + (16 - HeroPipsPainter.thickness) / 2, 16);
    });

    test('counts the status bar', () {
      final inset = heroPipsTopInsetFor(safeTop: 24, gap: 16);
      expect(inset + (16 - HeroPipsPainter.thickness) / 2, 40);
    });

    test('adds nothing when the row already reaches past 16', () {
      expect(heroPipsTopInsetFor(safeTop: 0, gap: 60), 0);
    });
  });
}
