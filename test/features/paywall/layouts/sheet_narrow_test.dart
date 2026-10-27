import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:flutter_test/flutter_test.dart';

SheetPlan _plan({
  double width = 320,
  double height = 568,
  double top = 20,
  double bottom = 0,
  double scale = 1,
  double? buy = 200,
  bool compact = true,
  int benefits = 5,
}) => sheetPlanFor(
  screenWidth: width,
  screenHeight: height,
  topInset: top,
  bottomInset: bottom,
  isCompact: compact,
  buyBlockHeight: buy,
  benefitCount: benefits,
  textScale: scale,
  hasAlso: true,
  showsLead: false,
);

void main() {
  group('a phone under 360 points wide', () {
    test('359 is narrow and 360 is not', () {
      expect(sheetIsNarrow(359), isTrue);
      expect(sheetIsNarrow(360), isFalse);
    });

    test('the face is 72 points and still', () {
      for (final scale in [1.0, 1.3, 2.0]) {
        final plan = _plan(scale: scale);
        expect(plan.faceSize, 72, reason: 'at $scale');
        expect(plan.isFaceStill, isTrue);
      }
    });

    test('its bottom edge is no lower than the sheet top edge', () {
      for (final height in [568.0, 640.0, 667.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final buy in [98.0, 200.0, null]) {
            final plan = _plan(height: height, scale: scale, buy: buy);
            expect(
              plan.faceTop + plan.faceSize,
              lessThanOrEqualTo(plan.sheetTop + 0.001),
              reason: '$height tall, text $scale, buy block $buy',
            );
          }
        }
      }
    });

    test('the lit row is still above the face', () {
      final plan = _plan();
      expect(plan.faceTop, greaterThanOrEqualTo(plan.litBottom));
    });

    test('the preview has the stage to itself', () {
      expect(_plan().showsFaceBesideCard, isFalse);
    });
  });

  group('a phone 360 points wide or more', () {
    test('keeps the face it had', () {
      final plan = _plan(width: 390, height: 844, top: 47, compact: false);
      expect(plan.faceSize, 150);
      expect(plan.isFaceStill, isFalse);
      expect(plan.faceShown, 0.37);
      expect(plan.showsFaceBesideCard, isTrue);
    });

    test('keeps the face behind the sheet at a large text size', () {
      final plan = _plan(
        width: 390,
        height: 844,
        top: 47,
        compact: false,
        scale: 2,
      );
      expect(plan.faceSize, 108);
      expect(plan.faceShown, SheetPlan.faceShownBehind);
      expect(plan.showsFaceBesideCard, isFalse);
    });
  });

  group('the room kept for the close control', () {
    test('a narrow phone keeps 48 points clear on the right', () {
      expect(sheetHeadlineEndRoomFor(width: 320, textScale: 1), 48);
    });

    test('a large text size keeps it on any phone', () {
      expect(sheetHeadlineEndRoomFor(width: 390, textScale: 2), 48);
      expect(sheetHeadlineEndRoomFor(width: 320, textScale: 2), 48);
    });

    test(
      'a regular phone at the default size keeps none: the stage is there',
      () {
        expect(sheetHeadlineEndRoomFor(width: 390, textScale: 1), 0);
      },
    );

    test('the headline is narrowed to leave it, past the side inset', () {
      expect(heroHeadlineWidth(width: 280, endRoom: 48), 280 - (48 - 20));
      expect(heroHeadlineWidth(width: 280), 280);
      expect(heroHeadlineWidth(width: 280, endRoom: 12), 280);
    });
  });
}
