import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/access/access_fakes.dart';

void main() {
  late TestAccess access;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  tearDown(() async {
    await access.dispose();
  });

  Future<GoRouter> openSettings(
    WidgetTester tester, {
    ServerMode mode = ServerMode.hosted,
    Set<Holding> held = const {},
    String path = '/settings/account',
  }) async {
    // Made here, inside the test's own zone: a future made in a setUp
    // completes outside the fake clock and the screen never sees it.
    access = TestAccess(held: held);
    // The settings cubit asks the container for its holdings each time the
    // screen opens, so a test hands it holdings it can move.
    if (getIt.isRegistered<Holdings>()) getIt.unregister<Holdings>();
    getIt.registerSingleton<Holdings>(access.holdings);
    await getIt<ApiSessionStore>().write(_session(mode));
    getIt<MockServer>().seedCalm();
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final router = buildRouter();
    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: getIt<ThemeCubit>(),
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    router.go(path);
    await tester.pumpAndSettle();
    return router;
  }

  // The plan card and the Pro row moved from Settings to Account and plan.
  // The card on top of Settings carries the same two buttons.
  // The mock server here never says what the plan is, so the plan name
  // reads "Plan unavailable", as the plan card always did.
  group('the card on top of Settings', () {
    testWidgets('offers Cloud and Pro to a person without Cloud', (
      tester,
    ) async {
      await openSettings(tester, path: '/settings');

      expect(find.text('Plan unavailable'), findsOneWidget);
      expect(find.text('See Cloud'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      // Above the phone checks card.
      final hero = tester.getTopLeft(find.text('See Pro')).dy;
      final checks = tester.getTopLeft(find.text('PHONE CHECKS')).dy;
      expect(hero, lessThan(checks));
    });

    testWidgets('an own server offers Pro alone', (tester) async {
      await openSettings(
        tester,
        mode: ServerMode.selfhosted,
        path: '/settings',
      );

      expect(find.text('Self-hosted'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('See Cloud'), findsNothing);
    });

    testWidgets('Pro owned shows the badge and no button', (tester) async {
      await openSettings(tester, path: '/settings');
      access.pro.set(HoldingState.held);
      await tester.pumpAndSettle();
      expect(find.text('See Pro'), findsNothing);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('a tap opens Account and plan', (tester) async {
      await openSettings(tester, path: '/settings');
      await tester.tap(find.text('Plan unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Account and plan'), findsWidgets);
      expect(find.text('Plan'), findsOneWidget);
    });
  });

  group('the Pro row on Account and plan', () {
    testWidgets('sits under the plan card with the button for a person '
        'without Pro', (tester) async {
      await openSettings(tester);

      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      // The Cloud card keeps its own button.
      expect(find.text('See Cloud'), findsOneWidget);
      final plan = tester.getTopLeft(find.text('See Cloud')).dy;
      final pro = tester.getTopLeft(find.text('Pro')).dy;
      expect(pro, greaterThan(plan));
    });

    testWidgets('shows on a phone with its own server', (tester) async {
      await openSettings(tester, mode: ServerMode.selfhosted);

      // The plan card says there is no plan, and the Pro row is still there.
      expect(find.text('This phone uses your own server'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('See Cloud'), findsNothing);
    });

    testWidgets('holding Hosted does not hide it', (tester) async {
      await openSettings(tester, held: {Holding.hosted});

      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('See Cloud'), findsNothing);
    });

    testWidgets('changes to owned on the same screen when Pro lands', (
      tester,
    ) async {
      await openSettings(tester);
      expect(find.text('See Pro'), findsOneWidget);

      access.pro.set(HoldingState.pending);
      await tester.pumpAndSettle();
      expect(find.text('See Pro'), findsNothing);
      expect(find.bySemanticsLabel('Checking your Pro purchase'), findsOne);

      access.pro.set(HoldingState.held);
      await tester.pumpAndSettle();
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('See Pro'), findsNothing);
      expect(find.bySemanticsLabel('You have Pro'), findsOneWidget);
    });

    testWidgets('the button opens the Pro paywall from Settings, never the '
        'Hosted one', (tester) async {
      final router = await openSettings(tester);

      // The paywall layout draws in this test with the test font, whose
      // widths overflow some of its rows. That is not what this test is
      // about, so overflow reports are let through. Anything else fails.
      final onError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = onError);
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        onError?.call(details);
      };

      await tester.ensureVisible(find.text('See Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See Pro'));
      // Not pumpAndSettle: the paywall layout moves without stopping.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final last = router.routerDelegate.currentConfiguration.last;
      final opened = last is ImperativeRouteMatch ? last.matches.uri : null;
      expect(opened, isNotNull);
      expect(opened!.queryParameters['source'], 'settings_plan');
      // A layout route that names Pro, never the Hosted product.
      expect(opened.path, startsWith('/plans/'), reason: '$opened');
      expect(opened.queryParameters['product'], 'pro', reason: '$opened');

      // Unmount and let the clocks run out, so nothing is left pending.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}

ApiSession _session(ServerMode mode) => ApiSession(
  baseUri: Uri.parse('https://alerts.anvilnine.com'),
  relayUri: Uri.parse('https://relay.critalarm.app'),
  mode: mode,
  managementCredential: 'admin_test_token',
);
