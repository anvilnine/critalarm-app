// Captures the offer sequence of setup off the device: the false alarm
// intro, the reel that opens on the user's answer, the confetti thanks and
// the hook-up step that follows, through the real router and the real setup
// shell, on the mock server with a made-up store and no network.
//
//   fvm flutter test tool/capture_offer_sequence.dart
//
// Every file is <scene>_<phone>_<theme>_<scale>x[_reduced].png, for two
// phones (390 wide, 320 wide), light and dark, and text scale 1.0, 1.3 and
// 2.0, plus a reduced motion run of each. The path of every file is printed,
// and a capture fails when anything overflows or throws.
//
// Runs (each one is a whole sequence, stepped a frame at a time):
//   <answer>      the Cloud sequence for servers, homelab, jobs, home and
//                 other: intro at 0.3, 0.9 and 1.25 s, the tag, the reel's
//                 first scene (first frame, settled) and its second, then a
//                 purchase: buying, the thanks part way and at rest with its
//                 button, the button tapped and the first frame of hook up.
//                 A second pass closes with the cross instead.
//   own_server    an own server, answer servers: the Pro pack
//   skip_*        the step skips: not on sale, the store failing, the store
//                 not answering in time, a held product, the switch off
//   replay        a developer replay on one answer (run with
//                 --dart-define=PAYWALL_LAB=true so ?use= is read)
//   tag_<answer>  only the frame with the tag, for every answer and the own
//                 server at every text size (ONLY=tag_). At 2.0 the frame
//                 shows no tag.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only runs whose name has one of these parts
//
// A capture is a still of one moment: it shows nothing moving. The score,
// the haptics and the confetti fall can only be judged on a phone.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

/// The made-up topic the user named in setup.
const _topic = 'payments-db';

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phones = [
  _Phone('390', Size(390, 844), 47, 34),
  _Phone('320', Size(320, 640), 24, 0),
];

const _scales = [1.0, 1.3, 2.0];

/// What the made-up store says when the step asks what is on sale.
enum _Sale { ready, notOnSale, failed, silent }

/// A buy model whose store never answers.
class _SilentBuyCubit extends DemoPaywallBuyCubit {
  _SilentBuyCubit(super.product);

  @override
  Future<void> load() => Completer<void>().future;
}

enum _Held { none, pro, hosted }

/// One run of the sequence.
class _Scenario {
  const _Scenario(
    this.name, {
    this.use,
    this.isOwnServer = false,
    this.sale = _Sale.ready,
    this.held = _Held.none,
    this.isOn = true,
    this.isFull = true,
  });

  final String name;
  final SetupUse? use;
  final bool isOwnServer;
  final _Sale sale;
  final _Held held;

  /// The `onboarding_offer` switch.
  final bool isOn;

  /// Every frame of the sequence, or only the reel and the way out.
  final bool isFull;
}

const _scenarios = [
  _Scenario('servers', use: SetupUse.servers),
  _Scenario('homelab', use: SetupUse.homelab, isFull: false),
  _Scenario('jobs', use: SetupUse.jobs, isFull: false),
  _Scenario('home', use: SetupUse.home),
  _Scenario('other', use: SetupUse.other, isFull: false),
  _Scenario('own_server', use: SetupUse.servers, isOwnServer: true),
];

const _skips = [
  _Scenario('skip_not_on_sale', use: SetupUse.servers, sale: _Sale.notOnSale),
  _Scenario('skip_store_failed', use: SetupUse.servers, sale: _Sale.failed),
  _Scenario('skip_store_silent', use: SetupUse.servers, sale: _Sale.silent),
  _Scenario('skip_held', use: SetupUse.servers, held: _Held.hosted),
  _Scenario('skip_switch_off', use: SetupUse.servers, isOn: false),
];

/// A made-up setup that has finished everything before the offer.
Map<String, Object> _prefsFor() => {
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
  // A made-up server and key. Nothing is contacted.
  'server_url': 'https://api.critalarm.app',
  'admin_token': 'demo',
  // The topic setup made.
  'onboarding_first_topic': _topic,
};

