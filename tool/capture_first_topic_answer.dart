// Captures the first topic of setup ("Your first topic") off the device, for
// each answer of the question step before it, through the real router and the
// real setup shell on the mock server, with a made-up setup and no network.
//
//   fvm flutter test tool/capture_first_topic_answer.dart
//
// Every file is <scene>_<phone>_<theme>_<scale>x[_reduced].png, for two
// phones (390 wide, 320 wide), light and dark, and text scale 1.0, 1.3 and
// 2.0. The path of every file is printed, and a capture fails when anything
// overflows or throws.
//
// Scenes that rest, one per answer, reached by tapping that answer's row:
//   first_servers, first_homelab, first_jobs, first_home, first_other
//
// More scenes, on the servers answer:
//   first_servers_page_end     the page dragged to its end: the form clear of
//                              the pinned button and the links under it
//   first_servers_chips_end    both chip lines dragged to their ends
//   first_tool_tapped          Uptime Kuma tapped: the name it filled
//                              replaces the one the answer filled
//   first_name_chip_tapped     a name chip tapped: it replaces the name
//   first_typed_then_tool      a name typed, then a tool tapped: the typed
//                              name stays
//   first_keyboard_open        the keyboard up
//
// And:
//   first_name_taken           a replay on the servers answer, with a topic
//                              called prod-db already held
//   first_after_back           Back to the question and a different answer:
//                              the step is rebuilt and refills
//   first_replay               a replay: the replay's pick, nothing made
//   first_new_topic_route      /topics/new?tool=cron, which keeps its
//                              wrapping chips above the name
//
// Scenes that move. Each first frame also has a _plus16 file, the frame 16 ms
// after it:
//   first_<answer>_first_frame   the first frame after the push from the
//                                question
//   first_<answer>_enter_mid     part way through the slide into the step
//   first_servers_exit_mid       part way through the slide out, after Create
//   first_after_back_first_frame the first frame after Back and forward again
//
// Under reduced motion nothing slides, so the scenes that move write only
// their first frame, which is already the settled one.
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
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
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
    // The user has no topic yet: a server with nothing on it, so the list
    // loads empty. A scene that needs a topic makes it.
    await getIt.unregister<MockServer>();
    getIt.registerLazySingleton<MockServer>(MockServer.new);
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

/// One answer of the question step: the word its scenes are named for, the
/// title of its row, and the name it fills.
class _Answer {
  const _Answer(this.scene, this.title, this.use, this.name);

  final String scene;
  final String title;
  final SetupUse use;
  final String name;
}

const _answers = [
  _Answer('servers', 'My servers and apps', SetupUse.servers, 'prod-db'),
  _Answer('homelab', 'My homelab', SetupUse.homelab, 'uptime-kuma'),
  _Answer('jobs', 'Builds and scheduled jobs', SetupUse.jobs, 'nightly-backup'),
  _Answer('home', 'My home', SetupUse.home, 'home-assistant'),
  _Answer('other', 'Something else', SetupUse.other, ''),
];

/// Opens a fresh run on the question step, the way a setup run gets there.
Future<_Run> _openOnUse(
  WidgetTester tester,
  _Config config,
  List<String> errors,
) async {
  final run = await _open(tester, config, prefs: _prefsFor(), errors: errors);
  await _startOnPermissions(tester, run);
  await _change(
    tester,
    run,
    config,
    start: () async => unawaited(
      finishOnboardingStepOn(run.router, 'permissions', isReplay: false),
    ),
    fromPath: '/onboarding',
  );
  expect(run.location.path, '/onboarding/use');
  return run;
}

/// Taps the row for [answer] and waits for the first topic. With a [scene]
/// the first frame, the frame after it and the slide in are written.
Future<void> _pick(
  WidgetTester tester,
  _Run run,
  _Config config,
  _Answer answer, {
  String Function(String scene)? name,
  String? scene,
}) async {
  final row = find.text(answer.title);
  expect(row, findsOneWidget);
  await _scrollToMiddle(tester, row);
  await _change(
    tester,
    run,
    config,
    start: () => tester.tap(row),
    fromPath: '/onboarding/use',
    name: name,
    firstFrame: scene == null ? null : '${scene}_first_frame',
    enterMid: scene == null ? null : '${scene}_enter_mid',
  );
  expect(run.location.path, '/onboarding/first-topic');
}

