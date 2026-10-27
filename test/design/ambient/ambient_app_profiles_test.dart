import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientAppProfiles', () {
    test(
      'all profiles have exactly 3 valid shapes in light and dark themes',
      () {
        for (final colors in const [AppColors.light, AppColors.dark]) {
          final profiles = [
            AmbientAppProfiles.criticalAlarmRinging(colors),
            AmbientAppProfiles.criticalAlarmAcknowledged(colors),
            AmbientAppProfiles.createTopic(colors),
            AmbientAppProfiles.topics(colors),
            AmbientAppProfiles.topicsHero(colors),
            AmbientAppProfiles.history(colors),
            AmbientAppProfiles.settings(colors),
            AmbientAppProfiles.topicDetail(colors),
            AmbientAppProfiles.historyDetail(colors),
            AmbientAppProfiles.settingsDetail(colors),
            AmbientAppProfiles.soundList(colors),
            AmbientAppProfiles.soundEditor(colors),
          ];

          for (final profile in profiles) {
            expect(profile.shapes.length, 3);
            expect(profile.surfaceOpacity, inInclusiveRange(0.0, 1.0));

            for (final shape in profile.shapes) {
              expect(shape.opacity, inInclusiveRange(0.0, 1.0));
              expect(shape.scale, inInclusiveRange(0.0, AmbientShape.maxScale));
              expect(shape.depth, inInclusiveRange(0.0, 1.0));
              expect(shape.anchor.x, inInclusiveRange(-1.0, 1.0));
              expect(shape.anchor.y, inInclusiveRange(-1.0, 1.0));
            }
          }
        }
      },
    );

    test('forTabIndex returns matching root profiles', () {
      const colors = AppColors.light;
      expect(
        AmbientAppProfiles.forTabIndex(0, colors),
        AmbientAppProfiles.topicsHero(colors),
      );
      expect(
        AmbientAppProfiles.forTabIndex(1, colors),
        AmbientAppProfiles.history(colors),
      );
      expect(
        AmbientAppProfiles.forTabIndex(2, colors),
        AmbientAppProfiles.settings(colors),
      );
    });

    test('all home tabs use the base yellow canvas color', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        expect(AmbientAppProfiles.topics(colors).canvas, colors.canvas);
        expect(AmbientAppProfiles.topicsHero(colors).canvas, colors.canvas);
        expect(AmbientAppProfiles.history(colors).canvas, colors.canvas);
        expect(AmbientAppProfiles.settings(colors).canvas, colors.canvas);
      }
    });

    test('calm profiles use only orange and pale tints, no cobalt or red', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final calm = [
          AmbientAppProfiles.createTopic(colors),
          AmbientAppProfiles.topics(colors),
          AmbientAppProfiles.history(colors),
          AmbientAppProfiles.settings(colors),
          AmbientAppProfiles.settingsDetail(colors),
        ];
        for (final profile in calm) {
          for (final shape in profile.shapes) {
            expect(
              shape.color,
              anyOf(const Color(0xFFFFB21F), const Color(0xFFFFE08A)),
            );
          }
        }
      }
    });

    test('calm shapes are half as strong on the dark canvas', () {
      final light = AmbientAppProfiles.topics(AppColors.light).shapes;
      final dark = AmbientAppProfiles.topics(AppColors.dark).shapes;
      for (var i = 0; i < light.length; i++) {
        expect(dark[i].opacity, closeTo(light[i].opacity / 2, 1e-9));
      }
    });

    test('all app profiles can lerp smoothly to any other profile', () {
      const colors = AppColors.dark;
      final profiles = [
        AmbientAppProfiles.criticalAlarmRinging(colors),
        AmbientAppProfiles.criticalAlarmAcknowledged(colors),
        AmbientAppProfiles.createTopic(colors),
        AmbientAppProfiles.topics(colors),
        AmbientAppProfiles.topicsHero(colors),
        AmbientAppProfiles.topicsHero(
          colors,
          severity: SeverityMode.crit,
        ),
        AmbientAppProfiles.topicDetail(colors),
        AmbientAppProfiles.history(colors),
        AmbientAppProfiles.settings(colors),
      ];

      for (var i = 0; i < profiles.length; i++) {
        for (var j = 0; j < profiles.length; j++) {
          final a = profiles[i];
          final b = profiles[j];
          final mid = AmbientProfile.lerp(a, b, 0.5);
          expect(mid.shapes.length, 3);
          expect(mid.surfaceOpacity, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('AmbientAppProfiles.topicsHero', () {
    const light = AppColors.light;

    test('is a disc, a hidden pill and a ring', () {
      final shapes = AmbientAppProfiles.topicsHero(light).shapes;
      expect(shapes.length, 3);
      expect(shapes[0].ring, 0);
      expect(shapes[0].opacity, 1);
      expect(shapes[1].opacity, 0);
      expect(shapes[2].ring, 1);
      expect(shapes[2].anchor, shapes[0].anchor);
    });

    test('the disc is wider than the screen and the ring wider still', () {
      final shapes = AmbientAppProfiles.topicsHero(light).shapes;
      expect(shapes[0].scale, greaterThan(1));
      expect(shapes[2].scale, greaterThan(shapes[0].scale));
      expect(shapes[2].scale, lessThanOrEqualTo(AmbientShape.maxScale));
    });

    test('every hero tone tints the disc as the scene does', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        for (final tone in AppHeroTone.values) {
          final disc = AmbientAppProfiles.topicsHero(
            colors,
            tone: tone,
          ).shapes.first;
          expect(
            disc.color.withValues(alpha: disc.opacity),
            tone.discColor(colors),
            reason: '$tone',
          );
        }
      }
    });

    test('the tones are four different profiles', () {
      final all = {
        for (final tone in AppHeroTone.values)
          AmbientAppProfiles.topicsHero(light, tone: tone),
      };
      expect(all.length, AppHeroTone.values.length);
    });

    test('a severity retints the canvas and the disc with it', () {
      final cases = {
        SeverityMode.high: (light.highCanvas, light.highCanvasAlt),
        SeverityMode.crit: (light.critCanvas, light.critCanvasAlt),
        SeverityMode.ack: (light.ackCanvas, light.ackCanvasAlt),
      };
      for (final MapEntry(key: mode, value: (canvas, alt)) in cases.entries) {
        final profile = AmbientAppProfiles.topicsHero(light, severity: mode);
        expect(profile.canvas, canvas, reason: '$mode');
        expect(profile.shapes.first.color, alt, reason: '$mode');
      }
    });

    test('the ring is orange on yellow and ink under a severity canvas', () {
      final plain = AmbientAppProfiles.topicsHero(light).shapes[2];
      expect(plain.color, const Color(0xFFFFB21F));
      final ack = AmbientAppProfiles.topicsHero(
        light,
        severity: SeverityMode.ack,
      ).shapes[2];
      expect(ack.color, light.withSeverity(SeverityMode.ack).onCanvas);
    });

    test('the spot moves the disc and the ring together', () {
      const spot = HeroDiscSpot(
        anchor: Alignment(0.1, -0.3),
        discScale: 0.9,
        ringScale: 1.1,
      );
      final shapes = AmbientAppProfiles.topicsHero(light, spot: spot).shapes;
      expect(shapes[0].anchor, spot.anchor);
      expect(shapes[2].anchor, spot.anchor);
      expect(shapes[0].scale, spot.discScale);
      expect(shapes[2].scale, spot.ringScale);
    });

    test('a tab change lerps from the hero profile to History and back', () {
      final hero = AmbientAppProfiles.topicsHero(light);
      final history = AmbientAppProfiles.history(light);
      final half = AmbientProfile.lerp(hero, history, 0.5);
      expect(half.shapes[0].scale, lessThan(hero.shapes[0].scale));
      expect(half.shapes[0].scale, greaterThan(history.shapes[0].scale));
      expect(half.shapes[2].ring, 0.5);
      expect(AmbientProfile.lerp(hero, history, 1), history);
      expect(AmbientProfile.lerp(history, hero, 1), hero);
    });

    test('the Topic screen keeps the three blobs', () {
      final detail = AmbientAppProfiles.topicDetail(light);
      for (final shape in detail.shapes) {
        expect(shape.ring, 0);
        expect(shape.opacity, greaterThan(0));
      }
    });
  });

  group('AmbientShape.ring', () {
    const base = AmbientShape(
      color: Color(0xFF000000),
      opacity: 1,
      anchor: Alignment.center,
      scale: 1,
      turns: 0,
      depth: 0.5,
    );

    test('lerps between a fill and an outline', () {
      final outline = AmbientShape(
        color: base.color,
        opacity: base.opacity,
        anchor: base.anchor,
        scale: base.scale,
        turns: base.turns,
        depth: base.depth,
        ring: 1,
      );
      expect(AmbientShape.lerp(base, outline, 0.25).ring, 0.25);
    });

    test('a shape can be wider than the screen but not unbounded', () {
      const big = AmbientShape(
        color: Color(0xFF000000),
        opacity: 1,
        anchor: Alignment.center,
        scale: 3,
        turns: 0,
        depth: 0,
      );
      expect(
        AmbientShape.lerp(big, big, 0.5).scale,
        AmbientShape.maxScale,
      );
    });
  });

  group('AmbientController route profiles', () {
    const light = AppColors.light;

    test('a registered profile is read back for its path only', () {
      final controller = AmbientController();
      final hero = AmbientAppProfiles.topicsHero(light);
      controller.setRouteProfile('/', hero);
      expect(controller.routeProfileFor('/'), hero);
      expect(controller.routeProfileFor('/history'), isNull);
    });

    test(
      'a route change does not drop it, an override clear does not touch it',
      () {
        final controller = AmbientController();
        final hero = AmbientAppProfiles.topicsHero(light);
        controller
          ..setRouteProfile('/', hero)
          ..setOverride(profile: AmbientAppProfiles.history(light))
          ..clearOverride();
        expect(controller.routeProfileFor('/'), hero);
      },
    );

    test('clearing takes it back and tells the listeners once', () {
      final controller = AmbientController();
      var heard = 0;
      controller
        ..addListener(() => heard++)
        ..setRouteProfile('/', AmbientAppProfiles.topicsHero(light))
        ..setRouteProfile('/', AmbientAppProfiles.topicsHero(light))
        ..clearRouteProfile('/')
        ..clearRouteProfile('/');
      expect(controller.routeProfileFor('/'), isNull);
      expect(heard, 2);
    });
  });

  group('AmbientScope', () {
    testWidgets('reports ambient state down the subtree', (tester) async {
      var detectedInAmbient = false;

      await tester.pumpWidget(
        AmbientScope(
          child: Builder(
            builder: (context) {
              detectedInAmbient = AmbientScope.isInAmbientScope(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(detectedInAmbient, isTrue);
    });

    testWidgets('returns false when outside AmbientScope', (tester) async {
      var detectedInAmbient = true;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            detectedInAmbient = AmbientScope.isInAmbientScope(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(detectedInAmbient, isFalse);
    });
  });
}
