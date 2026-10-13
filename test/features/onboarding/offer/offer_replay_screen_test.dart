import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sale_probe.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/alarm/fake_alarm_host.dart';
import '../../../helpers/load_translations.dart';

class _NothingAskedYet implements NotificationPermissionRepository {
  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async =>
      const Success(NotificationPermissionStatus.notDetermined);

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async =>
      const Success(NotificationPermissionStatus.notDetermined);

  @override
  Future<AppResult<bool>> openSettings() async => const Success(true);
}

class _SilentCues extends PaywallCues {
  const _SilentCues();

  @override
  void play(PaywallCue cue) {}
}

/// A setup that has finished everything before the offer.
Map<String, Object> _prefsOfAFinishedSetupSoFar() => {
  'onboarding_flow_id': BundledOnboardingFlows.october2026C.id,
  'onboarding_flow_steps': BundledOnboardingFlows.october2026C.steps,
  'onboarding_flow_completed': [
    'welcome',
    'connect',
    'permissions',
    'use',
    'first_topic',
    'real_ring',
  ],
  'server_url': 'https://api.critalarm.app',
  'admin_token': 'demo',
  'onboarding_first_topic': 'payments-db',
};

void main() {
  const offerPath = '/onboarding/offer';
  const hookUpPath = '/onboarding/hook-up';

  setUpAll(() async {
    await loadTestTranslations();
    FakeAlarmHost();
  });

  /// Opens the app on the mock server with the offer gate set the way a
  /// build says: [usesDemoStore] is the only difference between a build that
  /// skips the store and one that has it.
  Future<GoRouter> open(
    WidgetTester tester, {
    required bool usesDemoStore,
    String? remoteOfferJson,
    bool holdsHosted = false,
    String? accountId = 'acct_made_up',
    Map<String, Object> prefs = const {},
  }) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        ..._prefsOfAFinishedSetupSoFar(),
        ...prefs,
      });
      await getIt.reset();
      await configureDependencies(useMockApi: true);
      await getIt.unregister<NotificationPermissionRepository>();
      getIt.registerLazySingleton<NotificationPermissionRepository>(
        _NothingAskedYet.new,
      );
      if (getIt.isRegistered<PaywallCues>()) {
        await getIt.unregister<PaywallCues>();
      }
      getIt.registerSingleton<PaywallCues>(const _SilentCues());
      await getIt.unregister<PaywallBuyCubit>();
      getIt.registerFactoryParam<
        PaywallBuyCubit,
        PaywallProduct,
        PaywallBuyStatus?
      >(
        (product, _) =>
            DemoPaywallBuyCubit(product, stepTime: const Duration(seconds: 1)),
      );
      await getIt.unregister<OnboardingOfferGate>();
      getIt.registerSingleton<OnboardingOfferGate>(
        OnboardingOfferGate(
          readDeveloperJson: () => null,
          readRemoteJson: () => remoteOfferJson,
          readServerMode: () async => ServerMode.hosted,
          builtLayoutKeys: () => {
            for (final layout in paywallLayoutBuilders.keys) layout.key,
          },
          readAccountId: () async => accountId,
          holdsPro: () => false,
          readHoldsHosted: () async => holdsHosted,
          isSetupComplete: () async => false,
          readFlowSteps: () =>
              getIt<OnboardingFlowEngine>().runningFlow().steps,
          readCompletedSteps: () =>
              getIt<OnboardingFlowRepository>().read().completed,
          readUse: ({required isReplay}) => setupUseFor(
            isReplay: isReplay,
            store: getIt<SetupUseStore>(),
            replay: getIt<SetupUseReplay>(),
          ),
          readTopicName: () =>
              getIt<FirstTopicHandoff>().entry?.topicName ??
              getIt<FirstTopicHandoff>().savedTopicName,
          readSale: (product) => getIt<OfferSaleProbe>().answerFor(product),
          startSale: (product) => getIt<OfferSaleProbe>().start(product),
          readUsesDemoStore: () => usesDemoStore,
        ),
      );
    });
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
        builder: (context, child) =>
            AppAmbientShell(router: router, child: child!),
      ),
    );
    return router;
  }

  Future<void> settle(WidgetTester tester, [int frames = 30]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  }

  Future<void> untilLayerUp(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      if (find.byType(PaywallLayoutView).evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    fail('the offer layer never came up');
  }

  Future<Map<String, Object?>> snapshot(WidgetTester tester) async {
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    return {for (final key in prefs.getKeys()) key: prefs.get(key)};
  }

  Future<void> buyAndLeave(WidgetTester tester) async {
    final buy = find.descendant(
      of: find.byType(PaywallBuyBlock),
      matching: find.byType(AppButton),
    );
    await tester.tap(buy.last);
    await settle(tester, 60);
    expect(find.text('Hook up your tool'), findsOneWidget);
    await tester.tap(find.text('Hook up your tool'));
    await settle(tester, 20);
  }

  group('Redo onboarding reaches the offer', () {
    testWidgets('a build that skips the store plays it and saves nothing', (
      tester,
    ) async {
      final router = await open(
        tester,
        usesDemoStore: true,
        // An account is missing and the product is held: the replay plays
        // the offer anyway.
        accountId: null,
        holdsHosted: true,
      );
      var planChanges = 0;
      appPlanChanges.addListener(() => planChanges++);
      final before = await snapshot(tester);

      // The step before the offer, in a replay, ends and the engine opens
      // the offer with the replay flag carried on.
      getIt<SetupUseReplay>().set(SetupUse.jobs);
      final next = await tester.runAsync(
        () => getIt<OnboardingFlowEngine>().finishStep(
          OnboardingStepId.realRing,
          isReplay: true,
        ),
      );
      expect(next!.route, offerPath);
      router.go('$offerPath?demo=true');
      await tester.pump();
      await untilLayerUp(tester);
      await settle(tester, 10);

      // The reel is led by the answer picked in this replay.
      expect(getIt<SetupUseReplay>().pick, SetupUse.jobs);
      expect(find.byType(PaywallLayoutView), findsOneWidget);

      await buyAndLeave(tester);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        hookUpPath,
      );

      // Nothing reached the phone: no answer, no flag, no event, no
      // completed step, and no screen was told the plan changed.
      expect(await snapshot(tester), before);
      expect(
        (await snapshot(tester)).containsKey(OnboardingFunnel.bufferKey),
        isFalse,
      );
      expect(
        (await snapshot(tester)).containsKey(PaywallDoor.falseAlarmShownKey),
        isFalse,
      );
      expect(planChanges, 0);
    });

    testWidgets('closing the layer goes on and saves nothing', (tester) async {
      final router = await open(tester, usesDemoStore: true);
      final before = await snapshot(tester);
      router.go('$offerPath?demo=true');
      await tester.pump();
      await untilLayerUp(tester);
      await settle(tester, 10);

      await tester.tap(find.byType(AppDismissCross).first);
      await settle(tester, 20);

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        hookUpPath,
      );
      expect(await snapshot(tester), before);
    });

    testWidgets('the offer switch off skips the step', (tester) async {
      final router = await open(
        tester,
        usesDemoStore: true,
        remoteOfferJson: '{"enabled": false}',
      );
      router.go('$offerPath?demo=true');
      await tester.pump();
      await settle(tester, 20);

      expect(find.byType(PaywallLayoutView), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        hookUpPath,
      );
    });

    testWidgets('a build with the real store skips it, as before', (
      tester,
    ) async {
      final router = await open(tester, usesDemoStore: false);
      final before = await snapshot(tester);
      router.go('$offerPath?demo=true');
      await tester.pump();
      await settle(tester, 20);

      expect(find.byType(PaywallLayoutView), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        hookUpPath,
      );
      expect(await snapshot(tester), before);
    });
  });

  group('the real first run', () {
    testWidgets('still plays the offer and records it', (tester) async {
      final router = await open(tester, usesDemoStore: true);
      router.go(offerPath);
      await tester.pump();
      await untilLayerUp(tester);
      await settle(tester, 10);
      await tester.tap(find.byType(AppDismissCross).first);
      await settle(tester, 20);

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        hookUpPath,
      );
      final after = await snapshot(tester);
      expect(after[OnboardingFunnel.bufferKey], contains('"k":"os"'));
      expect(after[OnboardingFunnel.bufferKey], contains('"k":"oc"'));
      expect(
        getIt<OnboardingFlowRepository>().read().completed,
        contains('offer'),
      );
    });

    testWidgets('skips with no account or with the product held', (
      tester,
    ) async {
      for (final held in [false, true]) {
        final router = await open(
          tester,
          usesDemoStore: true,
          accountId: held ? 'acct_made_up' : null,
          holdsHosted: held,
        );
        router.go(offerPath);
        await tester.pump();
        await settle(tester, 20);
        expect(find.byType(PaywallLayoutView), findsNothing);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          hookUpPath,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