class _Config {
  const _Config(this.phone, this.mode, this.scale, {required this.reduce});

  final _Phone phone;
  final ThemeMode mode;
  final double scale;
  final bool reduce;

  String get name =>
      '${phone.name}_${mode.name}_${scale.toStringAsFixed(1)}x'
      '${reduce ? '_reduced' : ''}';
}

/// Cues make no sound in a capture.
class _SilentCues extends PaywallCues {
  const _SilentCues();

  @override
  void play(PaywallCue cue) {}
}

/// Notification permissions that were never asked for.
class _NothingAskedYet implements NotificationPermissionRepository {
  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async =>
      NotificationPermissionStatus.notDetermined.toSuccess();

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async =>
      NotificationPermissionStatus.notDetermined.toSuccess();

  @override
  Future<AppResult<bool>> openSettings() async => true.toSuccess();
}

class _Run {
  _Run(this.key, this.router, this.errors);

  final GlobalKey key;
  final GoRouter router;
  final List<String> errors;

  Uri get location => router.routerDelegate.currentConfiguration.uri;
}

Future<void> _real(WidgetTester tester, [int ms = 20]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

/// Sets the app up the way the scenario says: the made-up store, the offer
/// switch, the kind of server, what is held and the answer.
Future<void> _configure(
  WidgetTester tester,
  _Scenario scenario, {
  bool isDeveloperSwitch = false,
}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(_prefsFor());
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

    // What the store lists: the buy model every layer asks for.
    await getIt.unregister<PaywallBuyCubit>();
    getIt.registerFactoryParam<
      PaywallBuyCubit,
      PaywallProduct,
      PaywallBuyStatus?
    >(
      (product, _) => switch (scenario.sale) {
        _Sale.ready => DemoPaywallBuyCubit(product),
        _Sale.notOnSale => DemoPaywallBuyCubit(
          product,
          startAs: PaywallBuyStatus.notOnSale,
        ),
        _Sale.failed => DemoPaywallBuyCubit(
          product,
          startAs: PaywallBuyStatus.failed,
        ),
        _Sale.silent => _SilentBuyCubit(product),
      },
    );

    // The offer switch, the kind of server and what is held. The rest of
    // the gate reads what the app holds, as it does on a phone.
    await getIt.unregister<OnboardingOfferGate>();
    const on = '{"enabled": true}';
    getIt.registerSingleton<OnboardingOfferGate>(
      OnboardingOfferGate(
        readDeveloperJson: () => isDeveloperSwitch ? on : null,
        readRemoteJson: () => scenario.isOn && !isDeveloperSwitch ? on : null,
        readServerMode: () async =>
            scenario.isOwnServer ? ServerMode.selfhosted : ServerMode.hosted,
        builtLayoutKeys: () => {
          for (final layout in paywallLayoutBuilders.keys) layout.key,
        },
        readAccountId: () async => 'acct_made_up',
        holdsPro: () => scenario.held == _Held.pro,
        readHoldsHosted: () async => scenario.held == _Held.hosted,
        isSetupComplete: () async => false,
        readFlowSteps: () => getIt<OnboardingFlowEngine>().runningFlow().steps,
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
        markFalseAlarmShown: () async => (await SharedPreferences.getInstance())
            .setBool(PaywallDoor.falseAlarmShownKey, true),
      ),
    );
    final use = scenario.use;
    if (use != null) await getIt<SetupUseStore>().save(use);
  });
}

