import 'package:critalarm/features/settings/presentation/app_icon_fit.dart';
import 'package:critalarm/features/settings/presentation/app_icon_showcase_logic.dart';
import 'package:flutter_test/flutter_test.dart';

IconPageFit _tall({
  double width = 390,
  double height = 560,
  double nameHeight = 29,
  double headlineHeight = 0,
  double badgeHeight = 22,
}) => fitIconPage(
  width: width,
  height: height,
  nameHeight: nameHeight,
  headlineHeight: headlineHeight,
  badgeHeight: badgeHeight,
  sideBySide: false,
);

void main() {
  group('fitIconPage, one column', () {
    test('keeps the width size when the height is roomy', () {
      final fit = _tall();
      expect(fit.tile, showcaseTileSize(390));
      expect(fit.room, kIconRoomRoomy);
      expect(fit.sideBySide, isFalse);
    });

    test('shrinks the icon before the name and the badge fall off', () {
      final fit = _tall(width: 320, height: 330, nameHeight: 116);
      expect(fit.tile, lessThan(showcaseTileSize(320)));
      final used =
          fit.carouselHeight +
          kIconDotsGap +
          kIconDotsHeight +
          kIconNameGap +
          116 +
          kIconBadgeGap +
          iconBadgeHeight(1);
      expect(used, lessThanOrEqualTo(330 + 1));
    });

    test('takes the tight air once the roomy one would make a small icon', () {
      final roomy = _tall(height: 420);
      final tight = _tall(height: 300);
      expect(roomy.room, kIconRoomRoomy);
      expect(tight.room, kIconRoomTight);
    });

    test('never goes below the smallest tile', () {
      final fit = _tall(height: 100, nameHeight: 116);
      expect(fit.tile, kIconMinTile);
    });

    test('a slot for the badge costs height only when asked for', () {
      final withBadge = _tall(height: 400);
      final without = _tall(height: 400, badgeHeight: 0);
      expect(without.tile, greaterThanOrEqualTo(withBadge.tile));
    });

    test('the welcome headline takes height too', () {
      final plain = _tall(height: 330, width: 320);
      final headed = _tall(height: 330, width: 320, headlineHeight: 60);
      expect(headed.tile, lessThanOrEqualTo(plain.tile));
    });
  });

  group('fitIconPage, side by side', () {
    test('fits the free height and leaves air for the tilt', () {
      final fit = fitIconPage(
        width: 560,
        height: 190,
        nameHeight: 29,
        headlineHeight: 0,
        badgeHeight: 22,
        sideBySide: true,
      );
      expect(fit.sideBySide, isTrue);
      expect(fit.tile, 190 - kIconRoomTight);
    });

    test('stays clear of its neighbour on a tall free height', () {
      final fit = fitIconPage(
        width: 560,
        height: 400,
        nameHeight: 29,
        headlineHeight: 0,
        badgeHeight: 22,
        sideBySide: true,
      );
      expect(fit.tile, lessThanOrEqualTo(560 * 0.36));
    });
  });

  test('the badge grows with the text size', () {
    expect(iconBadgeHeight(2), greaterThan(iconBadgeHeight(1)));
  });
}
