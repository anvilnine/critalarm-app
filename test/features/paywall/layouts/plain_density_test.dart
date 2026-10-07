import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_one_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/plain/plain_density.dart';
import 'package:flutter_test/flutter_test.dart';

/// Made-up heights, each density shorter than the one before.
double _heightOf(PlainDensity density) => switch (density) {
  PlainDensity.full => 400,
  PlainDensity.titles => 320,
  PlainDensity.bare => 240,
  PlainDensity.bareNoFace => 180,
};

void main() {
  group('the plain layout at a large text size', () {
    PlainDensity at(double room) =>
        plainDensityFor(room: room, heightOf: _heightOf);

    test('everything is drawn when it fits', () {
      expect(at(456), PlainDensity.full);
      expect(at(400), PlainDensity.full);
    });

    test('the second lines go first, then the pictures, then the face', () {
      expect(at(399), PlainDensity.titles);
      expect(at(319), PlainDensity.bare);
      expect(at(239), PlainDensity.bareNoFace);
    });

    test('with no room at all it is the shortest, which still names every '
        'benefit', () {
      expect(at(100), PlainDensity.bareNoFace);
    });
  });

  group('the one benefit composition', () {
    test('the face and the card keep their chosen sizes when there is room, '
        'however much', () {
      expect(oneBenefitSizes(296), (face: 96.0, card: 200.0));
      expect(oneBenefitSizes(600), (face: 96.0, card: 200.0));
    });

    test('short of room the face gets smaller, and the card does not', () {
      expect(oneBenefitSizes(295), (face: 64.0, card: 200.0));
      expect(oneBenefitSizes(264), (face: 64.0, card: 200.0));
    });

    test('then the face goes, and only then the card gives up height', () {
      expect(oneBenefitSizes(263), (face: 0.0, card: 200.0));
      expect(oneBenefitSizes(160), (face: 0.0, card: 160.0));
    });

    test('the card is never shorter than its least height', () {
      expect(oneBenefitSizes(40), (face: 0.0, card: oneBenefitMinCard));
    });
  });
}