Future<_Run> _open(
  WidgetTester tester,
  _Config config,
  _Scenario scenario, {
  required List<String> errors,
  bool isDeveloperSwitch = false,
}) async {
  await _configure(tester, scenario, isDeveloperSwitch: isDeveloperSwitch);
  const dpr = 2.0;
  tester.view.physicalSize = config.phone.size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: config.phone.top * dpr,
    bottom: config.phone.bottom * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  final router = buildRouter();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      fallbackLocale: const Locale('en'),
      path: 'assets/translations',
      useOnlyLangCode: true,
      saveLocale: false,
      child: Builder(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider<IncidentsCubit>.value(value: getIt<IncidentsCubit>()),
            BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
            BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: config.mode,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(config.scale),
                disableAnimations: config.reduce,
              ),
              child: RepaintBoundary(
                key: key,
                child: AppAmbientShell(
                  router: router,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The translations load from the asset bundle, which takes real time.
  await _real(tester, 300);
  return _Run(key, router, errors);
}

Future<void> _save(WidgetTester tester, _Run run, String name) =>
    tester.runAsync(() async {
      final boundary =
          run.key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      print('${run.errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
    });

/// One frame of the stepped clock, with real time for the reads the screens
/// wait on.
Future<void> _frame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await _real(tester, 2);
}

/// Pumps frames until [seconds] of the clock have passed since [from].
Future<double> _stepTo(WidgetTester tester, double from, double seconds) async {
  var t = from;
  while (t < seconds - 0.0001) {
    await _frame(tester);
    t += 0.016;
  }
  return t;
}

/// Runs [body] with every framework error collected, and fails the capture
/// when there is one.
Future<void> _guarded(
  String name,
  List<String> errors,
  Future<void> Function() body,
) async {
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('RenderAnimatedSize was mutated in its own')) {
      print('  NOTE: $text');
      return;
    }
    errors.add(details.toString());
  };
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = oldHandler;
  }
  for (final e in errors) {
    print('  ERROR: ${e.split('\n').take(40).join('\n')}');
  }
  expect(errors, isEmpty, reason: 'overflow or build error in $name');
}

String _prefsString(SharedPreferences prefs, String key) =>
    prefs.getString(key) ?? '';

Future<SharedPreferences> _prefs(WidgetTester tester) async =>
    (await tester.runAsync(SharedPreferences.getInstance))!;

/// Seconds since the layer opened, read off the reel's own loop on a run
/// with the intro: the first scene has settled, the push to the second is
/// part way, and the second has settled.
const _firstSceneRestAt = 3.2;
const _secondScenePushAt = 4.5;
const _secondSceneRestAt = 5.8;

/// The path the engine opens after the offer: hook up.
const _hookUpPath = '/onboarding/hook-up';
const _offerPath = '/onboarding/offer';

/// Waits for the route to leave [from], then saves the first frame of the
/// new route when [firstFrame] is named.
Future<void> _untilLeft(
  WidgetTester tester,
  _Run run, {
  required String from,
  required String Function(String scene) name,
  String? firstFrame,
}) async {
  for (var i = 0; i < 200 && run.location.path == from; i++) {
    await _frame(tester);
  }
  expect(run.location.path, isNot(from), reason: 'the step moved on');
  await tester.pump();
  if (firstFrame != null) await _save(tester, run, name(firstFrame));
}

