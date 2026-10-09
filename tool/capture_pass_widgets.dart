// Captures the Widgets page of Personalize off the device, on the mock server
// and the developer plan switches, through the real router and the real
// ambient shell.
//
//   fvm flutter test tool/capture_pass_widgets.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=plans,sizes (default: all):
//   plans    the page in every plan state: free, pro, hosted, notread (the
//            plan still being read), own (a server of the user's own with
//            nothing held), ownpro (the same with Pro), confirming,
//            unreadable. 390 by 844, light and dark; the last two light only
//   sizes    free at 375 by 667, 320 by 640, 1024 by 768 and 844 by 390, and
//            at text scale 1.3 and 2.0 where the matrix has them, plus pro
//            at the same sizes (one button)
//   sheet    the steps sheet on iOS and on Android, as Free sees it (with the
//            needs-Pro note and its button) and as Pro sees it, light
//   taps     what a tap on each button does: How to add one, See Pro (the
//            paywall), and See Pro inside the sheet (the sheet closes, then
//            the paywall)
//   reduce   the resting frame under reduce motion
//   ring     the Open incidents face part way through each of its two rings
//   grow     the page reached from the root: the grow at 0.25, 0.5, 0.75 and
//            1, light and dark, and the way back at 0.5
//   absent   a platform with no home screen widgets: the root draws no
//            Widgets pass, and the Widgets route sends the person back
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a207)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the face ringing or the grow playing.
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
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';
import 'capture_pass_kit.dart';
import 'own_look_photos.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a207');
const _partsArg = String.fromEnvironment('PARTS');

/// The page name in every file.
const _page = 'widgets';

/// Where the page lives.
const _location = '/settings/personalize/widgets';

/// The Personalize root, where the cards are.
const _rootLocation = '/settings/personalize';

/// A server of the user's own with nothing held. The kit's own-server state
/// holds Pro; this one is the plain state, where Widgets still need Pro.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// A server of the user's own with Pro held.
const _ownServerPro = PassPlanState(
  'ownpro',
  preset: AccessPreset.pro,
  isOwnServer: true,
);

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.platform = TargetPlatform.android,
    this.isWeb = false,
  });

  final PassPlanState plan;

  /// The phone the steps are worded for.
  final TargetPlatform platform;

  /// A platform with no home screen widgets and no icon change.
  final bool isWeb;
}

/// The preferences that hold [plan], as the developer switches save them.
Map<String, Object> _planPrefs(PassPlanState plan) {
  final preset = plan.preset;
  return {
    if (preset != null)
      for (final entry in preset.holdings.entries)
        DevAccessSwitches.holdingKey(entry.key): entry.value.name,
    if (preset != null && preset.holdsPlanRead)
      DevAccessSwitches.holdsPlanReadKey: true,
    // The kit's plan not read yet holds the plan read open.
    if (!plan.isPlanRead) DevAccessSwitches.holdsPlanReadKey: true,
    if (plan.isOwnServer) DevAccessSwitches.serverModeKey: 'ownServer',
  };
}

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _boot(WidgetTester tester, _Setup setup) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
    ..._planPrefs(setup.plan),
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  getIt<MockServer>().seedCalm();
  await useCaptureOwnLookStore();
  getIt
    ..unregister<PlatformCapabilities>()
    ..registerSingleton<PlatformCapabilities>(
      PlatformCapabilities(isWeb: setup.isWeb, platform: setup.platform),
    );
}

/// Lets the root ask the app icon and the sound host what they would.
void _mockChannels(_Setup setup) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async {
            if (setup.isWeb) throw MissingPluginException();
            return call.method == 'current' ? 'default' : true;
          },
        )
        ..setMockMethodCallHandler(
          const MethodChannel(SoundHost.channelName),
          (call) async => switch (call.method) {
            'readPeaks' => <double>[
              for (var i = 0; i < 48; i++) 0.2 + 0.75 * ((i * 5) % 9) / 8,
            ],
            'capabilities' => <String, Object?>{'can_import_sounds': false},
            _ => null,
          },
        );
  addTearDown(() {
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel(AppIconHost.channelName),
        null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel(SoundHost.channelName),
        null,
      );
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 400);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 200);
  await tester.pump(const Duration(milliseconds: 600));
}

/// A running shot: the key of what is saved and the router that moves it.
class _Run {
  _Run(this.key, this.router);

  final GlobalKey key;
  final GoRouter router;
}

