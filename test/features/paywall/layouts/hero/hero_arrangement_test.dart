import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_arrangement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the stage', () {
    test('on a tall phone the card and the mascot are both at full size', () {
      final a = heroArrangementFor(const Size(390, 380));
      expect(a.kind, HeroStageKind.pair);
      expect(a.card.width, closeTo(197.8, 0.1));
      expect(a.mascot.width, closeTo(a.card.width * heroMascotShare, 1e-9));
    });

    test('the card never grows past its largest edge', () {
      final a = heroArrangementFor(const Size(800, 900));
      expect(a.card.width, heroCardMax);
      expect(a.mascot.width, heroCardMax * heroMascotShare);
    });

    test('on a short stage the card keeps its smallest edge and the mascot '
        'gives up size', () {
      final a = heroArrangementFor(const Size(375, 262));
      expect(a.kind, HeroStageKind.pair);
      expect(a.card.width, heroCardMin);
      expect(a.mascot.width, lessThan(heroCardMin * heroMascotShare));
      expect(a.mascot.width, greaterThan(heroCardMin * 0.5));
    });

    test('the mascot is up and to the left, the card down and to the right, '
        'and they overlap', () {
      for (final size in const [Size(375, 262), Size(390, 380)]) {
        final a = heroArrangementFor(size);
        expect(a.mascot.left, lessThan(a.card.left));
        expect(a.mascot.top, lessThan(a.card.top));
        expect(a.mascot.overlaps(a.card), isTrue);
        expect(
          a.mascot.right - a.card.left,
          closeTo(a.mascot.width * heroOverlapX, 1e-6),
        );
        expect(
          a.mascot.bottom - a.card.top,
          closeTo(a.mascot.height * heroOverlapY, 1e-6),
        );
      }
    });

    test('both stay inside the stage, under the room kept at the top', () {
      for (final size in const [
        Size(375, 262),
        Size(390, 380),
        Size(320, 240),
      ]) {
        final a = heroArrangementFor(size);
        final stage = Rect.fromLTWH(
          0,
          heroTopRoom - 0.001,
          size.width,
          size.height - heroTopRoom + 0.002,
        );
        expect(stage.contains(a.group.topLeft), isTrue, reason: '$size');
        expect(stage.contains(a.group.bottomRight), isTrue, reason: '$size');
      }
    });

    test('the pair is centred across the stage', () {
      final a = heroArrangementFor(const Size(375, 262));
      expect(a.group.center.dx, closeTo(375 / 2, 1e-6));
    });

    test('a stage too short for a preview holds the mascot alone', () {
      final a = heroArrangementFor(const Size(375, 150));
      expect(a.kind, HeroStageKind.mascot);
      expect(a.card, Rect.zero);
      expect(a.mascot.width, 150 - heroTopRoom);
      expect(a.mascot.center.dx, closeTo(375 / 2, 1e-6));
      expect(a.group, a.mascot);
    });

    test('a stage with no room for a face worth drawing holds nothing', () {
      final a = heroArrangementFor(const Size(375, 60));
      expect(a.kind, HeroStageKind.none);
      expect(heroArrangementFor(Size.zero).kind, HeroStageKind.none);
    });
  });
}
