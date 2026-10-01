import 'dart:math' as math;

import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/components/tilt_showcase.dart';
import 'package:critalarm/features/settings/presentation/app_icon_showcase_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pageLook', () {
    test('the centred page is full size and opaque', () {
      final look = pageLook(0);
      expect(look.scale, 1);
      expect(look.opacity, 1);
    });

    test('a neighbour is 0.78 and half faded, either side', () {
      for (final d in [1.0, -1.0]) {
        final look = pageLook(d);
        expect(look.scale, closeTo(0.78, 1e-9));
        expect(look.opacity, closeTo(0.5, 1e-9));
      }
    });

    test('halfway between pages is halfway between looks', () {
      final look = pageLook(0.5);
      expect(look.scale, closeTo(0.89, 1e-9));
      expect(look.opacity, closeTo(0.75, 1e-9));
    });

    test('far pages stay at the neighbour look', () {
      expect(pageLook(3).scale, closeTo(0.78, 1e-9));
      expect(pageLook(-3).opacity, closeTo(0.5, 1e-9));
    });
  });

  group('tiltPoseAt', () {
    test('stays inside -1..1 on both axes for any phase', () {
      for (var p = 0.0; p < 8; p += 1.3) {
        for (var t = 0.0; t <= 1; t += 0.01) {
          final pose = tiltPoseAt(t, phase: p);
          expect(pose.x.abs(), lessThanOrEqualTo(1));
          expect(pose.y.abs(), lessThanOrEqualTo(1));
        }
      }
    });

    test('t = 0 and t = 1 are the same pose, so the loop has no seam', () {
      final a = tiltPoseAt(0, phase: 2);
      final b = tiltPoseAt(1, phase: 2);
      expect(a.x, closeTo(b.x, 1e-9));
      expect(a.y, closeTo(b.y, 1e-9));
    });

    test('phase moves the pose', () {
      expect(
        tiltPoseAt(0.2).x,
        isNot(closeTo(tiltPoseAt(0.2, phase: 1.3).x, 1e-3)),
      );
    });

    test('the angle at the default max never passes 12 degrees', () {
      const max = 11 * math.pi / 180;
      final pose = tiltPoseAt(0.25);
      expect((pose.x * max).abs(), lessThanOrEqualTo(12 * math.pi / 180));
    });
  });

  group('iconAction', () {
    test('free: standard in use, Pro icons ask to unlock', () {
      expect(
        iconAction(
          AppIcon.standard,
          unlocked: false,
          current: AppIcon.standard,
        ),
        IconAction.inUse,
      );
      for (final icon in [
        AppIcon.crowned,
        AppIcon.shades,
        AppIcon.shadesCrown,
      ]) {
        expect(
          iconAction(icon, unlocked: false, current: AppIcon.standard),
          IconAction.unlock,
        );
      }
    });

    test('Pro: any other icon can be used, the current one cannot', () {
      expect(
        iconAction(AppIcon.shades, unlocked: true, current: AppIcon.standard),
        IconAction.use,
      );
      expect(
        iconAction(AppIcon.shades, unlocked: true, current: AppIcon.shades),
        IconAction.inUse,
      );
      expect(
        iconAction(AppIcon.standard, unlocked: true, current: AppIcon.shades),
        IconAction.use,
      );
    });

    test('a Pro icon still in use after Pro ends asks to unlock', () {
      expect(
        iconAction(AppIcon.crowned, unlocked: false, current: AppIcon.crowned),
        IconAction.unlock,
      );
    });
  });

  test('showcaseTileSize grows with the phone, caps at 240, floors at 120', () {
    expect(showcaseTileSize(390), closeTo(226.2, 0.001));
    expect(showcaseTileSize(500), 240);
    expect(showcaseTileSize(280), closeTo(162.4, 0.001));
    expect(showcaseTileSize(100), 120);
  });
}