/// Boots the app and opens the Widgets page, or with [openPage] false the
/// Personalize root, to tap a card.
Future<_Run> _open(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
  bool holdClock = true,
  bool openPage = true,
}) async {
  _mockChannels(setup);
  await tester.runAsync(() => _boot(tester, setup));
  const dpr = 2.0;
  tester.view.physicalSize = device.size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: device.safeTop * dpr,
    bottom: device.safeBottom * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  final router = buildRouter();
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: RepaintBoundary(
            key: key,
            // A held clock draws the resting frame of every motion, so two
            // shots of one state are the same picture. The ring shots let
            // it run.
            child: PaywallStill(
              isStill: holdClock,
              child: AppAmbientShell(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  router.go('/');
  await _settle(tester);
  unawaited(router.push(openPage ? _location : _rootLocation));
  await _settle(tester);
  await tester.pump(const Duration(seconds: 1));
  return _Run(key, router);
}

Future<void> _save(
  WidgetTester tester,
  _Run run,
  String name,
  List<String> errors,
) => tester.runAsync(() async {
  final boundary =
      run.key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
});

/// Runs [body] with every framework error collected, and fails the capture
/// when there is one.
Future<void> _guarded(
  String name,
  Future<void> Function(List<String> errors) body,
) async {
  final errors = <String>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    // Reduce motion gives an AnimatedSize a zero duration, which marks
    // itself dirty while it lays out when its child changes size. A debug
    // build only.
    if (text.contains('RenderAnimatedSize was mutated in its own')) {
      print('  NOTE: $text');
      return;
    }
    errors.add(details.toString());
  };
  debugDisableShadows = false;
  try {
    await body(errors);
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = oldHandler;
  }
  for (final e in errors) {
    print('  ERROR: ${e.split('\n').take(40).join('\n')}');
  }
  expect(errors, isEmpty, reason: 'overflow or build error in $name');
}

Set<String> get _parts => _partsArg.isEmpty
    ? {'plans', 'sizes', 'sheet', 'taps', 'reduce', 'ring', 'grow', 'absent'}
    : _partsArg.split(',').toSet();

/// Registers one capture of the page as it opens.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  String frame = 'rest',
  bool reduceMotion = false,
  bool openPage = true,
  Future<void> Function(WidgetTester tester, _Run run)? act,
}) {
  if (!_parts.contains(part)) return;
  final name = passFileName(
    page: _page,
    device: device,
    mode: mode,
    scale: scale,
    frame: frame,
    state: state,
  );
  if (!passWanted(name)) return;
  testWidgets('capture $name', (tester) async {
    await _guarded(name, (errors) async {
      final run = await _open(
        tester,
        setup: setup,
        device: device,
        mode: mode,
        scale: scale,
        reduceMotion: reduceMotion,
        openPage: openPage,
      );
      if (act != null) await act(tester, run);
      await _save(tester, run, name, errors);
    });
  });
}

