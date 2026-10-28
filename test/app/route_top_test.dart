import 'dart:async';

import 'package:critalarm/app/route_top.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // The same shape as the app router: setup steps inside a ShellRoute, the
  // alarm, incident and lock screen routes on the root navigator.
  Widget page(BuildContext context, GoRouterState state) =>
      const SizedBox.shrink();
  final config = RouteConfiguration(
    ValueNotifier(
      RoutingConfig(
        routes: [
          GoRoute(path: '/', builder: page),
          ShellRoute(
            builder: (context, state, child) => child,
            routes: [
              GoRoute(path: '/onboarding/real-ring', builder: page),
            ],
          ),
          GoRoute(path: '/alarm', builder: page),
          GoRoute(path: '/incidents/:id', builder: page),
          GoRoute(path: '/lockscreen', builder: page),
          GoRoute(path: '/permissions/ask', builder: page),
          GoRoute(path: '/sounds/crop', builder: page),
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

  group('topPathOf', () {
    test('an alarm pushed over Home is the top, not the base uri', () {
      final routes = push(at('/'), '/alarm');
      expect(routes.uri.path, '/');
      expect(topPathOf(routes), '/alarm');
    });

    test('an incident pushed over Home reads with its id', () {
      expect(
        topPathOf(push(at('/'), '/incidents/inc_1')),
        '/incidents/inc_1',
      );
    });

    test('an alarm opened with go reads as itself', () {
      expect(topPathOf(at('/alarm')), '/alarm');
      expect(topPathOf(at('/incidents/inc_1')), '/incidents/inc_1');
    });

    test('a setup step inside the shell reads as its own path', () {
      expect(topPathOf(at('/onboarding/real-ring')), '/onboarding/real-ring');
    });

    test('an alarm pushed over setup is the top', () {
      expect(topPathOf(push(at('/onboarding/real-ring'), '/alarm')), '/alarm');
    });

    test('the query is left out, as uri.path left it out', () {
      expect(
        topPathOf(at('/onboarding/real-ring?demo=true')),
        '/onboarding/real-ring',
      );
    });

    test('closing the pushed alarm hands the top back', () {
      final routes = push(at('/'), '/alarm');
      expect(topPathOf(routes.remove(routes.last)), '/');
    });

    test('an empty list reads as /', () {
      expect(topPathOf(RouteMatchList.empty), '/');
    });
  });

  group('alarmIsOnTop', () {
    const step = '/onboarding/real-ring';

    test('an alarm pushed over the step is on top', () {
      expect(alarmIsOnTop(push(at(step), '/alarm')), isTrue);
    });

    test('an incident pushed over the step is on top', () {
      expect(alarmIsOnTop(push(at(step), '/incidents/inc_1')), isTrue);
    });

    test('an alarm opened with go is on top', () {
      expect(alarmIsOnTop(at('/incidents/inc_1')), isTrue);
    });

    test('a page that is not the alarm, pushed over the step, is not', () {
      expect(alarmIsOnTop(push(at(step), '/permissions/ask')), isFalse);
      expect(alarmIsOnTop(push(at(step), '/sounds/crop')), isFalse);
      expect(alarmIsOnTop(push(at(step), '/lockscreen')), isFalse);
    });

    test('the step itself is not', () {
      expect(alarmIsOnTop(at(step)), isFalse);
    });

    test('an empty list is not', () {
      expect(alarmIsOnTop(RouteMatchList.empty), isFalse);
    });
  });

  group('setupStepMayOpenAlarm', () {
    const step = '/onboarding/real-ring';

    test('the step on its own opens the alarm', () {
      expect(setupStepMayOpenAlarm(at(step), step), isTrue);
    });

    test('a page that is not the alarm pushed over the step does not stop '
        'it', () {
      expect(
        setupStepMayOpenAlarm(push(at(step), '/permissions/ask'), step),
        isTrue,
      );
      expect(
        setupStepMayOpenAlarm(push(at(step), '/sounds/crop'), step),
        isTrue,
      );
    });

    test('an alarm already pushed over the step stops it', () {
      expect(setupStepMayOpenAlarm(push(at(step), '/alarm'), step), isFalse);
      expect(
        setupStepMayOpenAlarm(push(at(step), '/incidents/inc_1'), step),
        isFalse,
      );
    });

    test('an alarm pushed over another page pushed over the step stops it', () {
      final routes = push(push(at(step), '/permissions/ask'), '/alarm');
      expect(setupStepMayOpenAlarm(routes, step), isFalse);
    });

    test('the router gone elsewhere with go stops it', () {
      expect(setupStepMayOpenAlarm(at('/incidents/inc_1'), step), isFalse);
      expect(setupStepMayOpenAlarm(at('/'), step), isFalse);
    });
  });
}
