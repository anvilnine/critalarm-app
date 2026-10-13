// Captures the use step of setup ("What should wake you?") off the device,
// through the real router and the real setup shell on the mock server, with
// a made-up setup and no network.
//
//   fvm flutter test tool/capture_use_step.dart
//
// Every file is <scene>_<phone>_<theme>_<scale>x[_reduced].png, for two
// phones (390 wide, 320 wide), light and dark, and text scale 1.0, 1.3 and
// 2.0. The path of every file is printed, and a capture fails when anything
// overflows or throws.
//
// Scenes that rest:
//   use_first_open     the step opened from the permissions, nothing picked
//   use_scrolled_to_end  the same, dragged to the end of the column
//   use_picked_row     a row tapped: its picked look, as the step moves on
//   use_came_back      Back from the first topic: the saved answer picked
//   use_replay         a replay (?demo=true): nothing saved, nothing picked
//   first_topic_rest   the step after, once it has settled
//
// Scenes that move. Each first frame also has a _plus16 file, the frame 16 ms
// after it:
//   use_enter_first_frame      the first frame after the push from the
//                              permissions
//   use_enter_mid              part way through the slide into the step
//   use_exit_mid               part way through the slide out to the next one
//   first_topic_first_frame    the first frame of the step after
//   first_topic_enter_mid      part way through the slide into it
//   use_came_back_first_frame  the first frame after Back
//   use_came_back_enter_mid    part way through the slide back in
//
// Under reduced motion nothing slides, so the scenes that move write only
// their first frame, which is already the settled one. Two more files show
// the shell's "Connecting" line taking the corner skip sits in
// (use_corner_line): skip is not there to tap, and the rows still answer.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only configurations whose name has a part
//
// A capture is a still of one moment: it shows nothing moving.
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
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
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

/// A made-up setup: a pinned run on 2026-10-c that has finished the welcome
/// and connect, with a server saved so the first topic shows its own screen.
Map<String, Object> _prefsFor({List<String> completed = const []}) => {
  'onboarding_flow_id': BundledOnboardingFlows.october2026C.id,
  'onboarding_flow_steps': BundledOnboardingFlows.october2026C.steps,
  'onboarding_flow_completed': ['welcome', 'connect', ...completed],
  // A made-up server and key. Nothing is contacted.
  'server_url': 'https://api.critalarm.app',
  'admin_token': 'demo',
};

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

/// One configuration of the matrix.
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

class _Run {
  _Run(this.key, this.router, this.errors);

  final GlobalKey key;
  final GoRouter router;
  final List<String> errors;

  Uri get location => router.routerDelegate.currentConfiguration.uri;
}

Future<void> _real(WidgetTester tester, [int ms = 20]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<_Run> _open(
  WidgetTester tester,
  _Config config, {
  required Map<String, Object> prefs,
  required List<String> errors,
}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(prefs);
    await getIt.reset();
    await configureDependencies(useMockApi: true);
    // No notification plugin runs in a test, so the permissions answer from
    // here: nothing asked yet.
    await getIt.unregister<NotificationPermissionRepository>();
    getIt.registerLazySingleton<NotificationPermissionRepository>(
      _NothingAskedYet.new,
    );
  });
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
        // The cubits the app provides above its router, which the first topic
        // reads.
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

/// Opens the permissions step as a setup run does: the engine has put the
/// user on it, so Back has somewhere to go from the steps after.
Future<void> _startOnPermissions(WidgetTester tester, _Run run) async {
  await tester.runAsync(
    () => getIt<OnboardingFlowEngine>().resume(),
  );
  run.router.go('/onboarding');
  await _settle(tester);
}

/// Pumps frames of the given length, with real time between them for the
/// saves and reads the screens wait on.
Future<void> _settle(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await _real(tester, 8);
  }
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

/// Scrolls [target] to the middle of the screen, clear of the bars, as a
/// finger would before tapping a row that is off the page.
Future<void> _scrollToMiddle(WidgetTester tester, Finder target) async {
  unawaited(
    Scrollable.ensureVisible(tester.element(target), alignment: 0.5),
  );
  await _settle(tester, frames: 3);
}