/// Taps the card of [pass] on the root, on the band that shows.
Future<void> _tapCard(WidgetTester tester, PassId pass) async {
  final card = find.byKey(ValueKey('pass-${pass.name}'));
  expect(card, findsOneWidget, reason: 'no card for ${pass.name}');
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

/// Taps the button with [key] and lets what it opens settle.
Future<void> _tapButton(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  expect(button, findsOneWidget, reason: 'no button $key');
  await tester.tap(button);
  await _settle(tester);
}

/// The text of the sheet's See Pro button.
Finder get _sheetSeePro =>
    find.widgetWithText(AppButton, 'See Pro').hitTestable();

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  tearDownAll(dropCaptureOwnLookStore);

  // The plan states.
  for (final plan in [
    PassPlanState.free,
    PassPlanState.pro,
    PassPlanState.hosted,
    PassPlanState.notRead,
    _ownServer,
    _ownServerPro,
    PassPlanState.confirming,
    PassPlanState.unreadable,
  ]) {
    final isMain = const {
      'free',
      'pro',
      'hosted',
      'notread',
      'own',
      'ownpro',
    }.contains(plan.name);
    for (final mode in isMain ? passThemes : [ThemeMode.light]) {
      _shot(
        part: 'plans',
        state: plan.name,
        setup: _Setup(plan: plan),
        device: passPhone,
        mode: mode,
      );
    }
  }

  // The sizes and text scales: Free (two buttons) and Pro (one).
  for (final device in passDevices) {
    for (final scale in passScalesFor(device)) {
      for (final mode in passThemes) {
        for (final plan in [PassPlanState.free, PassPlanState.pro]) {
          if (device == passPhone && scale == 1) continue;
          _shot(
            part: 'sizes',
            state: plan.name,
            setup: _Setup(plan: plan),
            device: device,
            mode: mode,
            scale: scale,
          );
        }
      }
    }
  }

  // The steps sheet on each platform, for Free and for Pro.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final os = platform == TargetPlatform.iOS ? 'ios' : 'android';
    for (final plan in [PassPlanState.free, PassPlanState.pro]) {
      for (final mode in passThemes) {
        _shot(
          part: 'sheet',
          state: '${plan.name}-$os',
          setup: _Setup(plan: plan, platform: platform),
          device: passPhone,
          mode: mode,
          frame: 'sheet',
          act: (tester, run) => _tapButton(tester, 'widgets-how-to'),
        );
      }
    }
  }
  // The sheet at the largest text and the narrowest phone.
  for (final device in [passPhone, passNarrowPhone]) {
    _shot(
      part: 'sheet',
      state: 'free-android',
      setup: const _Setup(),
      device: device,
      mode: ThemeMode.light,
      scale: 2,
      frame: 'sheet',
      act: (tester, run) => _tapButton(tester, 'widgets-how-to'),
    );
  }
  // The plan still being read: the steps show and nothing is sold.
  _shot(
    part: 'sheet',
    state: 'notread-android',
    setup: const _Setup(plan: PassPlanState.notRead),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'sheet',
    act: (tester, run) => _tapButton(tester, 'widgets-how-to'),
  );

  // What a tap does. There is no try on this page: the widgets are pictures,
  // so a tap on See Pro is the keep action and opens the paywall.
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'tap-see-pro',
    act: (tester, run) => _tapButton(tester, 'widgets-see-plan'),
  );
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'tap-sheet-see-pro',
    act: (tester, run) async {
      await _tapButton(tester, 'widgets-how-to');
      expect(_sheetSeePro, findsOneWidget);
      await tester.tap(_sheetSeePro);
      await _settle(tester);
    },
  );

  // Reduce motion: the resting frame.
  for (final mode in passThemes) {
    _shot(
      part: 'reduce',
      state: 'free',
      setup: const _Setup(),
      device: passPhone,
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
  }

  // The face part way through each ring. The clock runs from the page's
  // first frame: the first ring starts 0.6 s in and the second 2.0 s in, and
  // each shot is 0.2 s or 0.7 s into its ring.
  for (final mode in passThemes) {
    for (final (ring, seconds) in const [
      ('ring1-0.2s', 0.8),
      ('ring1-0.7s', 1.3),
      ('ring2-0.2s', 2.2),
      ('ring2-0.7s', 2.7),
      ('ring-rest', 3.4),
    ]) {
      final name = passFileName(
        page: _page,
        device: passPhone,
        mode: mode,
        scale: 1,
        frame: ring,
        state: 'free',
      );
      if (!_parts.contains('ring') || !passWanted(name)) continue;
      testWidgets('capture $name', (tester) async {
        await _guarded(name, (errors) async {
          final run = await _open(
            tester,
            setup: const _Setup(),
            device: passPhone,
            mode: mode,
            scale: 1,
            holdClock: false,
            openPage: false,
          );
          await _tapCard(tester, PassId.widgets);
          // The route is built and the page's clock is at zero.
          await tester.pump();
          await tester.pump();
          await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
          await _save(tester, run, name, errors);
        });
      });
    }
  }

  // The page reached from the root: the grow, and the way back.
  for (final mode in passThemes) {
    final base = passFileName(
      page: 'grow-widgets',
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'x',
      state: 'free',
    );
    if (!_parts.contains('grow') || !passWanted(base)) continue;
    testWidgets('capture grow widgets ${mode.name}', (tester) async {
      await _guarded(base, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: mode,
          scale: 1,
          openPage: false,
        );
        Future<void> save(String frame) => _save(
          tester,
          run,
          passFileName(
            page: 'grow-widgets',
            device: passPhone,
            mode: mode,
            scale: 1,
            frame: frame,
            state: 'free',
          ),
          errors,
        );
        await _tapCard(tester, PassId.widgets);
        await tester.pump();
        await tester.pump();
        var elapsed = 0;
        // The route is 600 ms.
        for (final percent in const [0, 25, 50, 75, 100]) {
          final target = (600 * percent / 100).round();
          if (target > elapsed) {
            await tester.pump(Duration(milliseconds: target - elapsed));
            elapsed = target;
          }
          await save('open-t${percent.toString().padLeft(3, '0')}');
        }
        await tester.pump(const Duration(seconds: 1));
        run.router.pop();
        await tester.pump();
        await tester.pump();
        // The way back is 520 ms.
        await tester.pump(const Duration(milliseconds: 260));
        await save('back-t050');
      });
    });
  }

  // A platform with no home screen widgets: the root draws no Widgets pass,
  // and a deep link to the page lands on the root.
  for (final mode in passThemes) {
    _shot(
      part: 'absent',
      state: 'web',
      setup: const _Setup(isWeb: true, platform: TargetPlatform.macOS),
      device: passPhone,
      mode: mode,
      frame: 'root',
      openPage: false,
    );
  }
  _shot(
    part: 'absent',
    state: 'web',
    setup: const _Setup(isWeb: true, platform: TargetPlatform.macOS),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'redirect',
    act: (tester, run) async {
      expect(
        find.byKey(const ValueKey('pass-widgets')),
        findsNothing,
        reason: 'the root has a Widgets pass on a platform with no widgets',
      );
    },
  );

  // Scroll: the header at rest, half way through its collapse and collapsed,
  // on both phones and both text scales.
  forEachPassScroll((device, mode, scale, at) {
    _shot(
      part: 'scroll',
      state: 'free',
      setup: const _Setup(),
      device: device,
      mode: mode,
      scale: scale,
      frame: at.frame,
      act: (tester, run) =>
          scrollPassPage(tester, at, device: device, scale: scale),
    );
  });
}
