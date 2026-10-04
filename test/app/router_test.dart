import 'package:critalarm/app/router.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Walks a route and everything nested under it.
Iterable<RouteBase> _flatten(RouteBase route) sync* {
  yield route;
  if (route is StatefulShellRoute) {
    for (final branch in route.branches) {
      for (final child in branch.routes) {
        yield* _flatten(child);
      }
    }
  } else {
    for (final child in route.routes) {
      yield* _flatten(child);
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

  group('the app icon route', () {
    test('is top level and draws on the root navigator', () {
      final routes = buildRouter().configuration.routes;

      final picker = routes
          .whereType<GoRoute>()
          .where((r) => r.name == AppRoute.appIcon)
          .toList();

      expect(picker, hasLength(1));
      expect(picker.single.path, '/app-icon');
      expect(picker.single.parentNavigatorKey, isNotNull);
      expect(picker.single.redirect, isNotNull);
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

      expect(names, isNot(contains(AppRoute.appIcon)));
    });
  });

  group('ambient transitions across application routes', () {
    test('all visual routes define pageBuilder and not legacy builder', () {
      final routes = buildRouter().configuration.routes
          .expand(_flatten)
          .whereType<GoRoute>()
          .where((r) => r.pageBuilder != null || r.builder != null);

      expect(routes, isNotEmpty);
      for (final route in routes) {
        expect(
          route.pageBuilder,
          isNotNull,
          reason: 'Route ${route.name ?? route.path} must define pageBuilder',
        );
        expect(
          route.builder,
          isNull,
          reason:
              'Route ${route.name ?? route.path} should not define legacy '
              'builder',
        );
      }
    });
  });

  group('the setup step routes', () {
    test('every step with a screen has one route, under its own name', () {
      final routes = buildRouter().configuration.routes
          .expand(_flatten)
          .whereType<GoRoute>()
          .toList();

      for (final step in OnboardingStepRegistry.entries) {
        final matches = routes.where((r) => r.path == step.route).toList();
        expect(
          matches,
          hasLength(step.route == null ? 0 : 1),
          reason: step.id,
        );
        if (step.route != null) {
          expect(matches.single.name, step.routeName, reason: step.id);
          expect(step.screen, isNotNull, reason: step.id);
        }
      }
    });

    test('the names other screens navigate by still resolve', () {
      final names = buildRouter().configuration.routes
          .expand(_flatten)
          .whereType<GoRoute>()
          .map((r) => r.name)
          .toSet();

      expect(
        names,
        containsAll([
          AppRoute.onboarding,
          AppRoute.onboardingWelcome,
          AppRoute.onboardingHowItRings,
          AppRoute.onboardingConnect,
          AppRoute.onboardingWidgets,
          AppRoute.onboardingFirstTopic,
          AppRoute.onboardingRealRing,
          AppRoute.onboardingTest,
          AppRoute.onboardingDenied,
          AppRoute.onboardingPermissions,
        ]),
      );
    });
  });
}
