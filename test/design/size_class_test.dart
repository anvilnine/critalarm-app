import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/components/stage.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSize size class', () {
    test('an iPhone 16 Pro upright is compact', () {
      expect(const AppSize(402, 874).sizeClass, AppSizeClass.compact);
    });

    test('a Galaxy Fold cover screen is compact and narrow', () {
      const size = AppSize(348, 891);
      expect(size.sizeClass, AppSizeClass.compact);
      expect(size.isNarrow, isTrue);
      expect(size.isShort, isFalse);
    });

    test('a Razr cover screen is compact and short', () {
      const size = AppSize(484, 411);
      expect(size.sizeClass, AppSizeClass.compact);
      expect(size.isShort, isTrue);
      expect(size.isNarrow, isFalse);
    });

    test('an iPad mini upright is medium', () {
      expect(const AppSize(744, 1133).sizeClass, AppSizeClass.medium);
    });

    test('an opened Fold upright is medium', () {
      expect(const AppSize(673, 841).sizeClass, AppSizeClass.medium);
    });

    test('an iPad mini on its side is expanded', () {
      expect(const AppSize(1133, 744).sizeClass, AppSizeClass.expanded);
    });

    test('an iPad Pro 11 on its side is expanded', () {
      expect(const AppSize(1210, 834).sizeClass, AppSizeClass.expanded);
    });

    test('the Pixel Fold inner screen is expanded at the 840 step', () {
      expect(const AppSize(841, 701).isExpanded, isTrue);
    });

    test('an iPad 11 upright stays medium, under the 840 step', () {
      expect(const AppSize(834, 1194).isMedium, isTrue);
    });

    test('the Galaxy Fold inner screen stays medium', () {
      expect(const AppSize(690, 829).isMedium, isTrue);
      expect(const AppSize(829, 690).isMedium, isTrue);
    });

    test('a big phone on its side is wide but too short for two panes', () {
      const size = AppSize(956, 440);
      expect(size.sizeClass, AppSizeClass.medium);
      expect(size.isShort, isTrue);
    });
  });

  group('AppSize tab bar placement', () {
    test('a phone upright keeps the bar along the bottom', () {
      const size = AppSize(402, 874, isIphone: true);
      expect(size.navPlacement, AppNavPlacement.bottom);
      expect(size.hasRail, isFalse);
    });

    test('a phone on its side stands the bar up on the left', () {
      const size = AppSize(874, 402, isIphone: true);
      expect(size.navPlacement, AppNavPlacement.left);
      expect(size.hasRail, isTrue);
    });

    test('an iPad mini upright keeps the bar along the bottom', () {
      expect(
        const AppSize(744, 1133).navPlacement,
        AppNavPlacement.bottom,
      );
    });

    test('an iPad on its side stands the bar up on the left', () {
      expect(const AppSize(1210, 834).navPlacement, AppNavPlacement.left);
    });

    test('an unfolded iPhone Fold puts the rail on the right', () {
      expect(
        const AppSize(720, 960, isIphone: true).navPlacement,
        AppNavPlacement.right,
      );
      expect(
        const AppSize(960, 720, isIphone: true).navPlacement,
        AppNavPlacement.right,
      );
    });

    test('an iPad the same size as an unfolded Fold stays on the left', () {
      expect(const AppSize(960, 720).navPlacement, AppNavPlacement.left);
    });

    test('an opened Android Fold upright keeps the bar along the bottom', () {
      expect(const AppSize(673, 841).navPlacement, AppNavPlacement.bottom);
    });
  });

  group('AppSize side gutter', () {
    test('a phone gets no gutter', () {
      expect(const AppSize(402, 874).sideGutter, 0);
    });

    test('a display exactly 560 wide gets no gutter', () {
      expect(const AppSize(560, 900).sideGutter, 0);
    });

    test('an iPad mini upright centres a 560 column', () {
      expect(const AppSize(744, 1133).sideGutter, 92);
    });
  });

  group('AppSize cover', () {
    test('the Razr cover is a cover screen', () {
      expect(const AppSize(384, 388).isCover, isTrue);
    });

    test('a phone on its side is short but not a cover screen', () {
      const size = AppSize(844, 390);
      expect(size.isShort, isTrue);
      expect(size.isCover, isFalse);
    });

    test('a phone upright is not a cover screen', () {
      expect(const AppSize(390, 844).isCover, isFalse);
    });
  });

  group('AppSize frame', () {
    test('a window up to 1600 wide has no canvas outside the frame', () {
      expect(const AppSize(1440, 900).frameInset, 0);
      expect(const AppSize(1600, 900).frameInset, 0);
    });

    test('a 1920 window centres the 1600 frame', () {
      expect(const AppSize(1920, 1080).frameInset, 160);
    });
  });

  group('AppScreenColumns', () {
    test('a 1920 window keeps the rail and both panes inside the frame', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 1920,
        size: const AppSize(1920, 1080),
        padding: EdgeInsets.zero,
        hasDetail: true,
      );
      expect(columns.twoPane, isTrue);
      // 160 of canvas, then the rail's room, then the list.
      expect(columns.listLeft, 160 + 88);
      expect(columns.detailLeft + columns.detailWidth, 1920 - 160);
    });

    test('the Pixel Fold inner screen gets list and detail', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 841,
        size: const AppSize(841, 701),
        padding: EdgeInsets.zero,
        hasDetail: true,
      );
      expect(columns.twoPane, isTrue);
      expect(columns.listWidth, 340);
    });

    test('one column on a 1920 window still centres at 560', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 1920,
        size: const AppSize(1920, 1080),
        padding: EdgeInsets.zero,
      );
      expect(columns.twoPane, isFalse);
      expect(columns.contentWidth, AppSize.contentMaxWidth);
      expect(columns.contentLeft, (1920 - 560) / 2);
    });

    test('a phone fills the box', () {
      final columns = AppScreenColumns.resolve(
        boxWidth: 390,
        size: const AppSize(390, 844),
        padding: EdgeInsets.zero,
        hasDetail: true,
      );
      expect(columns.twoPane, isFalse);
      expect(columns.contentLeft, 0);
      expect(columns.contentWidth, 390);
    });
  });

  group('AppScreenColumns rail on the right', () {
    test(
      'an iPhone Fold past the frame keeps the rail and the frame inset',
      () {
        // An unfolded iPhone Fold puts the rail on the right. 1800 wide is past
        // the frame, so 100 of canvas shows each side.
        final columns = AppScreenColumns.resolve(
          boxWidth: 1800,
          size: const AppSize(1800, 1000, isIphone: true),
          padding: EdgeInsets.zero,
          hasDetail: true,
        );
        expect(columns.railOnRight, isTrue);
        expect(columns.twoPane, isTrue);
        expect(columns.listLeft, 100);
        // The detail stops short of the rail's room and the canvas.
        expect(columns.detailLeft + columns.detailWidth, 1800 - 100 - 88);
        expect(columns.railClearance, 88 + 100);
      },
    );
  });

  group('AppFloatingTabBar gaps', () {
    test('a cover screen puts the bar 8 from the edge', () {
      const cover = AppSize(384, 388);
      expect(AppFloatingTabBar.edgeGapFor(cover), 8);
      expect(
        AppFloatingTabBar.contentGapFor(cover),
        AppFloatingTabBar.contentGap - AppFloatingTabBar.edgeGap + 8,
      );
      expect(
        AppFloatingTabBar.fadeHeightFor(cover),
        AppFloatingTabBar.height + 8,
      );
    });

    test('everything else keeps the usual gap', () {
      const phone = AppSize(390, 844);
      expect(AppFloatingTabBar.edgeGapFor(phone), AppFloatingTabBar.edgeGap);
      expect(
        AppFloatingTabBar.contentGapFor(phone),
        AppFloatingTabBar.contentGap,
      );
      expect(
        AppFloatingTabBar.fadeHeightFor(phone),
        AppFloatingTabBar.fadeHeight,
      );
    });
  });

  group('hero face size', () {
    test('a cover screen draws the face at 72 in either layout', () {
      for (final layout in AppHeroLayout.values) {
        expect(heroFaceSizeFor(layout, 360, isCover: true), 72);
      }
    });

    test('a column 360 or wider never draws it under 120', () {
      expect(
        heroFaceSizeFor(AppHeroLayout.stacked, 360),
        greaterThanOrEqualTo(120),
      );
      expect(
        heroFaceSizeFor(AppHeroLayout.sideBySide, 360),
        greaterThanOrEqualTo(120),
      );
    });

    test('a narrow column keeps the plain size', () {
      expect(heroFaceSizeFor(AppHeroLayout.stacked, 200), 200 * 0.44);
    });
  });

  group('stageFaceSizeFor', () {
    test('a cover screen gets 72', () {
      expect(
        stageFaceSizeFor(requested: 190, size: const AppSize(384, 388)),
        72,
      );
    });

    test('a short display caps the face at 96', () {
      expect(
        stageFaceSizeFor(requested: 110, size: const AppSize(844, 390)),
        96,
      );
    });

    test('a tablet lifts a small face to 120', () {
      expect(
        stageFaceSizeFor(requested: 110, size: const AppSize(744, 1133)),
        120,
      );
    });

    test('a phone keeps what it asked for', () {
      expect(
        stageFaceSizeFor(requested: 110, size: const AppSize(390, 844)),
        110,
      );
    });
  });
}
