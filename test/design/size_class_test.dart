import 'package:critalarm/design/size_class.dart';
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

    test('a big phone on its side is wide but too short for two panes', () {
      const size = AppSize(956, 440);
      expect(size.sizeClass, AppSizeClass.medium);
      expect(size.isShort, isTrue);
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
}
