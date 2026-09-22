import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const colors = AppColors.light;
  AmbientProfile at(String path) =>
      AppAmbientShell.profileForPath(path, colors);

  group('AppAmbientShell.profileForPath', () {
    test('the sound list moves the backdrop on from Alarms', () {
      expect(at('/settings/alarms/sounds'), isNot(at('/settings/alarms')));
    });

    test('every way into the sound list shows the same backdrop', () {
      final list = AmbientAppProfiles.soundList(colors);
      expect(at('/sounds'), list);
      expect(at('/settings/alarms/sounds'), list);
      expect(at('/topics/prod/sounds'), list);
    });

    test('the cropper moves the backdrop on from the sound list', () {
      expect(at('/sounds/crop'), isNot(at('/sounds')));
      expect(at('/sounds/crop'), AmbientAppProfiles.soundEditor(colors));
    });

    test('the recorder moves the backdrop on from the sound list', () {
      expect(at('/sounds/record'), isNot(at('/sounds')));
      expect(at('/sounds/record'), AmbientAppProfiles.soundEditor(colors));
    });

    test('alarm and incident paths default to criticalAlarmRinging', () {
      final ringing = AmbientAppProfiles.criticalAlarmRinging(colors);
      expect(at('/alarm'), ringing);
      expect(at('/incidents/123'), ringing);
      expect(at('/incidents/inc_demo'), ringing);
    });
  });

  group('AppAmbientShell widget', () {
    testWidgets(
      'mounts persistent AmbientCanvas on /alarm and updates via AmbientOverride',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/alarm',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: '/alarm',
              builder: (context, state) => Scaffold(
                body: AmbientOverride(
                  profile: AmbientAppProfiles.criticalAlarmAcknowledged(colors),
                  direction: AmbientDirection.push,
                  child: const Text('Acknowledged Screen'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => AppAmbientShell(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );

        // Verify persistent canvas is mounted for /alarm
        final canvasFinder = find.byKey(const ValueKey('app-ambient-canvas'));
        expect(canvasFinder, findsOneWidget);

        // Let AmbientOverride postFrameCallback apply
        await tester.pumpAndSettle();

        final canvasWidget = tester.widget<AmbientCanvas>(canvasFinder);
        expect(
          canvasWidget.profile,
          AmbientAppProfiles.criticalAlarmAcknowledged(colors),
        );

        // Navigate to /
        router.go('/');
        await tester.pumpAndSettle();

        // Canvas remains mounted and profile reverts to topics
        final homeCanvasWidget = tester.widget<AmbientCanvas>(canvasFinder);
        expect(homeCanvasWidget.profile, AmbientAppProfiles.topics(colors));
        expect(find.text('Home Screen'), findsOneWidget);
      },
    );
  });
}
