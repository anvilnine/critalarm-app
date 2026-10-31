import 'dart:ui';

import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DisplayFeature _fold(
  Rect bounds, {
  DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
  DisplayFeatureType type = DisplayFeatureType.fold,
}) => DisplayFeature(bounds: bounds, type: type, state: state);

void main() {
  // The Galaxy Fold inner screen, 690 x 829, and the Pixel Fold inner
  // screen, 841 x 701, with the folds the capture matrix uses.
  const book = Size(690, 829);
  const tabletop = Size(841, 701);
  final bookLine = Rect.fromLTWH(345, 0, 0, book.height);
  final tabletopLine = Rect.fromLTWH(0, 350, tabletop.width, 0);

  group('AppFold.fromFeatures', () {
    test('a half-opened fold that runs top to bottom is book', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      expect(fold.posture, AppPosture.book);
      expect(fold.bounds, bookLine);
    });

    test('a half-opened fold that runs left to right is tabletop', () {
      final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      expect(fold.posture, AppPosture.tabletop);
    });

    test('a fold opened flat is no fold', () {
      final fold = AppFold.fromFeatures([
        _fold(bookLine, state: DisplayFeatureState.postureFlat),
      ], book);
      expect(fold.isNone, isTrue);
      expect(fold, AppFold.none);
    });

    test('no features is no fold', () {
      expect(AppFold.fromFeatures(const [], book).isNone, isTrue);
    });

    test('a hinge with a width counts even when flat', () {
      final fold = AppFold.fromFeatures([
        _fold(
          Rect.fromLTWH(340, 0, 10, book.height),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ], book);
      expect(fold.isBook, isTrue);
    });

    test('a camera cutout is ignored', () {
      final fold = AppFold.fromFeatures([
        _fold(
          const Rect.fromLTWH(160, 0, 40, 30),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ], book);
      expect(fold.isNone, isTrue);
    });
  });

  group('AppFold band and panes', () {
    test('the book band is 16 either side of the fold', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      expect(fold.band, Rect.fromLTRB(329, 0, 361, book.height));
    });

    test('the tabletop band is 16 above and below the fold', () {
      final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      expect(fold.band, Rect.fromLTRB(0, 334, tabletop.width, 366));
    });

    test('book panes sit either side of the band, start first', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      final ltr = fold.panes(book);
      expect(ltr.first, Rect.fromLTRB(0, 0, 329, book.height));
      expect(ltr.second, Rect.fromLTRB(361, 0, 690, book.height));
      final rtl = fold.panes(book, direction: TextDirection.rtl);
      expect(rtl.first, ltr.second);
    });

    test('tabletop panes are the halves above and below the band', () {
      final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      final panes = fold.panes(tabletop);
      expect(panes.first, Rect.fromLTRB(0, 0, tabletop.width, 334));
      expect(panes.second, Rect.fromLTRB(0, 366, tabletop.width, 701));
    });

    test('a book pane is a compact phone and the tabletop half is short', () {
      final bookFold = AppFold.fromFeatures([_fold(bookLine)], book);
      final pane = bookFold.panes(book).first;
      expect(AppSize.from(pane.size).isCompact, isTrue);
      final topFold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      final half = topFold.panes(tabletop).second;
      expect(AppSize.from(half.size).isExpanded, isFalse);
    });
  });

  group('foldOverlaps', () {
    final band = AppFold.fromFeatures([_fold(bookLine)], book).band;

    test('a button across the band fails', () {
      const button = Rect.fromLTWH(300, 700, 120, 48);
      expect(foldOverlaps([button], band), isTrue);
    });

    test('boxes clear of the band pass', () {
      const boxes = [
        Rect.fromLTWH(16, 100, 300, 20),
        Rect.fromLTWH(377, 100, 280, 20),
        // Touching the band's edge is still clear.
        Rect.fromLTWH(229, 300, 100, 48),
      ];
      expect(foldOverlaps(boxes, band), isFalse);
    });

    test('an empty box never overlaps', () {
      expect(boxCrossesFold(const Rect.fromLTWH(340, 10, 0, 20), band), false);
    });

    test('nothing overlaps when there is no fold', () {
      expect(
        foldOverlaps([const Rect.fromLTWH(0, 0, 690, 829)], AppFold.none.band),
        isFalse,
      );
    });
  });

  group('foldPaneMediaQuery', () {
    const window = MediaQueryData(
      size: tabletop,
      padding: EdgeInsets.fromLTRB(0, 24, 0, 20),
      viewInsets: EdgeInsets.only(bottom: 300),
    );

    test('the top half keeps the status bar and loses the bottom inset', () {
      final media = foldPaneMediaQuery(
        window,
        const Rect.fromLTRB(0, 0, 841, 334),
      );
      expect(media.size, const Size(841, 334));
      expect(media.padding, const EdgeInsets.only(top: 24));
      // A 300 keyboard covers the 335 bottom half and stops short of here.
      expect(media.viewInsets, EdgeInsets.zero);
      expect(media.displayFeatures, isEmpty);
    });

    test('the bottom half keeps the home bar and the keyboard', () {
      final media = foldPaneMediaQuery(
        window,
        const Rect.fromLTRB(0, 366, 841, 701),
      );
      expect(media.padding, const EdgeInsets.only(bottom: 20));
      expect(media.viewInsets, const EdgeInsets.only(bottom: 300));
    });
  });

  group('AppScreenScaffold.showsDetailFor', () {
    test('book posture shows the detail at any width', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      expect(AppScreenScaffold.showsDetailFor(AppSize.from(book), fold), true);
    });

    test('tabletop shows none, even on an expanded window', () {
      final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      final size = AppSize.from(tabletop);
      expect(size.isExpanded, isTrue);
      expect(AppScreenScaffold.showsDetailFor(size, fold), isFalse);
    });

    test('an expanded window with no fold shows it, a phone does not', () {
      expect(
        AppScreenScaffold.showsDetailFor(
          const AppSize(1440, 900),
          AppFold.none,
        ),
        isTrue,
      );
      expect(
        AppScreenScaffold.showsDetailFor(const AppSize(390, 844), AppFold.none),
        isFalse,
      );
    });
  });

  group('book posture beats the size class', () {
    // A Pixel Fold inner screen half opened as a book: expanded and wider
    // than tall, so without the fold it would get a rail.
    const window = Size(841, 701);
    final fold = AppFold.fromFeatures([
      _fold(Rect.fromLTWH(420, 0, 0, window.height)),
    ], window);
    final size = AppSize.from(window);

    test('the bar is the bottom pill, never a rail', () {
      expect(size.navPlacement, AppNavPlacement.left);
      expect(navPlacementFor(size, fold), AppNavPlacement.bottom);
      expect(navPlacementFor(size, AppFold.none), AppNavPlacement.left);
    });

    test('a side strip that holds the rail keeps the rail, half open', () {
      // The iPhone Duo's inner display: the strip down the right holds the
      // rail clear of the fold, so it stays a rail in book posture.
      const duo = Size(951, 669);
      final duoFold = AppFold.fromFeatures([
        _fold(Rect.fromLTWH(475.5, 0, 0, duo.height)),
      ], duo);
      final duoSize = AppSize.from(duo, isIphone: true);
      const strip = EdgeInsets.only(right: 84);
      expect(
        navPlacementFor(duoSize, duoFold, padding: strip),
        AppNavPlacement.right,
      );
      expect(navPlacementFor(duoSize, duoFold), AppNavPlacement.bottom);
    });

    test('the bar floats in the start pane, left of the band', () {
      final area = navAreaFor(window, fold);
      expect(area, const Rect.fromLTRB(0, 0, 404, 701));
    });

    test('one column keeps no room for a rail that is not drawn', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: window.width,
        size: size,
        padding: EdgeInsets.zero,
        fold: fold,
      );
      expect(columns.railClearance, 0);
      expect(columns.gutter, (841 - 560) / 2);
    });

    test('a detail never sits beside the list in one folded box', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: window.width,
        size: size,
        padding: EdgeInsets.zero,
        fold: fold,
        hasDetail: true,
      );
      expect(columns.twoPane, isFalse);
    });
  });

  group('AppScreenColumns.forWindow', () {
    test('book with a detail: the list is the start pane', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      final columns = AppScreenColumns.forWindow(
        window: book,
        padding: EdgeInsets.zero,
        fold: fold,
        hasDetail: true,
      );
      expect(columns.inFoldPane, isTrue);
      expect(columns.originX, 0);
      expect(columns.listWidth, 329);
      expect(columns.contentWidth, 329);
    });

    test(
      'book with a detail, right to left: the start pane is on the right',
      () {
        final fold = AppFold.fromFeatures([_fold(bookLine)], book);
        final columns = AppScreenColumns.forWindow(
          window: book,
          padding: EdgeInsets.zero,
          fold: fold,
          direction: TextDirection.rtl,
          hasDetail: true,
        );
        expect(columns.originX, 361);
        expect(columns.contentLeft, 361);
      },
    );

    test('book with a stage: the list is the end pane, with no bar', () {
      final fold = AppFold.fromFeatures([_fold(bookLine)], book);
      final columns = AppScreenColumns.forWindow(
        window: book,
        padding: EdgeInsets.zero,
        fold: fold,
        hasStage: true,
      );
      expect(columns.originX, 361);
      expect(columns.listWidth, 329);
      expect(columns.railClearance, 0);
    });

    test(
      'tabletop with a stage: the list is the bottom half, with the rail',
      () {
        final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
        final columns = AppScreenColumns.forWindow(
          window: tabletop,
          padding: EdgeInsets.zero,
          fold: fold,
          hasStage: true,
        );
        expect(columns.originY, 366);
        expect(columns.railClearance, 88);
      },
    );

    test('tabletop with only a detail: one column on the window', () {
      final fold = AppFold.fromFeatures([_fold(tabletopLine)], tabletop);
      final columns = AppScreenColumns.forWindow(
        window: tabletop,
        padding: EdgeInsets.zero,
        fold: fold,
        hasDetail: true,
      );
      expect(columns.twoPane, isFalse);
      expect(columns.inFoldPane, isFalse);
    });
  });

  group('AppScreenColumns.detailEndInset', () {
    AppScreenColumns columnsAt(Size window) => AppScreenColumns.resolve(
      boxWidth: window.width,
      size: AppSize.from(window),
      padding: EdgeInsets.zero,
      hasDetail: true,
    );

    test('past the 1600 frame the pane stops short of the window edge', () {
      final columns = columnsAt(const Size(1920, 1080));
      expect(columns.twoPane, isTrue);
      expect(columns.detailEndInset(1920), (1920 - AppSize.frameMaxWidth) / 2);
    });

    test('inside the frame the pane runs to the window edge', () {
      final columns = columnsAt(const Size(1440, 900));
      expect(columns.twoPane, isTrue);
      expect(columns.detailEndInset(1440), 0);
    });
  });
}