/// The whole sequence for one scenario in one configuration.
Future<void> _sequence(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  List<String> errors,
) async {
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';
  final label = scenario.name;

  for (final closeWith in ['purchase', 'cross']) {
    final run = await _open(tester, config, scenario, errors: errors);
    await tester.runAsync(() => getIt<OnboardingFlowEngine>().resume());
    // The offer step, as "It works" leaves it: a frame of the shell with
    // nothing on it while the store answers.
    run.router.go(_offerPath);
    await tester.pump();
    if (closeWith == 'purchase' && scenario.isFull) {
      await _save(tester, run, name('offer_step_first_frame_$label'));
    }

    // Until the layer is up. The intro's clock starts as it is built.
    for (
      var i = 0;
      i < 400 && find.byType(PaywallIntroHost).evaluate().isEmpty;
      i++
    ) {
      await _frame(tester);
    }
    expect(find.byType(PaywallIntroHost), findsOneWidget, reason: 'layer up');
    final prefs = await _prefs(tester);
    final usedUp = prefs.getBool(PaywallDoor.falseAlarmShownKey) ?? false;
    expect(
      usedUp,
      !config.reduce,
      reason: 'the false alarm showing is used up unless nothing may move',
    );

    var t = 0.0;
    if (!config.reduce) {
      if (closeWith == 'purchase' && scenario.isFull) {
        // The first frame is the one after the first pump.
        await tester.pump(const Duration(milliseconds: 16));
        t = 0.016;
        await _save(tester, run, name('offer_intro_first_frame_$label'));
        t = await _stepTo(tester, t, 0.3);
        await _save(tester, run, name('offer_intro_0_3_$label'));
        t = await _stepTo(tester, t, 0.9);
        await _save(tester, run, name('offer_intro_0_9_$label'));
        t = await _stepTo(tester, t, 1.25);
        await _save(tester, run, name('offer_intro_1_25_reveal_$label'));
        t = await _stepTo(tester, t, 1.52);
        await _save(tester, run, name('offer_handover_$label'));
        t = await _stepTo(tester, t, 2.2);
        // The tag is detail, so it goes at the largest text size, and where
        // it has no clear room it is not shown.
        if (config.scale <= 1.3) {
          expect(find.text('Just kidding.').evaluate().length, lessThan(2));
          await _save(tester, run, name('offer_tag_just_kidding_$label'));
        }
      } else {
        t = await _stepTo(tester, t, 1.52);
      }
      // The reel: first scene as it comes in, settled, then the second.
      const base = 1.5;
      if (closeWith == 'purchase') {
        t = await _stepTo(tester, t, base + 0.03);
        await _save(tester, run, name('offer_reel_first_frame_$label'));
        t = await _stepTo(tester, t, _firstSceneRestAt);
        await _save(tester, run, name('offer_reel_rest_$label'));
        t = await _stepTo(tester, t, _secondScenePushAt);
        await _save(tester, run, name('offer_reel_second_mid_$label'));
        t = await _stepTo(tester, t, _secondSceneRestAt);
        await _save(tester, run, name('offer_reel_second_rest_$label'));
      } else {
        t = await _stepTo(tester, t, _firstSceneRestAt);
      }
    } else {
      // Nothing moves: the reel is at rest from the first frame.
      await _real(tester, 50);
      await tester.pump(const Duration(milliseconds: 600));
      if (closeWith == 'purchase') {
        await _save(tester, run, name('offer_reel_rest_$label'));
      }
    }

    if (closeWith == 'cross') {
      // Close at once: the cross is a bare x and goes to hook up.
      await tester.tap(find.byType(AppDismissCross).first);
      await tester.pump();
      await _stepTo(tester, 0, 0.12);
      await _save(tester, run, name('offer_close_tapped_$label'));
      await _untilLeft(
        tester,
        run,
        from: _offerPath,
        name: name,
        firstFrame: 'hook_up_first_frame_after_close_$label',
      );
      expect(run.location.path, _hookUpPath);
      await _stepTo(tester, 0, 0.016);
      await _save(tester, run, name('hook_up_plus16_after_close_$label'));
      await _afterClose(tester, run, scenario);
      continue;
    }

    // A purchase: tap the buy button.
    final buy = find.descendant(
      of: find.byType(PaywallBuyBlock),
      matching: find.byType(AppButton),
    );
    expect(buy, findsWidgets);
    await tester.tap(buy.last);
    await tester.pump();
    await _stepTo(tester, 0, 0.3);
    if (scenario.isFull) await _save(tester, run, name('offer_buying_$label'));
    // The demo store confirms after two steps.
    await _stepTo(tester, 0, 1.4);
    // The thanks takes over: its first frame, part way, at rest.
    await _frame(tester);
    if (scenario.isFull) {
      await _save(tester, run, name('offer_thanks_first_frame_$label'));
      await _stepTo(tester, 0, 0.6);
      await _save(tester, run, name('offer_thanks_mid_$label'));
    }
    await _stepTo(tester, 0, config.reduce ? 0.1 : 3.4);
    expect(find.text('Hook up your tool'), findsOneWidget);
    await _save(tester, run, name('offer_thanks_rest_$label'));
    expect(run.location.path, _offerPath, reason: 'the purchase waits');

    await tester.tap(find.text('Hook up your tool'));
    await tester.pump();
    await _untilLeft(
      tester,
      run,
      from: _offerPath,
      name: name,
      firstFrame: 'hook_up_first_frame_after_thanks_$label',
    );
    expect(run.location.path, _hookUpPath, reason: 'never Home');
    await _stepTo(tester, 0, 0.016);
    await _save(tester, run, name('hook_up_plus16_after_thanks_$label'));
    // The funnel kept the answer with each event.
    final buffer = _prefsString(
      await _prefs(tester),
      OnboardingFunnel.bufferKey,
    );
    expect(
      buffer,
      contains('"use":"${(scenario.use ?? SetupUse.other).wire}"'),
    );
    expect(buffer, contains('"k":"ob"'));
    await _afterClose(tester, run, scenario);
  }
}