/// What the name field holds.
String _nameText(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .first
    .controller
    .text;

/// The line of chips that holds the chip called [chip].
Finder _lineOf(String chip) => find
    .ancestor(of: find.text(chip), matching: find.byType(SingleChildScrollView))
    .first;

/// Taps the chip called [chip], after bringing it to the middle of the page
/// and of its line, as a finger would.
Future<void> _tapChip(WidgetTester tester, String chip) async {
  final target = find.text(chip);
  expect(target, findsOneWidget, reason: 'one chip called $chip');
  await _scrollToMiddle(tester, target);
  await tester.tap(target);
  await _settle(tester, frames: 4);
}

/// A made-up replay, with the answer the replay picked.
Future<_Run> _openReplay(
  WidgetTester tester,
  _Config config,
  List<String> errors,
  _Answer answer, {
  List<String> owned = const [],
}) async {
  final run = await _open(tester, config, prefs: _prefsFor(), errors: errors);
  for (final topic in owned) {
    await tester.runAsync(() async {
      await getIt<CreateTopicUsecase>()(CreateTopicParams(name: topic));
      await getIt<TopicsCubit>().refresh();
    });
  }
  run.router.go('/onboarding/use?demo=true');
  await _settle(tester);
  final row = find.text(answer.title);
  await _scrollToMiddle(tester, row);
  await tester.tap(row);
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await _real(tester, 8);
  }
  await _settle(tester);
  expect(run.location.path, '/onboarding/first-topic');
  expect(run.location.queryParameters['demo'], 'true');
  expect(getIt<SetupUseStore>().read(), isNull, reason: 'a replay saves');
  return run;
}

