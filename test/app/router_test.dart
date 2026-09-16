import 'package:critalarm/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Walks a route and everything nested under it.
Iterable<RouteBase> _flatten(RouteBase route) sync* {
  yield route;
  for (final child in route.routes) {
    yield* _flatten(child);
  }
  if (route is StatefulShellRoute) {
    for (final branch in route.branches) {
      for (final child in branch.routes) {
        yield* _flatten(child);
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the sound picker route', () {
    test('is top level and draws on the root navigator', () {
      final routes = buildRouter().configuration.routes;

      final picker = routes
          .whereType<GoRoute>()
          .where((r) => r.name == AppRoute.soundPicker)
          .toList();

      expect(picker, hasLength(1));
      expect(picker.single.path, '/sounds');
      expect(picker.single.parentNavigatorKey, isNotNull);
    });

    test('is not nested under settings, which would switch the tab', () {
      final settings = buildRouter().configuration.routes
          .expand(_flatten)
          .whereType<GoRoute>()
          .firstWhere((r) => r.name == AppRoute.settings);

      final names = settings.routes
          .expand(_flatten)
          .whereType<GoRoute>()
          .map((r) => r.name);

      expect(names, isNot(contains(AppRoute.soundPicker)));
    });
  });
}