/// How far the shell's slide has carried the step, as a share of the width:
/// 0 at rest.
double _shift(WidgetTester tester) {
  var most = 0.0;
  for (final box in tester.widgetList<FractionalTranslation>(
    find.byType(FractionalTranslation),
  )) {
    if (box.translation.dx.abs() > most) most = box.translation.dx.abs();
  }
  return most;
}

/// Runs one step change started by [start], writing the named frames:
/// [exitMid] while the old step slides out, [firstFrame] on the first frame
/// of the new route and the frame 16 ms after it, and [enterMid] part way
/// through the slide in. Returns once the new step has settled.
///
/// With reduce motion only [firstFrame] is written, since nothing slides.
/// With no [name] nothing is written and the change only runs.
Future<void> _change(
  WidgetTester tester,
  _Run run,
  _Config config, {
  required Future<void> Function() start,
  required String fromPath,
  String Function(String scene)? name,
  String? exitMid,
  String? firstFrame,
  String? enterMid,
}) async {
  Future<void> write(String? scene) async {
    if (name == null || scene == null) return;
    await _save(tester, run, name(scene));
  }

  await start();
  var exitSaved = exitMid == null || config.reduce;
  for (var i = 0; i < 80 && run.location.path == fromPath; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await _real(tester, 8);
    if (!exitSaved && run.location.path == fromPath && _shift(tester) > 0.03) {
      exitSaved = true;
      await write(exitMid);
    }
  }
  expect(run.location.path, isNot(fromPath), reason: 'the step moved on');
  // The first frame of the new route, as the shell draws it.
  await tester.pump();
  await write(firstFrame);
  if (!config.reduce) {
    await tester.pump(const Duration(milliseconds: 16));
    await write(firstFrame == null ? null : '${firstFrame}_plus16');
    var enterSaved = enterMid == null;
    for (var i = 0; i < 40 && !enterSaved; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_shift(tester) > 0 && _shift(tester) < 0.07) {
        enterSaved = true;
        await write(enterMid);
      }
    }
  }
  await _settle(tester);
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

