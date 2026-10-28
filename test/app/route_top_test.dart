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
}
