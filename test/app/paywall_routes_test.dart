import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_tap_route.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every route the app has, nested ones included.
Iterable<GoRoute> _allRoutes(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) yield route;
    if (route is StatefulShellRoute) {
      yield* _allRoutes(route.branches.expand((branch) => branch.routes));
    } else {
      yield* _allRoutes(route.routes);
    }
  }
}

/// The two paywall routes as the app wires them, over a bare home page.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SizedBox()),
    GoRoute(
      path: paywallPath,
      name: AppRoute.paywall,
      redirect: (context, state) =>
          resolvePaywallLocation(state.uri.toString()),
    ),
    GoRoute(
      path: paywallLayoutPath,
      name: AppRoute.paywallLayout,
      builder: (_, _) => const SizedBox(),
    ),
  ],
);

/// Where a tap on a reminder of [kind] goes, for someone who holds nothing.
String _reminderRoute(LocalReminderKind kind) =>
    (LocalReminderTapRoute.resolve(
              LocalReminderTap(kind: kind, actionId: 'open'),
            )!
            as OpenRouteAction)
        .path;

List<String> _stack(GoRouter router) => [
  for (final match in router.routerDelegate.currentConfiguration.matches)
    match.matchedLocation,
];

void main() {
  group('the route table', () {
    final routes = _allRoutes(buildRouter().configuration.routes).toList();

    test('/paywall draws nothing of its own: it only redirects', () {
      final paywall = routes.where((r) => r.path == paywallPath).toList();
      expect(paywall, hasLength(1));
      expect(paywall.single.name, AppRoute.paywall);
      expect(paywall.single.redirect, isNotNull);
      expect(paywall.single.builder, isNull);
      expect(paywall.single.pageBuilder, isNull);
    });

    test('the layout route draws, with no gate in front of it', () {
      final layout = routes.where((r) => r.path == paywallLayoutPath).toList();
      expect(layout, hasLength(1));
      expect(layout.single.name, AppRoute.paywallLayout);
      expect(layout.single.redirect, isNull);
      expect(layout.single.pageBuilder, isNotNull);
    });

    test('there is no /pro route and no route named for the Pro sheet', () {
      expect(routes.map((r) => r.path), isNot(contains('/pro')));
      expect(routes.map((r) => r.name), isNot(contains('proPack')));
    });
  });

  group('a raw /paywall path', () {
    // The places that build the path with no door at hand.
    final raw = <String, String>{
      'the morning after reminder': _reminderRoute(
        LocalReminderKind.morningAfter,
      ),
      'the Pro later reminder': _reminderRoute(LocalReminderKind.proLater),
      'the settings search result': SettingsSearchIndex.all
          .firstWhere((destination) => destination.id == 'plan')
          .routePath,
      'a locked home screen widget': PushDeepLink.paywallLocation,
      'a link with no source': paywallPath,
      'a link with a source this build does not know':
          '$paywallPath?source=nope',
    };

    test('is what each of them builds', () {
      for (final entry in raw.entries) {
        expect(Uri.parse(entry.value).path, paywallPath, reason: entry.key);
      }
    });

    test('resolves to a layout', () {
      for (final entry in raw.entries) {
        final resolved = Uri.parse(resolvePaywallLocation(entry.value));
        expect(resolved.path, startsWith('/plans/'), reason: entry.key);
        expect(
          resolved.queryParameters['product'],
          anyOf('hosted', 'pro'),
          reason: entry.key,
        );
      }
    });

    testWidgets('opens the layout route when it is pushed or gone to', (
      tester,
    ) async {
      for (final entry in raw.entries) {
        final router = _router();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        // Pushed, as a reminder tap is.
        // The push is never awaited: it completes when the page closes.
        // ignore: unawaited_futures
        router.push<void>(entry.value);
        await tester.pumpAndSettle();
        final pushed = router.routerDelegate.currentConfiguration.last;
        expect(pushed.route.name, AppRoute.paywallLayout, reason: entry.key);
        expect(_stack(router), hasLength(2), reason: entry.key);

        // Gone to, as a link that starts the app is.
        router.go(entry.value);
        await tester.pumpAndSettle();
        final gone = router.routerDelegate.currentConfiguration.last;
        expect(gone.route.name, AppRoute.paywallLayout, reason: entry.key);
        expect(gone.matchedLocation, startsWith('/plans/'), reason: entry.key);
      }
    });
  });

  group('a paywall that is already up', () {
    testWidgets('a second shared file does not stack a second paywall', (
      tester,
    ) async {
      for (final offer in Holding.values) {
        final router = _router();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        // What a shared file opens while own sounds are locked.
        final location = paywallLocationFor(
          FeatureDecision.locked(offer),
          LockSource.sounds,
        )!;
        expect(paywallIsOnTop(router), isFalse);

        expect(openPaywallOnce(router, location), isTrue);
        await tester.pumpAndSettle();
        expect(paywallIsOnTop(router), isTrue);
        expect(_stack(router), hasLength(2), reason: '$offer');

        // The second file lands while the first paywall is still up.
        expect(openPaywallOnce(router, location), isFalse);
        await tester.pumpAndSettle();
        expect(_stack(router), hasLength(2), reason: '$offer');
        expect(
          _stack(router).where((path) => path.startsWith('/plans/')),
          hasLength(1),
          reason: '$offer',
        );

        // Once it is closed the next file opens one again.
        router.pop();
        await tester.pumpAndSettle();
        expect(paywallIsOnTop(router), isFalse);
        expect(openPaywallOnce(router, location), isTrue);
        await tester.pumpAndSettle();
        expect(_stack(router), hasLength(2), reason: '$offer');
      }
    });

    testWidgets('a raw /paywall path counts as a paywall once it is open', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(openPaywallOnce(router, paywallPath), isTrue);
      await tester.pumpAndSettle();
      expect(paywallIsOnTop(router), isTrue);
      expect(openPaywallOnce(router, paywallPath), isFalse);
      await tester.pumpAndSettle();
      expect(_stack(router), hasLength(2));
    });

    testWidgets('any other page on top lets the paywall open', (tester) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(paywallIsOnTop(router), isFalse);
      expect(openPaywallOnce(router, '/plans/hero?product=pro'), isTrue);
      await tester.pumpAndSettle();
      expect(_stack(router).last, '/plans/hero');
    });
  });
}