void _configuration(_Config config) {
  if (_only.isNotEmpty && !_only.split(',').any(config.name.contains)) return;

  // <scene>_<phone>_<theme>_<scale>x[_reduced]
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';

  testWidgets('capture use step ${config.name}', (tester) async {
    final errors = <String>[];
    await _guarded(config.name, errors, () async {
      // 1. Into the step from the permissions, then rest.
      var run = await _open(tester, config, prefs: _prefsFor(), errors: errors);
      await _startOnPermissions(tester, run);
      await _change(
        tester,
        run,
        config,
        start: () async => unawaited(
          finishOnboardingStepOn(run.router, 'permissions', isReplay: false),
        ),
        fromPath: '/onboarding',
        name: name,
        firstFrame: 'use_enter_first_frame',
        enterMid: 'use_enter_mid',
      );
      expect(run.location.path, '/onboarding/use');
      await _save(tester, run, name('use_first_open'));

      // The end of the column, for a text size that does not fit.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -3000),
      );
      await _settle(tester, frames: 6);
      await _save(tester, run, name('use_scrolled_to_end'));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 3000),
      );
      await _settle(tester, frames: 6);

      // 2. A tap on a row: the picked look, the slide out, the next step.
      final homelab = find.text('My homelab');
      expect(homelab, findsOneWidget);
      await _scrollToMiddle(tester, homelab);
      await _change(
        tester,
        run,
        config,
        start: () async {
          await tester.tap(homelab);
          await tester.pump();
          await _save(tester, run, name('use_picked_row'));
        },
        fromPath: '/onboarding/use',
        name: name,
        exitMid: 'use_exit_mid',
        firstFrame: 'first_topic_first_frame',
        enterMid: 'first_topic_enter_mid',
      );
      expect(run.location.path, '/onboarding/first-topic');
      expect(
        getIt<SetupUseStore>().read(),
        SetupUse.homelab,
        reason: 'a tap saves the answer',
      );
      expect(
        await tester.runAsync(
          () async => (await SharedPreferences.getInstance()).getString(
            OnboardingFunnel.bufferKey,
          ),
        ),
        allOf(contains('"use":"homelab"'), contains('2026-10-c')),
        reason: 'a tap buffers the pick event',
      );
      await _save(tester, run, name('first_topic_rest'));

      // 3. Back from the first topic: the saved row is picked.
      await _change(
        tester,
        run,
        config,
        start: () async => unawaited(
          goBackInOnboarding(run.router, 'first_topic', isReplay: false),
        ),
        fromPath: '/onboarding/first-topic',
        name: name,
        firstFrame: 'use_came_back_first_frame',
        enterMid: 'use_came_back_enter_mid',
      );
      expect(run.location.path, '/onboarding/use');
      expect(run.location.queryParameters['back'], 'true');
      await _save(tester, run, name('use_came_back'));

      // A tap on the picked row moves on again.
      final again = find.text('My homelab');
      await _scrollToMiddle(tester, again);
      await _change(
        tester,
        run,
        config,
        start: () => tester.tap(again),
        fromPath: '/onboarding/use',
      );
      expect(run.location.path, '/onboarding/first-topic');

      // 4. A replay saves nothing and sends nothing.
      run = await _open(tester, config, prefs: _prefsFor(), errors: errors);
      run.router.go('/onboarding/use?demo=true');
      await _settle(tester);
      await _save(tester, run, name('use_replay'));
      final servers = find.text('My servers and apps');
      await _scrollToMiddle(tester, servers);
      await tester.tap(servers);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await _real(tester, 8);
      }
      expect(getIt<SetupUseStore>().read(), isNull, reason: 'a replay saves');
      expect(getIt<SetupUseReplay>().pick, SetupUse.servers);
      expect(
        await tester.runAsync(
          () async => (await SharedPreferences.getInstance()).getString(
            OnboardingFunnel.bufferKey,
          ),
        ),
        isNull,
        reason: 'a replay sends no event',
      );
    });
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  testWidgets('skip answers Something else and sends skipped', (tester) async {
    final errors = <String>[];
    const config = _Config(
      _Phone('390', Size(390, 844), 47, 34),
      ThemeMode.light,
      1,
      reduce: true,
    );
    await _guarded('skip', errors, () async {
      final run = await _open(
        tester,
        config,
        prefs: _prefsFor(),
        errors: errors,
      );
      await _startOnPermissions(tester, run);
      run.router.go('/onboarding/use');
      await _settle(tester);
      await _change(
        tester,
        run,
        config,
        start: () async {
          await tester.tap(find.text('SKIP'));
        },
        fromPath: '/onboarding/use',
      );
      expect(getIt<SetupUseStore>().read(), SetupUse.other);
      expect(
        await tester.runAsync(
          () async => (await SharedPreferences.getInstance()).getString(
            OnboardingFunnel.bufferKey,
          ),
        ),
        contains('"use":"skipped"'),
      );
    });
  });

  // The shell's short line about a connect running behind the user takes the
  // corner skip sits in. Skip gives it up and the rows still answer.
  for (final config in [
    _Config(_phones[0], ThemeMode.light, 1, reduce: false),
    _Config(_phones[1], ThemeMode.dark, 1.3, reduce: false),
  ]) {
    testWidgets('corner line ${config.name}', (tester) async {
      final errors = <String>[];
      await _guarded('corner ${config.name}', errors, () async {
        // No saved server, so the connect is the one pending.
        final prefs = _prefsFor()
          ..remove('server_url')
          ..remove('admin_token');
        final run = await _open(tester, config, prefs: prefs, errors: errors);
        await _startOnPermissions(tester, run);
        run.router.go('/onboarding/use');
        await _settle(tester);
        await tester.runAsync(
          () => getIt<BackgroundConnect>().start('https://api.critalarm.app'),
        );
        await _settle(tester, frames: 8);
        await _save(
          tester,
          run,
          'use_corner_line_${config.phone.name}_${config.mode.name}_'
          '${config.scale.toStringAsFixed(1)}x',
        );
        // The corner is taken, so skip is not there to tap.
        expect(find.text('SKIP').hitTestable(), findsNothing);
      });
    });
  }

  for (final phone in _phones) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in _scales) {
        for (final reduce in [false, true]) {
          _configuration(_Config(phone, mode, scale, reduce: reduce));
        }
      }
    }
  }
}
