import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_tile_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BentoTileText text({
    required Size inner,
    double titleWidth = 80,
    double lineWidth = 120,
    bool isLead = false,
  }) => bentoTileText(
    inner: inner,
    titleWidth: titleWidth,
    titleLineHeight: 16,
    lineWidth: lineWidth,
    lineLineHeight: 14,
    isLead: isLead,
  );

  group('bentoTileText', () {
    test('a short line sits beside the title on a wide tile', () {
      final result = text(inner: const Size(320, 60));
      expect(result.linePlace, BentoLinePlace.beside);
      expect(result.titleLines, 1);
      expect(result.height, 16);
    });

    test('the line goes under the title where the tile is tall', () {
      final result = text(inner: const Size(150, 130), lineWidth: 250);
      expect(result.linePlace, BentoLinePlace.below);
      expect(result.lineLines, 2);
      expect(result.height, 16 + bentoLineGap + 2 * 14);
    });

    test('a tile with no room hides the line and keeps the preview', () {
      final result = text(inner: const Size(150, 60), lineWidth: 250);
      expect(result.linePlace, BentoLinePlace.none);
      expect(result.height, 16);
      expect(result.previewBeside, isFalse);
    });

    test('a line that would take more than two lines is hidden', () {
      final result = text(inner: const Size(90, 300), lineWidth: 400);
      expect(result.linePlace, BentoLinePlace.none);
    });

    test('the lead keeps its line under the title, up to three lines', () {
      final short = text(inner: const Size(320, 200), isLead: true);
      expect(short.linePlace, BentoLinePlace.below);
      expect(short.lineLines, 1);

      final long = text(
        inner: const Size(200, 300),
        lineWidth: 500,
        isLead: true,
      );
      expect(long.linePlace, BentoLinePlace.below);
      expect(long.lineLines, 3);
    });

    test('a long title takes a second line only if the preview keeps room', () {
      final tall = text(inner: const Size(70, 90), lineWidth: 400);
      expect(tall.titleLines, 2);
      expect(tall.height, 32);

      final short = text(inner: const Size(70, 50), lineWidth: 400);
      expect(short.titleLines, 1);
    });

    test('words first: the title keeps both lines and the preview goes', () {
      const inner = Size(70, 40);
      expect(text(inner: inner, lineWidth: 400).titleLines, 1);
      final result = bentoTileText(
        inner: inner,
        titleWidth: 80,
        titleLineHeight: 16,
        lineWidth: 400,
        lineLineHeight: 14,
        isLead: false,
        wordsFirst: true,
      );
      expect(result.titleLines, 2);
      expect(result.height, 32);
    });

    test('the words never take more than the tile has', () {
      for (final width in [60.0, 110.0, 200.0, 330.0]) {
        for (final height in [20.0, 40.0, 70.0, 120.0, 400.0]) {
          for (final isLead in [false, true]) {
            final result = text(
              inner: Size(width, height),
              lineWidth: 260,
              isLead: isLead,
            );
            if (height >= 16) {
              expect(result.height, lessThanOrEqualTo(height));
            }
          }
        }
      }
    });

    test('a tile too short to stack puts the preview beside the title', () {
      final result = text(inner: const Size(300, 36), lineWidth: 400);
      expect(result.previewBeside, isTrue);
      expect(result.titleLines, 1);
      expect(result.linePlace, BentoLinePlace.none);
    });

    test('the lead never puts its preview beside the title', () {
      final result = text(
        inner: const Size(300, 36),
        lineWidth: 400,
        isLead: true,
      );
      expect(result.previewBeside, isFalse);
    });
  });

  group('bentoTitleSteps', () {
    test('a title that fits starts at its own size', () {
      expect(bentoTitleSteps(titleWidth: 80, innerWidth: 100).first, 1);
    });

    test('a title a little too wide is set smaller to stay on a line', () {
      final steps = bentoTitleSteps(titleWidth: 110, innerWidth: 100);
      expect(steps.first, lessThan(1));
      expect(110 * steps.last, lessThanOrEqualTo(100));
    });

    test('a much longer title wraps at full size first', () {
      final steps = bentoTitleSteps(titleWidth: 180, innerWidth: 100);
      expect(steps.first, 1);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], lessThan(steps[i - 1]));
      }
    });

    test('enlarged text may step down further, the default may not', () {
      double smallest(double scale) => bentoTitleSteps(
        titleWidth: 300,
        innerWidth: 100,
        textScale: scale,
      ).last;
      expect(smallest(1), 0.78);
      expect(smallest(1.5), lessThan(0.78));
      // Never under nine tenths of the size at the default scale.
      expect(smallest(1.5) * 1.5, greaterThanOrEqualTo(0.9));
      expect(smallest(1.3) * 1.3, greaterThanOrEqualTo(0.9));
    });
  });

  group('bentoEntrance', () {
    test('a tile starts small, low and unseen', () {
      final start = bentoEntrance(0, 0);
      expect(start.opacity, 0);
      expect(start.scale, closeTo(0.8, 0.001));
      expect(start.rise, closeTo(10, 0.001));
    });

    test('a tile rests full size, in place and upright', () {
      for (var turn = 0; turn < 7; turn++) {
        // A hair past the end, clear of rounding in the sum.
        final rest = bentoEntrance(turn, bentoEntranceEnd(7) + 0.001);
        expect(rest.opacity, 1);
        expect(rest.scale, 1);
        expect(rest.rise, 0);
      }
    });

    test('the frame a still layout rests on is past the entrance', () {
      // The layout rests on second 2.
      expect(bentoEntranceEnd(7), lessThan(2));
      expect(bentoEntranceEnd(12), lessThan(2));
    });

    test('each tile starts one beat after the tile before it', () {
      const t = bentoEntranceStart + 2 * bentoEntranceEach + 0.1;
      final third = bentoEntrance(2, t);
      final fourth = bentoEntrance(3, t);
      final ninth = bentoEntrance(8, t);
      expect(third.opacity, greaterThan(fourth.opacity));
      expect(fourth.opacity, greaterThan(0));
      expect(ninth.opacity, 0);
    });

    test('opacity stays between 0 and 1 through the overshoot', () {
      for (var t = 0.0; t < 1.2; t += 0.01) {
        final at = bentoEntrance(1, t);
        expect(at.opacity, inInclusiveRange(0, 1));
        expect(at.scale, inInclusiveRange(0.8, 1.1));
        expect(at.rise, inInclusiveRange(0, 10));
      }
    });
  });
}
