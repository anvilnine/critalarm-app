// Captures the App icon page, the last pass of Personalize, off the device,
// on the mock server and the developer plan switches, through the real
// router and the real ambient shell. The page is reached the way a person
// reaches it: the Personalize root, then the App icon card.
//
//   fvm flutter test tool/capture_pass_icon.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
// The page is `icon`. The state says what the shot shows.
//
// Parts, picked with --dart-define=PARTS=icons,plans (default: all):
//   icons    each of the four icons centred, Hosted held, the icon in use
//            being Default (so Default shows the status, the others Use)
//   plans    a locked icon centred in every plan state: free, pro, hosted,
//            notread (the plan still being read), own (a server of the
//            user's own), confirming, unreadable. 390 by 844, light and
//            dark; the last two light only
//   actions  the pinned action in its three states: use, inuse, unlock
//   sizes    free and hosted at 375 by 667, 320 by 640, 1024 by 768 and
//            844 by 390, and at text scale 1.3 and 2.0 where the matrix
//            has them, the longest name ("Shades and crown") included
//   failed   the note when the platform refuses the change
//   welcome  the first visit with the icons open: the headline
//   reduce   the resting frame under reduce motion
//   taps     the locked option tapped: a locked icon picked in the
//            carousel (nothing sells), Unlock tapped (the paywall opens),
//            Unlock tapped while the plan is still being read (nothing
//            opens), Use this icon tapped with Hosted held (the icon
//            changes)
//   grow     the transition from the card to the page and back, at
//            progress 0, 0.25, 0.5, 0.75 and 1, light and dark, the page
//            reduce motion fade, and a page opened with no card
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a208)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the carousel moving, the confetti, or the grow playing.
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
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
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

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a208');
const _partsArg = String.fromEnvironment('PARTS');

/// The page name in every file.
const _page = 'icon';

/// A server of the user's own with nothing held: the icons are open, and
/// the other passes would still need Pro.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.inUse = AppIcon.standard,
    this.centre = AppIcon.crowned,
    this.welcomed = true,
    this.refuses = false,
  });

  final PassPlanState plan;

  /// The icon on the home screen when the page opens.
  final AppIcon inUse;

  /// The icon the carousel is moved to before the shot.
  final AppIcon centre;

  /// Whether the first-visit welcome has been played already.
  final bool welcomed;

  /// Whether the platform refuses to change the icon.
  final bool refuses;
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
    'app_icon.welcomed': setup.welcomed,
    ..._planPrefs(setup.plan),
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  getIt<MockServer>().seedCalm();
  await useCaptureOwnLookStore();
}

