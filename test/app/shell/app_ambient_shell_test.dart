import 'dart:async';

import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const colors = AppColors.light;
  AmbientProfile at(String path) =>
      AppAmbientShell.profileForPath(path, colors);

  group('AppAmbientShell.profileForPath', () {
    test('the sound list moves the backdrop on from Storage', () {
      expect(at('/sounds'), isNot(at('/settings/alarms')));
    });

    test('every way into the sound list shows the same backdrop', () {
      final list = AmbientAppProfiles.soundList(colors);
      expect(at('/sounds'), list);
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

    test('the app icon picker keeps the Settings detail backdrop', () {
      expect(at('/app-icon'), AmbientAppProfiles.settingsDetail(colors));
    });

    test('the Topics tab gets the hero profile, its topic keeps the blobs', () {
      expect(at('/'), AmbientAppProfiles.topicsHero(colors));
      expect(at('/topics/prod-db'), AmbientAppProfiles.topicDetail(colors));
      expect(at('/'), isNot(at('/topics/prod-db')));
    });

    test('the hero profile follows the spot it is given', () {
      const spot = HeroDiscSpot(
        anchor: Alignment(0.2, -0.5),
        discScale: 1,
        ringScale: 1.3,
      );
      expect(
        AppAmbientShell.profileForPath('/', colors, heroSpot: spot),
        AmbientAppProfiles.topicsHero(colors, spot: spot),
      );
    });

    test('alarm and incident paths default to criticalAlarmRinging', () {
      final ringing = AmbientAppProfiles.criticalAlarmRinging(colors);
      expect(at('/alarm'), ringing);
      expect(at('/incidents/123'), ringing);
      expect(at('/incidents/inc_demo'), ringing);
    });
  });

  group('AppAmbientShell.skipsCanvasFor', () {
    // The same shape as the app router: setup steps inside a ShellRoute, the
    // alarm, incident and lock screen routes on the root navigator.
    Widget page(BuildContext context, GoRouterState state) =>
        const SizedBox.shrink();
    final config = RouteConfiguration(
      ValueNotifier(
        RoutingConfig(
          routes: [
            GoRoute(path: '/', builder: page),
            GoRoute(path: '/settings', builder: page),
            ShellRoute(
              builder: (context, state, child) => child,
              routes: [
                GoRoute(path: '/onboarding/permissions', builder: page),
                GoRoute(path: '/onboarding/connect', builder: page),
              ],
            ),
            GoRoute(path: '/alarm', builder: page),
            GoRoute(path: '/incidents/:id', builder: page),
            GoRoute(path: '/lockscreen', builder: page),
          ],
        ),
      ),
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    var pushes = 0;
    RouteMatchList at(String location) => config.findMatch(Uri.parse(location));
    RouteMatchList push(RouteMatchList base, String location) => base.push(
      ImperativeRouteMatch(
        pageKey: ValueKey('push-${pushes++}'),
        matches: at(location),
        completer: Completer<Object?>(),
      ),
    );

    test('a push keeps the base uri, which is why the top match decides', () {
      final routes = push(at('/onboarding/permissions'), '/alarm');
      expect(routes.uri.path, '/onboarding/permissions');
      expect(routes.last.matchedLocation, '/alarm');
    });

    test('a setup step on its own draws no shell canvas', () {
      expect(
        AppAmbientShell.skipsCanvasFor(at('/onboarding/permissions')),
        isTrue,
      );
    });

    test('an alarm pushed over setup gets the shell canvas', () {
      final routes = push(at('/onboarding/permissions'), '/alarm');
      expect(AppAmbientShell.skipsCanvasFor(routes), isFalse);
    });

    test('an incident or the lock screen pushed over setup gets it too', () {
      final setup = at('/onboarding/permissions');
      expect(
        AppAmbientShell.skipsCanvasFor(push(setup, '/incidents/inc_1')),
        isFalse,
      );
      expect(
        AppAmbientShell.skipsCanvasFor(push(setup, '/lockscreen')),
        isFalse,
      );
    });

    test('closing the alarm hands the stack back to setup', () {
      final setup = at('/onboarding/permissions');
      final routes = push(setup, '/alarm');
      final popped = routes.remove(routes.last);
      expect(AppAmbientShell.skipsCanvasFor(popped), isTrue);
    });

    test('setup opened over a screen keeps the canvas under that screen', () {
      final routes = push(at('/settings'), '/onboarding/connect');
      expect(AppAmbientShell.skipsCanvasFor(routes), isFalse);
    });

    test('screens outside setup keep the canvas', () {
      expect(AppAmbientShell.skipsCanvasFor(at('/')), isFalse);
      expect(AppAmbientShell.skipsCanvasFor(at('/alarm')), isFalse);
      expect(
        AppAmbientShell.skipsCanvasFor(push(at('/'), '/alarm')),
        isFalse,
      );
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

        // Canvas remains mounted and profile reverts to the Topics hero, with
        // the disc where this display puts it.
        final homeCanvasWidget = tester.widget<AmbientCanvas>(canvasFinder);
        final spot = heroDiscSpotOf(tester.element(canvasFinder));
        expect(
          homeCanvasWidget.profile,
          AmbientAppProfiles.topicsHero(colors, spot: spot),
        );
        expect(find.text('Home Screen'), findsOneWidget);
      },
    );
  });
}
