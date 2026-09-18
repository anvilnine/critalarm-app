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
          AmbientAppProfiles.history(colors),
          AmbientAppProfiles.settings(colors),
          AmbientAppProfiles.topicDetail(colors),
          AmbientAppProfiles.historyDetail(colors),
          AmbientAppProfiles.settingsDetail(colors),
        ];

        for (final profile in profiles) {
          expect(profile.shapes.length, 3);
          expect(profile.surfaceOpacity, inInclusiveRange(0.0, 1.0));

          for (final shape in profile.shapes) {
            expect(shape.opacity, inInclusiveRange(0.0, 1.0));
            expect(shape.scale, inInclusiveRange(0.0, 1.0));
            expect(shape.depth, inInclusiveRange(0.0, 1.0));
            expect(shape.anchor.x, inInclusiveRange(-1.0, 1.0));
            expect(shape.anchor.y, inInclusiveRange(-1.0, 1.0));
          }
        }
      }
    });

    test('forTabIndex returns matching root profiles', () {
      const colors = AppColors.light;
      expect(
        AmbientAppProfiles.forTabIndex(0, colors),
        AmbientAppProfiles.topics(colors),
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
        expect(AmbientAppProfiles.history(colors).canvas, colors.canvas);
        expect(AmbientAppProfiles.settings(colors).canvas, colors.canvas);
      }
    });

    test('all app profiles can lerp smoothly to any other profile', () {
      const colors = AppColors.dark;
      final profiles = [
        AmbientAppProfiles.criticalAlarmRinging(colors),
        AmbientAppProfiles.criticalAlarmAcknowledged(colors),
        AmbientAppProfiles.createTopic(colors),
        AmbientAppProfiles.topics(colors),
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
