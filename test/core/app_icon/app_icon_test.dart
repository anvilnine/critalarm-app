import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIcon', () {
    test('only the default icon is free', () {
      expect(AppIcon.standard.isPro, isFalse);
      expect(AppIcon.crowned.isPro, isTrue);
      expect(AppIcon.shades.isPro, isTrue);
      expect(AppIcon.shadesCrown.isPro, isTrue);
    });

    test('platform names match the native channels', () {
      // AppDelegate.alternateIcons and AppIconChannel.ALIASES use these.
      expect(AppIcon.values.map((icon) => icon.platformName), [
        'default',
        'pro_crowned',
        'pro_shades',
        'pro_shades_crown',
      ]);
    });

    test('fromPlatformName reads every name back', () {
      for (final icon in AppIcon.values) {
        expect(AppIcon.fromPlatformName(icon.platformName), icon);
      }
    });

    test('fromPlatformName returns null for a name it does not know', () {
      expect(AppIcon.fromPlatformName('pro_gold'), isNull);
      expect(AppIcon.fromPlatformName(null), isNull);
    });
  });

  group('AppIconRule.isLocked', () {
    test('Free sees every Pro icon locked and the default open', () {
      expect(AppIconRule.isLocked(AppIcon.standard, unlocked: false), isFalse);
      for (final icon in AppIcon.values.where((icon) => icon.isPro)) {
        expect(AppIconRule.isLocked(icon, unlocked: false), isTrue);
      }
    });

    test('Pro sees nothing locked', () {
      for (final icon in AppIcon.values) {
        expect(AppIconRule.isLocked(icon, unlocked: true), isFalse);
      }
    });
  });

  group('AppIconRule.revertTo', () {
    test('a Pro icon goes back to the default when Pro has ended', () {
      for (final icon in AppIcon.values.where((icon) => icon.isPro)) {
        expect(AppIconRule.revertTo(icon, unlocked: false), AppIcon.standard);
      }
    });

    test('each Pro icon stays while Pro does', () {
      for (final icon in AppIcon.values) {
        expect(AppIconRule.revertTo(icon, unlocked: true), isNull);
      }
    });

    test('the default icon never moves', () {
      expect(AppIconRule.revertTo(AppIcon.standard, unlocked: false), isNull);
      expect(AppIconRule.revertTo(AppIcon.standard, unlocked: true), isNull);
    });
  });
}