void _configuration(_Config config) {
  if (_only.isNotEmpty && !_only.split(',').any(config.name.contains)) return;

  // <scene>_<phone>_<theme>_<scale>x[_reduced]
  String name(String scene) =>
      '${scene}_${config.phone.name}_${config.mode.name}_'
      '${config.scale.toStringAsFixed(1)}x${config.reduce ? '_reduced' : ''}';

  // The keyboard's height on this phone.
  final keyboard = config.phone.size.width < 340 ? 260.0 : 300.0;

  // Each answer on its own run, so nothing one scene did is left in the next.
  for (final answer in _answers) {
    testWidgets('capture first topic ${answer.scene} ${config.name}', (
      tester,
    ) async {
      final errors = <String>[];
      await _guarded('${answer.scene} ${config.name}', errors, () async {
        final run = await _openOnUse(tester, config, errors);
        await _pick(
          tester,
          run,
          config,
          answer,
          name: name,
          scene: 'first_${answer.scene}',
        );
        expect(getIt<SetupUseStore>().read(), answer.use);
        expect(
          _nameText(tester),
          answer.name,
          reason: 'the field arrives with the answer',
        );
        await _save(tester, run, name('first_${answer.scene}'));

        // Something else shows no names to pick from.
        expect(
          find.text('or'),
          answer.use == SetupUse.other ? findsNothing : findsOneWidget,
        );
        expect(find.text('What sends it'), findsOneWidget);

        if (answer.use != SetupUse.servers) return;

        // The page dragged to its end: the form clear of the pinned button.
        final page = find.byType(CustomScrollView).first;
        await tester.drag(page, const Offset(0, -3000));
        await _settle(tester, frames: 6);
        await _save(tester, run, name('first_servers_page_end'));
        await tester.drag(page, const Offset(0, 3000));
        await _settle(tester, frames: 6);

        // Both lines of chips dragged to their ends.
        await _scrollToMiddle(tester, find.text('What sends it'));
        await tester.drag(
          _lineOf('curl'),
          const Offset(-3000, 0),
          warnIfMissed: false,
        );
        await tester.drag(
          _lineOf('prod-api'),
          const Offset(-3000, 0),
          warnIfMissed: false,
        );
        await _settle(tester, frames: 6);
        await _save(tester, run, name('first_servers_chips_end'));
        await tester.drag(
          _lineOf('curl'),
          const Offset(3000, 0),
          warnIfMissed: false,
        );
        await tester.drag(
          _lineOf('prod-api'),
          const Offset(3000, 0),
          warnIfMissed: false,
        );
        await _settle(tester, frames: 6);

        // A tool tapped: its name replaces the one the answer filled.
        await _tapChip(tester, 'Uptime Kuma');
        expect(_nameText(tester), 'uptime-kuma');
        await _save(tester, run, name('first_tool_tapped'));

        // A name chip tapped: it replaces the name.
        await _tapChip(tester, 'prod-api');
        expect(_nameText(tester), 'prod-api');
        await _save(tester, run, name('first_name_chip_tapped'));

        // A name typed, then a tool tapped: the typed name stays.
        await tester.enterText(find.byType(EditableText).first, 'x-db');
        await tester.pump();
        await _tapChip(tester, 'Healthchecks');
        expect(_nameText(tester), 'x-db');
        await _save(tester, run, name('first_typed_then_tool'));

        // The keyboard up.
        await tester.tap(find.byType(EditableText).first);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
        await _settle(tester);
        await _save(tester, run, name('first_keyboard_open'));
        tester.view.viewInsets = FakeViewPadding.zero;
        await _settle(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await _settle(tester, frames: 4);

        // Back to the question and a different answer: the step is rebuilt
        // and refills from it, and what was typed is gone.
        await _change(
          tester,
          run,
          config,
          start: () async => unawaited(
            goBackInOnboarding(run.router, 'first_topic', isReplay: false),
          ),
          fromPath: '/onboarding/first-topic',
        );
        expect(run.location.path, '/onboarding/use');
        await _pick(
          tester,
          run,
          config,
          _answers[1],
          name: name,
          scene: 'first_after_back',
        );
        expect(_nameText(tester), 'uptime-kuma');
        await _save(tester, run, name('first_after_back'));

        // Create: the slide out of the step.
        await _change(
          tester,
          run,
          config,
          start: () async {
            await tester.tap(find.text('Create topic'));
            await _settle(tester, frames: 8);
            // A tap anywhere moves on from the picture of Home.
            await tester.tapAt(tester.getCenter(find.byType(Scaffold).first));
          },
          fromPath: '/onboarding/first-topic',
          name: name,
          exitMid: 'first_exit_mid',
        );
      });
    });
  }

  testWidgets('capture first topic replay ${config.name}', (tester) async {
    final errors = <String>[];
    await _guarded('replay ${config.name}', errors, () async {
      final run = await _openReplay(tester, config, errors, _answers[3]);
      expect(_nameText(tester), 'home-assistant');
      await _save(tester, run, name('first_replay'));
    });
  });

  testWidgets('capture first topic name taken ${config.name}', (tester) async {
    final errors = <String>[];
    await _guarded('name taken ${config.name}', errors, () async {
      final run = await _openReplay(
        tester,
        config,
        errors,
        _answers[0],
        owned: const ['prod-db'],
      );
      expect(_nameText(tester), 'prod-db');
      expect(find.text('A topic with that name already exists.'), findsAny);
      await _save(tester, run, name('first_name_taken'));
    });
  });

  testWidgets('capture first topic route ${config.name}', (tester) async {
    final errors = <String>[];
    await _guarded('route ${config.name}', errors, () async {
      final run = await _open(
        tester,
        config,
        prefs: _prefsFor(),
        errors: errors,
      );
      // The route that opens outside setup, with a tool from its address.
      // Not a setup step: no answer is read, and the chips wrap above the
      // name as they always did.
      run.router.go('/topics/new?tool=cron');
      await _settle(tester);
      expect(run.location.path, '/topics/new');
      await _save(tester, run, name('first_new_topic_route'));
    });
  });
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
          _configuration(_Config(phone, mode, scale, reduce: reduce));
        }
      }
    }
  }
}