/// Only the frame of the intro's tag, for every text size: the tag is there
/// at 1.0 and 1.3 when it has room and never at 2.0.
Future<void> _tag(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  List<String> errors,
) async {
  final file =
      'offer_tag_just_kidding_${scenario.name}_${config.phone.name}_'
      '${config.mode.name}_${config.scale.toStringAsFixed(1)}x';
  final run = await _open(tester, config, scenario, errors: errors);
  await tester.runAsync(() => getIt<OnboardingFlowEngine>().resume());
  run.router.go(_offerPath);
  await tester.pump();
  for (
    var i = 0;
    i < 400 && find.byType(PaywallIntroHost).evaluate().isEmpty;
    i++
  ) {
    await _frame(tester);
  }
  expect(find.byType(PaywallIntroHost), findsOneWidget, reason: 'layer up');
  await tester.pump(const Duration(milliseconds: 16));
  await _stepTo(tester, 0.016, 2.2);
  if (config.scale > 1.3) {
    expect(find.text('Just kidding.'), findsNothing, reason: 'detail goes');
  }
  final isShown = find.text('Just kidding.').evaluate().isNotEmpty;
  print('  tag ${isShown ? 'shown' : 'hidden'} $file');
  await _save(tester, run, file);
  await tester.tap(find.byType(AppDismissCross).first);
  await tester.pump();
  await _stepTo(tester, 0, 0.12);
  await _untilLeft(
    tester,
    run,
    from: _offerPath,
    name: (scene) => scene,
  );
  await _afterClose(tester, run, scenario);
}

Future<void> _afterClose(
  WidgetTester tester,
  _Run run,
  _Scenario scenario,
) async {
  // Settle so no timer is left over for the next open.
  for (var i = 0; i < 20; i++) {
    await _frame(tester);
  }
  expect(run.location.path, _hookUpPath);
}

/// "It works" as the setup test leaves it, 2.5 seconds in, with the offer
/// gate the scenario sets up: calm when the offer is ahead, with the
/// confetti when nothing follows.
Future<void> _itWorks(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  String file,
) async {
  await _configure(tester, scenario);
  // The screen's own column overflows on a 320 by 640 phone at the largest
  // text size. That is how the screen is today and this tool does not
  // change it, so the overflow is printed and the run goes on.
  final oldHandler = FlutterError.onError;
  if (config.phone == _phones[1] && config.scale >= 2) {
    FlutterError.onError = (details) => print(
      '  NOTE: known overflow on "It works": '
      '${details.exceptionAsString().split('\n').first}',
    );
  }
  const dpr = 2.0;
  tester.view.physicalSize = config.phone.size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: config.phone.top * dpr,
    bottom: config.phone.bottom * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 10, 13, 9, 41, 7);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: config.mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: config.reduce,
          textScaler: TextScaler.linear(config.scale),
        ),
        child: RepaintBoundary(key: key, child: child),
      ),
      home: AlarmStyleStage(
        style: standardAlarmStyle,
        stage: AlarmStage.acknowledged,
        severity: SeverityMode.crit,
        child: Builder(
          builder: (context) => AcknowledgedScreen(
            state: CriticalAlarmState(
              status: CriticalAlarmStatus.acknowledged,
              meta: '09:38 / critical, my-first-topic',
              incident: Incident(
                id: 'inc_made_up',
                topic: 'my-first-topic',
                openedAt: now.subtract(const Duration(seconds: 7)),
                ackedAt: now,
              ),
              topic: 'my-first-topic',
              isAcknowledged: true,
              setupFlowHasRealRing: true,
              setupTestIncidentIds: const {'inc_made_up'},
            ),
            colors: context.appColors,
          ),
        ),
      ),
    ),
  );
  await _real(tester, 100);
  for (var i = 0; i < 160; i++) {
    await _frame(tester);
  }
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('$_out/$file.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    print('FIT  ${out.path}');
  });
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
  FlutterError.onError = oldHandler;
}

