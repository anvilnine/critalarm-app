import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heroLayoutFor', () {
    test('side by side from 340 points up', () {
      expect(
        heroLayoutFor(width: 340, textScale: 1),
        AppHeroLayout.sideBySide,
      );
      expect(
        heroLayoutFor(width: 390, textScale: 1),
        AppHeroLayout.sideBySide,
      );
    });

    test('stacked below 340 points', () {
      expect(
        heroLayoutFor(width: 339.9, textScale: 1),
        AppHeroLayout.stacked,
      );
      expect(heroLayoutFor(width: 320, textScale: 1), AppHeroLayout.stacked);
    });

    test('stacked above text scale 1.3, side by side at 1.3', () {
      expect(
        heroLayoutFor(width: 390, textScale: 1.3),
        AppHeroLayout.sideBySide,
      );
      expect(
        heroLayoutFor(width: 390, textScale: 1.31),
        AppHeroLayout.stacked,
      );
      expect(heroLayoutFor(width: 390, textScale: 2), AppHeroLayout.stacked);
    });

    test('stacked in a pane, however wide', () {
      expect(
        heroLayoutFor(width: 460, textScale: 1, isPane: true),
        AppHeroLayout.stacked,
      );
    });
  });

  group('heroFaceSizeFor', () {
    test('side by side is 170 on a phone and 150 at 340', () {
      expect(heroFaceSizeFor(AppHeroLayout.sideBySide, 390), 170);
      expect(heroFaceSizeFor(AppHeroLayout.sideBySide, 340), 149.6);
      expect(
        heroFaceSizeFor(AppHeroLayout.sideBySide, 600),
        kHeroMaxFaceSize,
      );
    });

    test('stacked is 120', () {
      expect(heroFaceSizeFor(AppHeroLayout.stacked, 390), 120);
      expect(heroFaceSizeFor(AppHeroLayout.stacked, 320), 120);
    });
  });

  group('heroGazeOffset', () {
    test('none looks straight out', () {
      expect(
        heroGazeOffset(AppHeroGaze.none, AppHeroLayout.sideBySide),
        Offset.zero,
      );
    });

    test('the card is to the right beside the face and below it stacked', () {
      final side = heroGazeOffset(AppHeroGaze.card, AppHeroLayout.sideBySide);
      final stacked = heroGazeOffset(AppHeroGaze.card, AppHeroLayout.stacked);
      expect(side.dx, greaterThan(0));
      expect(stacked.dx, 0);
      expect(stacked.dy, greaterThan(side.dy));
    });

    test('the list is down', () {
      expect(
        heroGazeOffset(AppHeroGaze.list, AppHeroLayout.sideBySide).dy,
        greaterThan(5),
      );
    });
  });

  group('heroFaceBlinks', () {
    test('open eyed faces blink, shut and live faces keep their pose', () {
      expect(heroFaceBlinks(FaceState.calm), isTrue);
      expect(heroFaceBlinks(FaceState.skeptical), isTrue);
      expect(heroFaceBlinks(FaceState.sad), isTrue);
      expect(heroFaceBlinks(FaceState.acked), isFalse);
      expect(heroFaceBlinks(FaceState.happy), isFalse);
      expect(heroFaceBlinks(FaceState.dozing), isFalse);
      expect(heroFaceBlinks(FaceState.alarmed), isFalse);
    });
  });

  group('heroLookedShape', () {
    test('moves both pupils and nothing else', () {
      final calm = faceFor(FaceState.calm);
      final looked = heroLookedShape(calm, const Offset(7, 3));
      expect(looked.leftEye.pupilOffset, const Offset(7, 3));
      expect(looked.rightEye.pupilOffset, const Offset(7, 3));
      expect(looked.leftEye.centre, calm.leftEye.centre);
      expect(looked.mouth, calm.mouth);
    });
  });

  group('AppHeroTone.discColor', () {
    test('calm follows the canvas step', () {
      const colors = AppColors.light;
      expect(AppHeroTone.calm.discColor(colors), colors.canvasAlt);
      final retinted = colors.withSeverity(SeverityMode.crit);
      expect(AppHeroTone.calm.discColor(retinted), retinted.critCanvasAlt);
    });

    test('every tone has its own colour in both themes', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final all = AppHeroTone.values.map((t) => t.discColor(colors)).toSet();
        expect(all.length, AppHeroTone.values.length);
      }
    });
  });
}
