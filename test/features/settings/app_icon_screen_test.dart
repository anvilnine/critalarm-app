import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/app_icon_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core/access/access_fakes.dart';

/// The App icon screen with a hand-set plan: nothing from the store, the
/// relay or the platform.
void main() {
  late TestAccess access;
  late bool welcomed;

  /// The screen on a router that also has the two paywalls, as stubs.
  GoRouter routerFor() => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AppIconScreen()),
      GoRoute(path: '/paywall', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/pro',
        name: 'proPack',
        builder: (_, _) => const SizedBox(),
      ),
    ],
  );

  Future<GoRouter> open(
    WidgetTester tester, {
    required Set<Holding> held,
    bool isStill = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    access = TestAccess(held: held);
    addTearDown(access.dispose);
    await getIt.reset();
    getIt
      ..registerSingleton<FeatureAccess>(access.features)
      ..registerFactory<AppIconCubit>(
        () => AppIconCubit(
          readCurrent: () async => AppIcon.standard,
          apply: (_) async => true,
          readUnlocked: () => access.features.canOnceReady(AppFeature.appIcons),
          readWelcomed: () async => welcomed,
          markWelcomed: () async => welcomed = true,
          planChanges: PlanChanges(),
        ),
      );
    addTearDown(getIt.reset);

    final router = routerFor();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: isStill),
          child: child!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return router;
  }

  /// On to the first paid icon.
  Future<void> toCrowned(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Crowned'), findsOneWidget);
  }

  String top(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  setUp(() => welcomed = true);

  group('the first visit with the icons unlocked', () {
    setUp(() => welcomed = false);

    testWidgets('draws the welcome line under reduce motion with no layout '
        'error', (tester) async {
      await open(tester, held: {Holding.pro});
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Your extra icons'), findsOneWidget);
      expect(welcomed, isTrue);
    });

    testWidgets('plays the welcome with motion on with no layout error', (
      tester,
    ) async {
      await open(tester, held: {Holding.hosted}, isStill: false);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Your extra icons'), findsOneWidget);
      // The screen's clock never stops, so the tree is taken down by hand.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('a locked icon', () {
    testWidgets('keeps its picture at full colour, with the badge under its '
        'name', (tester) async {
      await open(tester, held: {});
      await toCrowned(tester);

      // Nothing recolours an icon: the badge is what says it is locked.
      expect(
        find.ancestor(
          of: find.byType(AppIconPreview),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      expect(find.byType(ProBadge), findsOneWidget);
    });

    testWidgets('says the plan once: the badge, and one button that names '
        'no plan', (tester) async {
      final router = await open(tester, held: {});
      await toCrowned(tester);

      expect(find.widgetWithText(AppButton, 'Unlock'), findsOneWidget);
      expect(find.text('Go Hosted'), findsNothing);
      expect(find.text('Comes with Hosted or Pro'), findsNothing);
      expect(find.byType(ProBadge), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The one door picks the paywall from the decision, not the screen.
      expect(top(router), anyOf('/paywall', '/pro'));
    });

    testWidgets('an open icon has no badge and offers Use this icon', (
      tester,
    ) async {
      await open(tester, held: {Holding.hosted});
      await toCrowned(tester);

      expect(find.byType(ProBadge), findsNothing);
      expect(find.widgetWithText(AppButton, 'Use this icon'), findsOneWidget);
    });
  });
}