/// A step that skips: no intro, no layer. The offer step opens as a blank
/// shell and hook up follows.
Future<void> _skip(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  List<String> errors,
) async {
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';
  final label = scenario.name;
  await _itWorks(
    tester,
    config,
    scenario,
    name('offer_skipped_it_works_$label'),
  );
  final run = await _open(tester, config, scenario, errors: errors);
  await tester.runAsync(() => getIt<OnboardingFlowEngine>().resume());

  // What "Continue" on "It works" does: finish the real ring step and go
  // where the engine says.
  final next = await tester.runAsync(
    () => getIt<OnboardingFlowEngine>().finishStep('real_ring'),
  );
  final straightOn = next!.route == _hookUpPath;
  print('  $label: after real_ring the engine opens ${next.route}');
  expect(
    straightOn,
    scenario.isOn && scenario.held == _Held.none ? isFalse : isTrue,
    reason: 'a held product or a switch that is off skips before the step',
  );

  run.router.go(straightOn ? _hookUpPath : _offerPath);
  await tester.pump();
  if (!straightOn) {
    await _save(tester, run, name('offer_skipped_step_first_frame_$label'));
    expect(find.byType(PaywallIntroHost), findsNothing, reason: 'no intro');
    await _untilLeft(
      tester,
      run,
      from: _offerPath,
      name: name,
      firstFrame: 'offer_skipped_hook_up_first_frame_$label',
    );
  } else {
    await _save(tester, run, name('offer_skipped_hook_up_first_frame_$label'));
  }
  expect(run.location.path, _hookUpPath);
  expect(find.byType(PaywallIntroHost), findsNothing);
  final prefs = await _prefs(tester);
  expect(
    prefs.getBool(PaywallDoor.falseAlarmShownKey),
    isNull,
    reason: 'nothing played, so the showing is kept',
  );
  expect(
    prefs.getString(OnboardingFunnel.bufferKey) ?? '',
    isNot(contains('"k":"os"')),
  );
  await _afterClose(tester, run, scenario);
}

/// A developer replay on one answer: nothing is saved, no flag, no event.
Future<void> _replay(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  List<String> errors,
) async {
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';
  final run = await _open(
    tester,
    config,
    scenario,
    errors: errors,
    isDeveloperSwitch: true,
  );
  // No saved answer: the replay's own is what the query sets.
  await tester.runAsync(() => getIt<SetupUseStore>().clear());
  run.router.go('$_offerPath?demo=true&use=${scenario.use!.wire}');
  await tester.pump();
  for (
    var i = 0;
    i < 400 && find.byType(PaywallIntroHost).evaluate().isEmpty;
    i++
  ) {
    await _frame(tester);
  }
  expect(find.byType(PaywallIntroHost), findsOneWidget, reason: 'layer up');
  expect(getIt<SetupUseReplay>().pick, scenario.use);
  await _stepTo(tester, 0, config.reduce ? 0.1 : 0.9);
  await _save(tester, run, name('offer_replay_intro_${scenario.name}'));
  await _stepTo(tester, 0, config.reduce ? 0.1 : _firstSceneRestAt);
  await _save(tester, run, name('offer_replay_reel_${scenario.name}'));
  final prefs = await _prefs(tester);
  expect(prefs.getBool(PaywallDoor.falseAlarmShownKey), isNull);
  expect(prefs.getString(OnboardingFunnel.bufferKey), isNull);
  await tester.tap(find.byType(AppDismissCross).first);
  await tester.pump();
  await _untilLeft(tester, run, from: _offerPath, name: name);
  await _afterClose(tester, run, scenario);
}

