import 'dart:ui';

import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame_geometry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fold implements DisplayFeature {
  const _Fold(this.bounds);

  @override
  final Rect bounds;

  @override
  DisplayFeatureState get state => DisplayFeatureState.postureHalfOpened;

  @override
  DisplayFeatureType get type => DisplayFeatureType.fold;
}

PaywallSplit? _splitAt(
  double width,
  double height, {
  Rect? fold,
  TextDirection direction = TextDirection.ltr,
}) {
  final window = Size(width, height);
  return paywallSplitFor(
    window: window,
    size: AppSize(width, height),
    fold: fold == null
        ? AppFold.none
        : AppFold.fromFeatures([_Fold(fold)], window),
    direction: direction,
  );
}

void main() {
  group('the one column', () {
    test('is the window on a phone', () {
      expect(paywallColumnWidthFor(390), 390);
      expect(paywallColumnWidthFor(384), 384);
      expect(paywallColumnHeightFor(width: 390, height: 932), 932);
    });

    test('is 520 wide from the medium size class up', () {
      expect(paywallColumnWidthFor(834), paywallColumnMaxWidth);
      expect(paywallColumnWidthFor(600), paywallColumnMaxWidth);
      expect(paywallColumnMaxWidth, 520);
    });

    test('its words and its buy block share one width', () {
      // The words keep 20 at each side of the column, and the buy block
      // caps the plans and the button at 480 inside the same 20.
      expect(
        paywallBuyBlockMaxWidthFor(width: 834, padding: paywallColumnPadding),
        paywallColumnMaxWidth,
      );
      expect(paywallColumnMaxWidth - 2 * paywallColumnPadding, 480);
    });

    test('stops at 900 tall on a tablet held upright', () {
      expect(paywallColumnHeightFor(width: 834, height: 1170), 900);
      // A phone on its side is medium and keeps its short height.
      expect(paywallColumnHeightFor(width: 844, height: 390), 390);
    });
  });

  group('the split', () {
    test('none on a phone or a tablet held upright', () {
      expect(_splitAt(390, 844), isNull);
      expect(_splitAt(834, 1194), isNull);
      expect(_splitAt(384, 388), isNull);
    });

    test(
      'wide: stage at the start, a 420 offer at the end of a 1040 frame',
      () {
        final split = _splitAt(1440, 900)!;
        expect(split.kind, PaywallSplitKind.wide);
        expect(split.offer, const Rect.fromLTWH(820, 0, 420, 900));
        expect(split.stage, const Rect.fromLTWH(200, 0, 572, 900));
        expect(split.offer.left - split.stage.right, paywallWideGap);
      },
    );

    test('wide: a window narrower than the frame keeps a margin', () {
      final split = _splitAt(841, 701)!;
      expect(split.kind, PaywallSplitKind.wide);
      expect(split.stage.left, paywallWideMargin);
      expect(split.offer.right, 841 - paywallWideMargin);
      expect(split.offer.width, paywallOfferWidth);
    });

    test('wide: the stage moves to the right in a right to left language', () {
      final split = _splitAt(1440, 900, direction: TextDirection.rtl)!;
      expect(split.offer.left, 200);
      expect(split.stage.right, 1240);
    });

    test('book: stage in the start pane, offer in the end pane', () {
      final split = _splitAt(
        690,
        829,
        fold: const Rect.fromLTRB(345, 0, 345, 829),
      )!;
      expect(split.kind, PaywallSplitKind.book);
      expect(split.stage, const Rect.fromLTRB(0, 0, 329, 829));
      expect(split.offer, const Rect.fromLTRB(361, 0, 690, 829));
    });

    test('tabletop wins over the wide window: stage on top, offer below', () {
      final split = _splitAt(
        841,
        701,
        fold: const Rect.fromLTRB(0, 350, 841, 350),
      )!;
      expect(split.kind, PaywallSplitKind.tabletop);
      expect(split.stage, const Rect.fromLTRB(0, 0, 841, 334));
      // Centred in the bottom half, never wider than the offer column.
      expect(split.offer, const Rect.fromLTRB(210.5, 366, 630.5, 701));
    });

    test('a pane narrower than a phone stacks the plans', () {
      final book = _splitAt(
        690,
        829,
        fold: const Rect.fromLTRB(345, 0, 345, 829),
      )!;
      expect(paywallSplitStacksPlans(book), isTrue);
      expect(paywallSplitStacksPlans(_splitAt(1440, 900)!), isFalse);
    });
  });

  group('the split stage', () {
    test('a phone sized pane is drawn as it is', () {
      expect(paywallStageScaleFor(const Size(329, 829)), 1);
      expect(paywallStageScaleFor(const Size(841, 334)), 1);
    });

    test('a wide column draws the stage up, to a limit', () {
      expect(
        paywallStageScaleFor(const Size(572, 900)),
        closeTo(572 / paywallStageBaseEdge, 1e-9),
      );
      expect(paywallStageScaleFor(const Size(2000, 2000)), 1.4);
    });
  });

  group('the pips row', () {
    test('a stage with no room still leaves the pips their row', () {
      final room = heroStageRoomFor(
        height: 200,
        words: 300,
        gap: 8,
        bottomGap: 12,
        minGap: heroPipsRow,
      );
      expect(room.stage, 0);
      expect(room.gap, heroPipsRow);
    });

    test('a tall screen, whose gap is larger, comes out the same', () {
      HeroStageRoom at(double minGap) => heroStageRoomFor(
        height: 844,
        words: 220,
        gap: 12,
        bottomGap: 20,
        minGap: minGap,
      );
      expect(at(heroPipsRow).stage, at(0).stage);
      expect(at(heroPipsRow).gap, at(0).gap);
    });
  });

  group('a layout that does not split', () {
    PaywallSplit? frameSplit(double w, double h, {Rect? line}) {
      final window = Size(w, h);
      return paywallFrameSplitFor(
        window: window,
        size: AppSize(w, h),
        fold: line == null
            ? AppFold.none
            : AppFold.fromFeatures([_Fold(line)], window),
        splits: false,
      );
    }

    test('keeps the one column on a phone, a tablet and a wide window', () {
      expect(frameSplit(390, 844), isNull);
      expect(frameSplit(834, 1194), isNull);
      expect(frameSplit(1440, 900), isNull);
    });

    test('splits on a half-open foldable, as the fold rule wins', () {
      final book = frameSplit(
        690,
        829,
        line: const Rect.fromLTRB(345, 0, 345, 829),
      )!;
      expect(book.kind, PaywallSplitKind.book);
      expect(book.stage, const Rect.fromLTRB(0, 0, 329, 829));
      expect(book.offer, const Rect.fromLTRB(361, 0, 690, 829));
      final tabletop = frameSplit(
        841,
        701,
        line: const Rect.fromLTRB(0, 350, 841, 350),
      )!;
      expect(tabletop.kind, PaywallSplitKind.tabletop);
      expect(tabletop.stage.bottom, 334);
      expect(tabletop.offer.top, 366);
    });

    test('a layout that splits splits on a wide window too', () {
      const window = Size(1440, 900);
      expect(
        paywallFrameSplitFor(
          window: window,
          size: const AppSize(1440, 900),
          fold: AppFold.none,
          splits: true,
        )!.kind,
        PaywallSplitKind.wide,
      );
    });
  });

  group('the buy block of the one column', () {
    test('runs the width of a phone', () {
      expect(paywallBuyBlockMaxWidthFor(width: 390, padding: 20), isNull);
      expect(paywallBuyBlockMaxWidthFor(width: 329, padding: 20), isNull);
    });

    test('stops its plans and Get Cloud at 480 from medium up', () {
      expect(paywallBuyBlockMaxWidthFor(width: 834, padding: 20), 520);
      expect(
        paywallBuyBlockMaxWidthFor(width: 1440, padding: 20)! - 40,
        AppSize.actionMaxWidth,
      );
    });

    test('a style copied with stacked plans keeps every other field', () {
      const style = PaywallBuyBlockStyle(
        tone: PaywallTone.surface,
        showsPicker: false,
        horizontalPadding: 24,
        buttonLabel: 'b',
        note: 'n',
        showsNote: false,
      );
      final rows = style.copyWith(pickerStyle: PaywallPlanPickerStyle.rows);
      expect(rows.pickerStyle, PaywallPlanPickerStyle.rows);
      expect(rows.tone, PaywallTone.surface);
      expect(rows.showsPicker, isFalse);
      expect(rows.horizontalPadding, 24);
      expect(rows.buttonLabel, 'b');
      expect(rows.note, 'n');
      expect(rows.showsNote, isFalse);
    });
  });
}
