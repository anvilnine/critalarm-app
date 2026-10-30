import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/design/components/bottom_sheets.dart';
import 'package:critalarm/design/components/dialogs.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Uneven side insets: the iPhone Duo keeps a system strip 84 wide down the
// right edge of its outer display and of its inner display opened flat.
void main() {
  group('AppScreenColumns side insets', () {
    test('a phone with no side insets keeps its gutters at 0', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 390,
        size: const AppSize(390, 844, isIphone: true),
        padding: const EdgeInsets.only(top: 59, bottom: 34),
        hasTabBar: false,
      );
      expect(columns.gutterLeft, 0);
      expect(columns.gutterRight, 0);
      expect(columns.contentLeft, 0);
      expect(columns.contentWidth, 390);
    });

    test('the Duo outer display keeps content out of the strip only', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 466,
        size: const AppSize(466, 678, isIphone: true),
        padding: const EdgeInsets.only(right: 84, bottom: 34),
      );
      expect(columns.gutter, 0);
      expect(columns.gutterLeft, 0);
      expect(columns.gutterRight, 84);
      expect(columns.contentWidth, 466 - 84);
    });

    test('a gutter wider than the inset is kept as it is', () {
      // A phone on its side, notch 47 each side: the 560 column already
      // clears it, so nothing moves.
      final columns = AppScreenColumns.resolve(
        boxWidth: 844,
        size: const AppSize(844, 390, isIphone: true),
        padding: const EdgeInsets.symmetric(horizontal: 47),
        hasTabBar: false,
      );
      expect(columns.gutterLeft, (844 - 560) / 2);
      expect(columns.gutterRight, (844 - 560) / 2);
    });

    test('a side with no inset is never given the other side\'s', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 678,
        size: const AppSize(678, 466, isIphone: true),
        padding: const EdgeInsets.only(right: 84),
        hasTabBar: false,
      );
      expect(columns.gutterLeft, (678 - 560) / 2);
      expect(columns.gutterRight, 84);
    });

    test('two panes with the rail on the right give the list no inset', () {
      // The Duo inner display opened flat: the rail sits left of the strip,
      // so the list pane is nowhere near it.
      final columns = AppScreenColumns.resolve(
        boxWidth: 951,
        size: const AppSize(951, 669, isIphone: true),
        padding: const EdgeInsets.only(right: 84),
        hasDetail: true,
      );
      expect(columns.twoPane, isTrue);
      expect(columns.railOnRight, isTrue);
      expect(columns.gutterLeft, 0);
      expect(columns.gutterRight, 0);
    });

    test('two panes with a left inset at the list edge keep it', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 951,
        size: const AppSize(951, 669, isIphone: true),
        padding: const EdgeInsets.only(left: 40),
        hasDetail: true,
      );
      expect(columns.twoPane, isTrue);
      expect(columns.listLeft, 0);
      expect(columns.gutterLeft, 40);
      expect(columns.gutterRight, 0);
    });

    test('a book end pane keeps the strip at its far edge', () {
      final columns = AppScreenColumns.forWindow(
        window: const Size(951, 669),
        padding: const EdgeInsets.only(right: 84),
        fold: AppFold.fromFeatures(const [
          DisplayFeature(
            bounds: Rect.fromLTWH(475.5, 0, 0, 669),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ], const Size(951, 669)),
        isIphone: true,
        hasStage: true,
      );
      expect(columns.inFoldPane, isTrue);
      expect(columns.gutterRight, 84);
      expect(columns.contentLeft + columns.contentWidth, 951 - 84);
    });
  });

  group('AppScreenColumns.sideInsetsWithin', () {
    test('a span that touches an edge keeps that edge whole', () {
      expect(
        AppScreenColumns.sideInsetsWithin(
          const EdgeInsets.only(left: 10, right: 84),
          boxWidth: 951,
          left: 0,
          right: 951,
        ),
        const EdgeInsets.only(left: 10, right: 84),
      );
    });

    test('a span in from an edge keeps none of it', () {
      expect(
        AppScreenColumns.sideInsetsWithin(
          const EdgeInsets.only(left: 10, right: 84),
          boxWidth: 951,
          left: 340,
          right: 779,
        ),
        EdgeInsets.zero,
      );
    });

    test('a span part way into an inset keeps the part it covers', () {
      expect(
        AppScreenColumns.sideInsetsWithin(
          const EdgeInsets.only(right: 84),
          boxWidth: 951,
          left: 0,
          right: 900,
        ),
        const EdgeInsets.only(right: 33),
      );
    });
  });

  group('navAreaInsideSides', () {
    test('no side insets leave the area as it is', () {
      const area = Rect.fromLTWH(0, 0, 390, 844);
      expect(
        navAreaInsideSides(
          area,
          const Size(390, 844),
          const EdgeInsets.only(top: 59, bottom: 34),
        ),
        area,
      );
    });

    test('the Duo strip comes off the right', () {
      expect(
        navAreaInsideSides(
          const Rect.fromLTWH(0, 0, 466, 678),
          const Size(466, 678),
          const EdgeInsets.only(right: 84, bottom: 34),
        ),
        const Rect.fromLTRB(0, 0, 382, 678),
      );
    });

    test('a start pane away from the strip keeps its width', () {
      const pane = Rect.fromLTRB(0, 0, 459.5, 669);
      expect(
        navAreaInsideSides(
          pane,
          const Size(951, 669),
          const EdgeInsets.only(right: 84),
        ),
        pane,
      );
    });
  });

  group('AppBottomSheet.sheetPaddingFor', () {
    test('a full-width sheet adds each side its own inset', () {
      expect(
        AppBottomSheet.sheetPaddingFor(
          padding: const EdgeInsets.only(right: 84, bottom: 34),
          window: 466,
          sheet: 466,
        ),
        const EdgeInsets.fromLTRB(16, 10, 100, 0),
      );
    });

    test('a phone with no side insets keeps 16', () {
      expect(
        AppBottomSheet.sheetPaddingFor(
          padding: const EdgeInsets.only(bottom: 34),
          window: 390,
          sheet: 390,
        ),
        const EdgeInsets.fromLTRB(16, 10, 16, 0),
      );
    });

    test('a sheet capped in from the notch adds nothing', () {
      expect(
        AppBottomSheet.sheetPaddingFor(
          padding: const EdgeInsets.symmetric(horizontal: 47),
          window: 844,
          sheet: 640,
        ),
        const EdgeInsets.fromLTRB(16, 10, 16, 0),
      );
    });
  });

  group('dialogInsetPaddingFor', () {
    test('24 past each side inset, 24 top and bottom', () {
      expect(
        dialogInsetPaddingFor(const EdgeInsets.only(right: 84, top: 20)),
        const EdgeInsets.fromLTRB(24, 24, 108, 24),
      );
      expect(
        dialogInsetPaddingFor(EdgeInsets.zero),
        const EdgeInsets.all(24),
      );
    });
  });
}