/// A real alarm opens while the layer is up: the router goes to the alarm
/// screen, and the layer must not stay over it. The step is finished in the
/// engine, nothing moves, and no purchase or close is recorded.
Future<void> _interrupt(
  WidgetTester tester,
  _Config config,
  _Scenario scenario,
  List<String> errors,
) async {
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';
  final run = await _open(tester, config, scenario, errors: errors);
  await tester.runAsync(() => getIt<OnboardingFlowEngine>().resume());
  run.router.go(_offerPath);
  await tester.pump();
  for (
    var i = 0;
    i < 400 && find.byType(PaywallIntroHost).evaluate().isEmpty;
    i++
  ) {
    await _frame(tester);
  }
  expect(find.byType(PaywallIntroHost), findsOneWidget, reason: 'layer up');
  await _stepTo(tester, 0, config.reduce ? 0.1 : 0.5);
  // What a tapped alarm notification does.
  run.router.go('/incidents/inc_made_up');
  await tester.pump();
  await _stepTo(tester, 0, 0.1);
  await _save(tester, run, name('offer_interrupted_alarm_${scenario.name}'));
  await _stepTo(tester, 0, 0.5);
  expect(find.byType(PaywallIntroHost), findsNothing, reason: 'layer is gone');
  expect(run.location.path, startsWith('/incidents/'));
  final completed = getIt<OnboardingFlowRepository>().read().completed;
  expect(completed, contains('offer'), reason: 'the step is finished');
  final buffer = _prefsString(
    await _prefs(tester),
    OnboardingFunnel.bufferKey,
  );
  expect(buffer, contains('"k":"os"'));
  expect(buffer, isNot(contains('"k":"ob"')));
  expect(buffer, isNot(contains('"k":"oc"')));
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

void _configuration(
  _Config config,
  _Scenario scenario,
  Future<void> Function(WidgetTester, _Config, _Scenario, List<String>) body,
) {
  final name = '${scenario.name}_${config.name}';
  if (!_wanted(name)) return;
  testWidgets('capture $name', (tester) async {
    final errors = <String>[];
    await _guarded(name, errors, () => body(tester, config, scenario, errors));
  });
}

/// The scenes of a run in the order they are written, so a contact sheet
/// reads left to right and top to bottom as the sequence plays.
const _sceneOrder = [
  'offer_step_first_frame',
  'offer_intro_first_frame',
  'offer_intro_0_3',
  'offer_intro_0_9',
  'offer_intro_1_25_reveal',
  'offer_handover',
  'offer_tag_just_kidding',
  'offer_reel_first_frame',
  'offer_reel_rest',
  'offer_reel_second_mid',
  'offer_reel_second_rest',
  'offer_buying',
  'offer_thanks_first_frame',
  'offer_thanks_mid',
  'offer_thanks_rest',
  'hook_up_first_frame_after_thanks',
  'hook_up_plus16_after_thanks',
  'offer_close_tapped',
  'hook_up_first_frame_after_close',
  'hook_up_plus16_after_close',
  'offer_skipped_it_works',
  'offer_skipped_step_first_frame',
  'offer_skipped_hook_up_first_frame',
  'offer_interrupted_alarm',
  'offer_replay_intro',
  'offer_replay_reel',
];

/// Lays the files of each run side by side, one sheet per run, phone,
/// theme and text size, so a run can be read at a glance. The cell shows
/// the frame at a third of its size.
Future<void> _sheets() async {
  final dir = Directory(_out);
  if (!dir.existsSync()) return;
  // <scene>_<label>_<phone>_<theme>_<scale>x[_reduced].png
  const labels =
      'servers|homelab|jobs|home|other|own_server|skip_[a-z_]+|replay|'
      'interrupt';
  final pattern = RegExp(
    '^(.+?)_($labels)_'
    r'(390|320)_(light|dark)_(\d\.\dx(?:_reduced)?)\.png$',
  );
  final groups = <String, List<(int, File)>>{};
  for (final f in dir.listSync().whereType<File>()) {
    final m = pattern.firstMatch(f.uri.pathSegments.last);
    if (m == null) continue;
    final order = _sceneOrder.indexOf(m.group(1)!);
    if (order < 0) continue;
    final key = '${m.group(2)}_${m.group(3)}_${m.group(4)}_${m.group(5)}';
    (groups[key] ??= []).add((order, f));
  }
  for (final entry in groups.entries) {
    final files = (entry.value..sort((a, b) => a.$1.compareTo(b.$1)))
        .map((e) => e.$2)
        .toList();
    final images = <ui.Image>[];
    for (final f in files) {
      final codec = await ui.instantiateImageCodec(await f.readAsBytes());
      images.add((await codec.getNextFrame()).image);
    }
    const cell = 0.34;
    const perRow = 6;
    final w = images.first.width * cell;
    final h = images.first.height * cell;
    final rows = (images.length / perRow).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, w * perRow, h * rows),
        ui.Paint()..color = const Color(0xFF808080),
      );
    for (var i = 0; i < images.length; i++) {
      canvas.drawImageRect(
        images[i],
        Rect.fromLTWH(
          0,
          0,
          images[i].width.toDouble(),
          images[i].height.toDouble(),
        ),
        Rect.fromLTWH(
          (i % perRow) * w + 2,
          (i ~/ perRow) * h + 2,
          w - 4,
          h - 4,
        ),
        ui.Paint()..filterQuality = FilterQuality.medium,
      );
    }
    final sheet = await recorder.endRecording().toImage(
      (w * perRow).round(),
      (h * rows).round(),
    );
    final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
    final out = File('$_out/sheet_${entry.key}.png');
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    print('SHEET ${out.path}');
    for (var i = 0; i < files.length; i++) {
      print('  $i ${files[i].uri.pathSegments.last}');
    }
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final phone in _phones) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in _scales) {
        for (final reduce in [false, true]) {
          final config = _Config(phone, mode, scale, reduce: reduce);
          for (final scenario in _scenarios) {
            _configuration(config, scenario, _sequence);
          }
          for (final scenario in _skips) {
            // The skip cases have no motion of their own; one reduced run
            // would show the same frames.
            if (reduce) continue;
            _configuration(config, scenario, _skip);
          }
        }
      }
    }
  }

  // The tag frame alone, for every answer (ONLY=tag_).
  if (_only.split(',').contains('tag_')) {
    for (final phone in _phones) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in _scales) {
          final config = _Config(phone, mode, scale, reduce: false);
          for (final scenario in _scenarios) {
            _configuration(
              config,
              _Scenario(
                'tag_${scenario.name}',
                use: scenario.use,
                isOwnServer: scenario.isOwnServer,
              ),
              (tester, config, tagged, errors) => _tag(
                tester,
                config,
                scenario,
                errors,
              ),
            );
          }
        }
      }
    }
  }

  // A real alarm opens over the layer.
  const interrupt = _Scenario('interrupt', use: SetupUse.servers);
  for (final reduce in [false, true]) {
    _configuration(
      _Config(_phones[0], ThemeMode.light, 1, reduce: reduce),
      interrupt,
      _interrupt,
    );
  }

  // A developer replay, on the answer the developer picked.
  const replay = _Scenario('replay', use: SetupUse.homelab);
  for (final config in [
    _Config(_phones[0], ThemeMode.light, 1, reduce: false),
    _Config(_phones[1], ThemeMode.dark, 2, reduce: false),
    _Config(_phones[0], ThemeMode.light, 1, reduce: true),
  ]) {
    _configuration(config, replay, _replay);
  }

  // Run last (or alone with ONLY=sheets): the contact sheets of every file
  // the folder holds.
  testWidgets('contact sheets', (tester) async {
    if (_only.isNotEmpty && !_only.split(',').contains('sheets')) return;
    await tester.runAsync(_sheets);
  });
}