/// Lets the phone answer the icon host: which icon shows, and whether a
/// change is accepted. The icon in use follows a change, as a phone's does.
void _mockChannels(_Setup setup) {
  var showing = setup.inUse;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async {
            if (call.method == 'current') return showing.platformName;
            if (setup.refuses) throw PlatformException(code: 'refused');
            final args = call.arguments as Map<Object?, Object?>;
            showing =
                AppIcon.fromPlatformName(args['icon'] as String?) ?? showing;
            return null;
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

/// Boots the app on the Personalize root.
Future<_Run> _openRoot(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
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
            // A held clock draws the resting frame of the two moving
            // thumbnails on the root.
            child: PaywallStill(
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
  unawaited(router.push('/settings/personalize'));
  await _settle(tester);
  await tester.pump(const Duration(seconds: 1));
  return _Run(key, router);
}

/// Taps the App icon card on the root. A phone that is short or at a large
/// text size scrolls to it first.
Future<void> _tapCard(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('pass-appIcon'));
  expect(card, findsOneWidget, reason: 'no App icon card on the root');
  await tester.ensureVisible(card);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

/// Moves the carousel to [setup]'s centred icon, by dragging it one page at
/// a time, and lets it settle.
Future<void> _centre(WidgetTester tester, _Setup setup) async {
  final steps = setup.centre.index - setup.inUse.index;
  if (steps == 0) {
    await _decoded(tester);
    return;
  }
  final pages = find.byType(PageView);
  expect(pages, findsOneWidget, reason: 'no carousel on the page');
  // The carousel shows each icon in 60% of its width.
  final page = tester.getSize(pages).width * 0.6;
  for (var i = 0; i < steps.abs(); i++) {
    await tester.drag(pages, Offset(steps > 0 ? -page : page, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pump(const Duration(milliseconds: 600));
  await _decoded(tester);
}

/// Lets the pictures of the icons decode, which takes real time.
Future<void> _decoded(WidgetTester tester) async {
  await _real(tester, 500);
  await tester.pump(const Duration(milliseconds: 100));
  await _real(tester);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the page from the root, with the carousel on the icon asked for.
Future<_Run> _openPage(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
}) async {
  final run = await _openRoot(
    tester,
    setup: setup,
    device: device,
    mode: mode,
    scale: scale,
    reduceMotion: reduceMotion,
  );
  await _tapCard(tester);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await _real(tester);
  await tester.pump(const Duration(seconds: 1));
  await _centre(tester, setup);
  return run;
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
    ? {
        'icons',
        'plans',
        'actions',
        'sizes',
        'failed',
        'welcome',
        'reduce',
        'taps',
        'grow',
      }
    : _partsArg.split(',').toSet();

String _name(
  String state,
  PassDevice device,
  ThemeMode mode,
  double scale,
  String frame,
) => passFileName(
  page: _page,
  device: device,
  mode: mode,
  scale: scale,
  frame: frame,
  state: state,
);

/// Registers one capture of the page as it opens.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  PassDevice device = passPhone,
  ThemeMode mode = ThemeMode.light,
  double scale = 1,
  String frame = 'rest',
  bool reduceMotion = false,
  Future<void> Function(WidgetTester tester, _Run run)? act,
}) {
  if (!_parts.contains(part)) return;
  final name = _name(state, device, mode, scale, frame);
  if (!passWanted(name)) return;
  testWidgets('capture $name', (tester) async {
    await _guarded(name, (errors) async {
      final run = await _openPage(
        tester,
        setup: setup,
        device: device,
        mode: mode,
        scale: scale,
        reduceMotion: reduceMotion,
      );
      if (act != null) await act(tester, run);
      await _save(tester, run, name, errors);
    });
  });
}

/// Lets the welcome finish: the headline fades in and the carousel slides in
/// over 900 ms.
Future<void> _afterWelcome(WidgetTester tester, _Run run) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// Taps the pinned button by its words and lets the plan be awaited and
/// the paywall open, if it does.
Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.text(label);
  expect(button, findsOneWidget, reason: 'no button "$label"');
  await tester.tap(button);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await _real(tester, 400);
  }
  await tester.pump(const Duration(seconds: 2));
}

/// Opens the page, and calls [onFrame] with the share of the way through the
/// transition: 0, 0.25, 0.5, 0.75 and 1.
Future<void> _grow(
  WidgetTester tester,
  _Run run,
  Future<void> Function(String frame) onFrame, {
  bool back = false,
  bool reduceMotion = false,
}) async {
  const fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
  await _tapCard(tester);
  // The route is built and its clock is at zero.
  await tester.pump();
  await tester.pump();
  final openMs = reduceMotion ? 150 : 600;
  var elapsed = 0;
  for (final fraction in fractions) {
    final target = (openMs * fraction).round();
    if (target > elapsed) {
      await tester.pump(Duration(milliseconds: target - elapsed));
      elapsed = target;
    }
    await onFrame(
      'open-t${(fraction * 100).round().toString().padLeft(3, '0')}',
    );
  }
  if (!back) return;
  // Let the page settle, then take it back.
  await tester.pump(const Duration(seconds: 1));
  run.router.pop();
  await tester.pump();
  await tester.pump();
  final backMs = reduceMotion ? 150 : 520;
  elapsed = 0;
  for (final fraction in fractions) {
    final target = (backMs * fraction).round();
    if (target > elapsed) {
      await tester.pump(Duration(milliseconds: target - elapsed));
      elapsed = target;
    }
    await onFrame(
      'back-t${(fraction * 100).round().toString().padLeft(3, '0')}',
    );
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  tearDownAll(dropCaptureOwnLookStore);

  // Each icon centred, with the icons open.
  for (final icon in AppIcon.values) {
    for (final mode in passThemes) {
      _shot(
        part: 'icons',
        state: 'hosted-${icon.platformName}',
        setup: _Setup(plan: PassPlanState.hosted, centre: icon),
        mode: mode,
      );
    }
  }

  // A locked icon, in every plan state.
  for (final plan in PassPlanState.all) {
    final p = plan.name == 'own' ? _ownServer : plan;
    final isMain = const {'free', 'pro', 'hosted', 'notread', 'own'}.contains(
      p.name,
    );
    for (final mode in isMain ? passThemes : [ThemeMode.light]) {
      _shot(
        part: 'plans',
        state: p.name,
        setup: _Setup(plan: p),
        mode: mode,
      );
    }
  }

  // The three states of the pinned action.
  _shot(
    part: 'actions',
    state: 'use',
    setup: const _Setup(plan: PassPlanState.hosted),
    frame: 'action-use',
  );
  _shot(
    part: 'actions',
    state: 'inuse',
    setup: const _Setup(
      plan: PassPlanState.hosted,
      inUse: AppIcon.shades,
      centre: AppIcon.shades,
    ),
    frame: 'action-inuse',
  );
  _shot(
    part: 'actions',
    state: 'unlock',
    setup: const _Setup(),
    frame: 'action-unlock',
  );

  // The sizes and text scales. Free puts the badge and Unlock on the page,
  // Hosted the status, and the longest name sits on the narrowest ones.
  const longest = AppIcon.shadesCrown;
  final sized = <(String, _Setup)>[
    ('free', const _Setup(centre: longest)),
    (
      'hosted',
      const _Setup(
        plan: PassPlanState.hosted,
        inUse: longest,
        centre: longest,
      ),
    ),
  ];
  for (final device in passDevices) {
    for (final scale in passScalesFor(device)) {
      for (final mode in passThemes) {
        for (final (state, setup) in sized) {
          if (device == passPhone && scale == 1) continue;
          _shot(
            part: 'sizes',
            state: state,
            setup: setup,
            device: device,
            mode: mode,
            scale: scale,
          );
        }
      }
    }
  }

  // The platform refuses the change.
  for (final mode in passThemes) {
    _shot(
      part: 'failed',
      state: 'hosted-refused',
      setup: const _Setup(plan: PassPlanState.hosted, refuses: true),
      mode: mode,
      frame: 'note',
      act: (tester, run) => _tapButton(
        tester,
        'Use this icon',
      ),
    );
  }
  _shot(
    part: 'failed',
    state: 'hosted-refused',
    setup: const _Setup(plan: PassPlanState.hosted, refuses: true),
    device: passNarrowPhone,
    scale: 2,
    frame: 'note',
    act: (tester, run) => _tapButton(tester, 'Use this icon'),
  );

  // The first visit with the icons open: the headline.
  for (final mode in passThemes) {
    _shot(
      part: 'welcome',
      state: 'hosted-first-visit',
      setup: const _Setup(
        plan: PassPlanState.hosted,
        inUse: AppIcon.shades,
        centre: AppIcon.shades,
        welcomed: false,
      ),
      mode: mode,
      frame: 'headline',
      act: _afterWelcome,
    );
  }
  _shot(
    part: 'welcome',
    state: 'hosted-first-visit',
    setup: const _Setup(
      plan: PassPlanState.hosted,
      inUse: AppIcon.shades,
      centre: AppIcon.shades,
      welcomed: false,
    ),
    device: passNarrowPhone,
    scale: 2,
    frame: 'headline',
    act: _afterWelcome,
  );

  // Reduce motion: the resting frame.
  for (final mode in passThemes) {
    _shot(
      part: 'reduce',
      state: 'free',
      setup: const _Setup(),
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
    _shot(
      part: 'reduce',
      state: 'hosted-first-visit',
      setup: const _Setup(
        plan: PassPlanState.hosted,
        inUse: AppIcon.shades,
        centre: AppIcon.shades,
        welcomed: false,
      ),
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
  }

  // Taps on a locked option.
  //
  // Picking a locked icon in the carousel is a look. The page stays, no
  // paywall.
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(centre: AppIcon.standard),
    frame: 'tap-locked-icon',
    act: (tester, run) async {
      // The Crowned tile sits right of the centred Default one.
      // Only its left edge is on the display, so the tap lands there.
      final tiles = find.byType(TiltShowcase);
      expect(tiles, findsWidgets);
      await tester.tapAt(
        Offset(
          passPhone.size.width - 24,
          tester.getCenter(tiles.first).dy,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
  // Unlock is the act of keeping it: the Hosted paywall opens.
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(),
    frame: 'tap-unlock',
    act: (tester, run) => _tapButton(tester, 'Unlock'),
  );
  // Unlock before the plan is read waits, and opens nothing.
  _shot(
    part: 'taps',
    state: 'notread',
    setup: const _Setup(plan: PassPlanState.notRead),
    frame: 'tap-unlock',
    act: (tester, run) => _tapButton(tester, 'Unlock'),
  );
  // Use this icon with Hosted held changes the icon: the status shows.
  _shot(
    part: 'taps',
    state: 'hosted',
    setup: const _Setup(plan: PassPlanState.hosted),
    frame: 'tap-use',
    act: (tester, run) => _tapButton(tester, 'Use this icon'),
  );

  // The grow, open and back, from the real route.
  for (final mode in passThemes) {
    for (final plan in const [PassPlanState.free, PassPlanState.hosted]) {
      if (plan == PassPlanState.hosted && mode == ThemeMode.dark) continue;
      final base = _name(plan.name, passPhone, mode, 1, 'x');
      if (!_parts.contains('grow') || !passWanted(base)) continue;
      testWidgets('capture grow ${plan.name} ${mode.name}', (tester) async {
        await _guarded(base, (errors) async {
          final run = await _openRoot(
            tester,
            setup: _Setup(
              plan: plan,
              inUse: plan == PassPlanState.hosted
                  ? AppIcon.crowned
                  : AppIcon.standard,
            ),
            device: passPhone,
            mode: mode,
            scale: 1,
          );
          await _grow(tester, run, back: true, (frame) async {
            await _save(
              tester,
              run,
              _name(plan.name, passPhone, mode, 1, 'grow-$frame'),
              errors,
            );
          });
        });
      });
    }
  }

  // A page opened with no card, and the reduce motion fade.
  for (final mode in passThemes) {
    final name = _name('free', passPhone, mode, 1, 'deeplink');
    if (!_parts.contains('grow') || !passWanted(name)) continue;
    testWidgets('capture $name', (tester) async {
      await _guarded(name, (errors) async {
        final run = await _openRoot(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: mode,
          scale: 1,
        );
        run.router.go('/app-icon');
        await _settle(tester);
        await _save(tester, run, name, errors);
      });
    });
  }
  final reduceName = _name(
    'free',
    passPhone,
    ThemeMode.light,
    1,
    'grow-reduce',
  );
  if (_parts.contains('grow') && passWanted(reduceName)) {
    testWidgets('capture grow reduce', (tester) async {
      await _guarded(reduceName, (errors) async {
        final run = await _openRoot(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: ThemeMode.light,
          scale: 1,
          reduceMotion: true,
        );
        await _grow(tester, run, reduceMotion: true, (frame) async {
          if (!const ['open-t000', 'open-t050', 'open-t100'].contains(frame)) {
            return;
          }
          await _save(
            tester,
            run,
            _name('free', passPhone, ThemeMode.light, 1, 'grow-reduce-$frame'),
            errors,
          );
        });
      });
    });
  }
}
