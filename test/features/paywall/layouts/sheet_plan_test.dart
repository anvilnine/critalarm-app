import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SheetPlan planFor({
    double screenHeight = 844,
    double topInset = 47,
    double bottomInset = 22,
    bool isCompact = false,
    double? buyBlockHeight = 200,
    int benefitCount = 4,
    double textScale = 1,
  }) => sheetPlanFor(
    screenHeight: screenHeight,
    topInset: topInset,
    bottomInset: bottomInset,
    isCompact: isCompact,
    buyBlockHeight: buyBlockHeight,
    benefitCount: benefitCount,
    textScale: textScale,
  );

  group('sheetPlanFor', () {
    test('the lit row is above the sheet with room for the mascot', () {
      for (final compact in [false, true]) {
        final plan = planFor(isCompact: compact);
        expect(plan.sheetTop - plan.litBottom, greaterThan(plan.faceAbove));
      }
    });

    test('a tall buy block takes every quiet row above the lit one', () {
      expect(planFor().rowsAbove, 0);
    });

    test('a short buy block leaves a quiet row above the lit one', () {
      final plan = planFor(buyBlockHeight: 98, benefitCount: 5);
      expect(plan.rowsAbove, greaterThan(0));
      expect(
        844 - plan.sheetTop,
        greaterThanOrEqualTo(
          sheetWantedHeight(
            buyBlockHeight: 98,
            benefitCount: 5,
            bottomInset: 22,
          ),
        ),
      );
    });

    test('the sheet takes about two thirds of a regular phone', () {
      final share = (844 - planFor().sheetTop) / 844;
      expect(share, inInclusiveRange(0.6, 0.75));
    });

    test('never more quiet rows than the page has', () {
      final plan = planFor(screenHeight: 2000, buyBlockHeight: 98);
      expect(plan.rowsAbove, SheetPlan.maxRowsAbove);
    });

    test('before the buy block is measured the plan is only a guess', () {
      final plan = planFor(buyBlockHeight: null);
      expect(plan.isMeasured, isFalse);
      expect(plan.rowsAbove, 0);
    });

    test('past the default text size no quiet row is kept', () {
      final plan = planFor(buyBlockHeight: 98, textScale: 1.3);
      expect(plan.rowsAbove, 0);
      expect(plan.isMeasured, isTrue);
    });

    test('a regular phone keeps the back row and the title line', () {
      expect(planFor().header, SheetHeader.full);
    });

    test('a short phone gives up the header to keep the large preview', () {
      final plan = planFor(
        screenHeight: 667,
        topInset: 20,
        bottomInset: 0,
        isCompact: true,
        buyBlockHeight: 202,
      );
      expect(plan.header, SheetHeader.none);
      expect(
        667 - plan.sheetTop - 202 - sheetWordsHeight(4),
        greaterThanOrEqualTo(sheetStageLarge),
      );
    });

    test('a short phone with a short buy block keeps its title', () {
      final plan = planFor(
        screenHeight: 667,
        topInset: 20,
        bottomInset: 0,
        isCompact: true,
        buyBlockHeight: 98,
        benefitCount: 5,
      );
      expect(plan.header, SheetHeader.full);
    });

    test('too short for the large preview whatever goes: the back row', () {
      final plan = planFor(
        screenHeight: 568,
        topInset: 20,
        bottomInset: 0,
        isCompact: true,
      );
      expect(plan.header, SheetHeader.inline);
      expect(plan.rowsAbove, 0);
    });
  });

  group('the mascot on the edge', () {
    test('in front of the sheet it is whole and large', () {
      expect(planFor().standsInFront, isTrue);
      expect(planFor().faceSize, greaterThanOrEqualTo(140));
      expect(planFor(isCompact: true).faceSize, greaterThanOrEqualTo(100));
      // Less than half of it is above the edge: the rest is on the sheet.
      expect(planFor().faceShown, lessThan(0.5));
    });

    test('past the default text size it stands behind and looks over', () {
      final plan = planFor(textScale: 1.3);
      expect(plan.standsInFront, isFalse);
      expect(plan.faceShown, SheetPlan.faceShownBehind);
      expect(plan.faceSize, lessThan(planFor().faceSize));
    });

    test('a hop keeps clear of the lit row', () {
      for (final compact in [false, true]) {
        final plan = planFor(isCompact: compact);
        // A reaction hops 8 percent of the mascot's size.
        expect(
          plan.peekGap - plan.faceAbove,
          greaterThanOrEqualTo(plan.faceSize * 0.08),
        );
      }
    });
  });

  group('sheetStageArrangement', () {
    test('a full stage holds the preview at its largest, centred', () {
      final a = sheetStageArrangement(const Size(390, sheetStageFull));
      expect(a.kind, HeroStageKind.pair);
      expect(a.card.width, heroCardMax);
      expect(a.card.height, heroCardMax);
      expect(a.card.center, const Offset(195, sheetStageFull / 2));
    });

    test('the preview shrinks with the stage down to the large class', () {
      final a = sheetStageArrangement(const Size(390, 190));
      expect(a.card.width, 190 - sheetCardRoom * 2);
      expect(a.card.width, greaterThanOrEqualTo(heroCardMin));
    });

    test('never past its largest in a taller stage', () {
      final a = sheetStageArrangement(const Size(390, 300));
      expect(a.card.width, heroCardMax);
      expect(a.card.center.dy, 150);
    });

    test('a stage too short for the large class holds the middle one', () {
      final a = sheetStageArrangement(const Size(375, 150));
      expect(a.kind, HeroStageKind.pair);
      expect(a.card.width, sheetCardMedium);
      expect(a.card.top, 15);
    });

    test('a stage too short for that holds nothing', () {
      final a = sheetStageArrangement(const Size(375, 100));
      expect(a.kind, HeroStageKind.none);
    });

    test('beside the mascot the preview keeps clear of it and the cross', () {
      for (final (width, face) in [(390.0, 150.0), (375.0, 112.0)]) {
        for (final height in [172.0, 190.0, sheetStageFull, 300.0]) {
          final a = sheetStageArrangement(Size(width, height), face: face);
          expect(a.kind, HeroStageKind.pair);
          expect(a.card.width, greaterThanOrEqualTo(heroCardMin));
          // The mascot may lie over the card's corner, as on the approved
          // stage, and no further.
          expect(
            a.card.left,
            greaterThanOrEqualTo(sheetSide + face * (1 - heroOverlapX) - 0.01),
          );
          expect(
            a.card.right,
            lessThanOrEqualTo(width - sheetCrossRoom + 0.01),
          );
          expect(a.card.center.dy, height / 2);
        }
      }
    });

    test('the mascot is not on the stage, and the air sits on the card', () {
      final a = sheetStageArrangement(const Size(390, 200));
      expect(a.mascot.isEmpty, isTrue);
      expect(a.group, a.card);
    });
  });
}
