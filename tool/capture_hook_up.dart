// Captures the hook-up step off the device, through the real router and the
// real onboarding shell on the mock server, as a replay with made-up values.
//
//   fvm flutter test tool/capture_hook_up.dart --dart-define=SKIP_PAYWALL=true
//
// SKIP_PAYWALL turns on the developer parameters the scenes use
// (`?tool=<id>`, `?use=<wire id>`, `?show=<state>`).
//
// It writes a PNG named <scene>_<phone>_<theme>_<scale>x[_reduced].png for
// every row of the list below, then one contact sheet per scene. The path of
// every file is printed.
//
// Scenes:
//   hook_kuma, hook_healthchecks, hook_home_assistant   the steps layout
//   hook_kuma_curl_open     the curl chip tapped, curl line open
//   hook_kuma_copied_url    Copy URL tapped
//   hook_kuma_copied_token  Copy token tapped
//   hook_curl_servers       today's screen, curl first
//   hook_curl_jobs          today's screen with the note for a job
//   hook_cron               today's screen with a pasted snippet
//   hook_arrived            the first message landed
//   hook_replay             a replay opened with no tool and no answer
//
// A scene may carry a suffix:
//   _push1   the first frame after the screen is pushed
//   _mid     a frame part way through the change the scene names
//   _end     scrolled to the foot
//
// Phones: 390 (390 x 844), 320 (320 x 640) and 320tall (320 x 2600, the whole
// page at once).
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows. A capture is a still of one
// moment: it does not show anything moving.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

class _Phone {
  const _Phone(this.name, this.size, {required this.top, this.bottom = 0});

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _p390 = _Phone('390', Size(390, 844), top: 47, bottom: 34);
const _p320 = _Phone('320', Size(320, 640), top: 24);
const _p320tall = _Phone('320tall', Size(320, 2600), top: 24);

const _kuma = 'tool=uptime_kuma&use=homelab';
const _healthchecks = 'tool=healthchecks&use=jobs';
const _homeAssistant = 'tool=home_assistant&use=home';

class _Scene {
  const _Scene(this.name, this.query, {this.run, this.firstMs});

  final String name;

  /// The query after `?demo=true`.
  final String query;

  /// Drives the open screen to the state to capture. Runs after it settled.
  final Future<void> Function(WidgetTester tester)? run;

  /// Capture a frame this many milliseconds after the push, before anything
  /// settled. 0 is the very first frame.
  final int? firstMs;
}

Future<void> _frames(WidgetTester tester, int count, [int ms = 100]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Scrolls the first widget showing [text] to [alignment] of the viewport
/// (0 is the top edge).
Future<void> _reveal(
  WidgetTester tester,
  String text, {
  double alignment = 0.25,
}) async {
  await Scrollable.ensureVisible(
    tester.element(find.text(text).first),
    alignment: alignment,
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await _reveal(tester, text);
  await tester.tap(find.text(text).first);
  await tester.pump();
}

HookUpCubit _cubit(WidgetTester tester) => BlocProvider.of<HookUpCubit>(
  tester.element(find.byType(AppScreenScaffold)),
);

Future<void> _toFoot(WidgetTester tester) async {
  await tester.fling(
    find.byType(CustomScrollView).first,
    const Offset(0, -4000),
    4000,
  );
  await _frames(tester, 12);
}

final _scenes = <String, _Scene>{
  for (final scene in [
    const _Scene('hook_kuma', _kuma),
    const _Scene('hook_healthchecks', _healthchecks),
    const _Scene('hook_home_assistant', _homeAssistant),
    _Scene(
      'hook_kuma_curl_open',
      _kuma,
      run: (tester) async {
        await _tap(tester, 'curl');
        await _frames(tester, 6);
        await _reveal(tester, 'Copy URL', alignment: 0.05);
      },
    ),
    _Scene(
      'hook_kuma_curl_mid',
      _kuma,
      run: (tester) async {
        await _tap(tester, 'curl');
        await tester.pump(const Duration(milliseconds: 90));
      },
    ),
    _Scene(
      'hook_kuma_curl_closing_mid',
      _kuma,
      run: (tester) async {
        await _tap(tester, 'curl');
        await _frames(tester, 6);
        await _tap(tester, 'curl');
        await tester.pump(const Duration(milliseconds: 90));
      },
    ),
    _Scene(
      'hook_kuma_copied_url',
      _kuma,
      run: (tester) async {
        await _tap(tester, 'Copy URL');
        await _frames(tester, 4);
      },
    ),
    _Scene(
      'hook_kuma_copied_token',
      _kuma,
      run: (tester) async {
        await _tap(tester, 'Copy token');
        await _frames(tester, 4);
      },
    ),
    const _Scene('hook_curl_servers', 'tool=curl&use=servers'),
    const _Scene('hook_curl_jobs', 'tool=curl&use=jobs'),
    const _Scene('hook_cron', 'tool=cron&use=servers'),
    const _Scene('hook_arrived', '$_kuma&show=arrived'),
    _Scene(
      'hook_arrived_mid',
      _kuma,
      run: (tester) async {
        _cubit(tester).showForReplay(isFirstMessageReceived: true);
        await tester.pump(const Duration(milliseconds: 110));
      },
    ),
    const _Scene('hook_curl_arrived', 'tool=curl&use=servers&show=arrived'),
    const _Scene('hook_replay', ''),
    const _Scene('hook_kuma_push1', _kuma, firstMs: 0),
    const _Scene('hook_kuma_push2', _kuma, firstMs: 80),
    const _Scene('hook_kuma_push3', _kuma, firstMs: 160),
    const _Scene('hook_home_assistant_push1', _homeAssistant, firstMs: 0),
    const _Scene('hook_home_assistant_push2', _homeAssistant, firstMs: 80),
    const _Scene('hook_home_assistant_push3', _homeAssistant, firstMs: 160),
    const _Scene(
      'hook_curl_servers_push1',
      'tool=curl&use=servers',
      firstMs: 0,
    ),
    const _Scene(
      'hook_curl_servers_push2',
      'tool=curl&use=servers',
      firstMs: 80,
    ),
    const _Scene(
      'hook_curl_servers_push3',
      'tool=curl&use=servers',
      firstMs: 160,
    ),
  ])
    scene.name: scene,
  'hook_kuma_end': const _Scene('hook_kuma_end', _kuma, run: _toFoot),
  'hook_home_assistant_end': const _Scene(
    'hook_home_assistant_end',
    _homeAssistant,
    run: _toFoot,
  ),
  'hook_curl_servers_end': const _Scene(
    'hook_curl_servers_end',
    'tool=curl&use=servers',
    run: _toFoot,
  ),
};

/// One file to write.
class _Shot {
  const _Shot(
    this.scene,
    this.phone,
    this.mode,
    this.scale, {
    this.isReduced = false,
  });

  final String scene;
  final _Phone phone;
  final ThemeMode mode;
  final double scale;
  final bool isReduced;

  String get name =>
      '${scene}_${phone.name}_${mode.name}_${scale}x'
      '${isReduced ? '_reduced' : ''}';
}

List<_Shot> _list() {
  const light = ThemeMode.light;
  const dark = ThemeMode.dark;
  final shots = <_Shot>[];
  void add(
    List<String> scenes,
    List<_Phone> phones,
    List<ThemeMode> modes,
    List<double> scales, {
    bool isReduced = false,
  }) {
    for (final scene in scenes) {
      for (final phone in phones) {
        for (final mode in modes) {
          for (final scale in scales) {
            shots.add(_Shot(scene, phone, mode, scale, isReduced: isReduced));
          }
        }
      }
    }
  }

  // The three tools and today's curl screen: everything.
  add(
    ['hook_kuma', 'hook_healthchecks', 'hook_home_assistant'],
    [_p320, _p320tall, _p390],
    [light, dark],
    [1, 1.3, 2],
  );
  add(
    ['hook_curl_servers'],
    [_p320, _p320tall, _p390],
    [light, dark],
    [
      1,
      1.3,
      2,
    ],
  );
  add(
    ['hook_curl_jobs', 'hook_cron', 'hook_replay'],
    [_p320, _p390],
    [
      light,
      dark,
    ],
    [1, 2],
  );
  add(['hook_curl_jobs'], [_p320tall], [light], [1.3]);
  // Curl opened, copy states, the first message.
  add(
    ['hook_kuma_curl_open'],
    [_p320, _p320tall, _p390],
    [light, dark],
    [
      1,
      1.3,
      2,
    ],
  );
  add(
    ['hook_kuma_copied_url', 'hook_kuma_copied_token'],
    [_p320, _p390],
    [
      light,
      dark,
    ],
    [1, 1.3],
  );
  add(
    ['hook_arrived', 'hook_curl_arrived'],
    [_p320, _p390],
    [light, dark],
    [
      1,
      1.3,
      2,
    ],
  );
  // The foot of the page, under the pinned bar.
  add(
    ['hook_kuma_end', 'hook_home_assistant_end', 'hook_curl_servers_end'],
    [_p320],
    [light, dark],
    [1, 1.3, 2],
  );
  // Part way through a change, and the first frame after the push.
  add(
    ['hook_kuma_curl_mid', 'hook_kuma_curl_closing_mid', 'hook_arrived_mid'],
    [_p320, _p390],
    [light, dark],
    [1, 2],
  );
  add(
    [
      for (final scene in [
        'hook_kuma',
        'hook_home_assistant',
        'hook_curl_servers',
      ])
        for (final n in [1, 2, 3]) '${scene}_push$n',
    ],
    [_p320, _p390],
    [light, dark],
    [1, 2],
  );
  // Reduced motion: the settled frame, no blink, no tween.
  add(
    [
      'hook_kuma',
      'hook_home_assistant',
      'hook_kuma_curl_open',
      'hook_curl_servers',
      'hook_arrived',
    ],
    [_p320, _p390],
    [light, dark],
    [1, 2],
    isReduced: true,
  );
  return shots;
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final shot in _list()) {
    if (!_wanted(shot.name)) continue;
    testWidgets('capture ${shot.name}', (tester) async {
      final scene = _scenes[shot.scene]!;
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        // Reduce motion gives an AnimatedSize a zero duration, which marks
        // itself dirty while it lays out when its child changes size. A
        // debug build only.
        if (text.contains('RenderAnimatedSize was mutated in its own')) {
          return;
        }
        errors.add(details.toString());
      };
      debugDisableShadows = false;
      try {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          await getIt.reset();
          await configureDependencies(useMockApi: true);
          getIt<MockServer>().seedCalm();
        });
        const dpr = 2.0;
        tester.view.physicalSize = shot.phone.size * dpr;
        tester.view.devicePixelRatio = dpr;
        tester.view.padding = FakeViewPadding(
          top: shot.phone.top * dpr,
          bottom: shot.phone.bottom * dpr,
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
              builder: (context) => BlocProvider<ThemeCubit>.value(
                value: getIt<ThemeCubit>(),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: shot.mode,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(shot.scale),
                      disableAnimations: shot.isReduced,
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
        await _real(tester);
        // The step before, so the push has something to come from.
        router.go('/onboarding/connect');
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await _real(tester, 20);
        }

        final query = scene.query.isEmpty ? '' : '&${scene.query}';
        router.go('/onboarding/hook-up?demo=true$query');
        if (scene.firstMs case final ms?) {
          // A frame of the pushed screen, before anything settled.
          await tester.pump();
          if (ms > 0) await tester.pump(Duration(milliseconds: ms));
        } else {
          await tester.pump();
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            await _real(tester, 20);
          }
          await scene.run?.call(tester);
        }

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/${shot.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
        });
        // Tear the page down so no timer outlives the test.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
      for (final e in errors) {
        print('  ERROR: ${e.split('\n').take(40).join('\n')}');
      }
      expect(
        errors,
        isEmpty,
        reason: 'overflow or build error in ${shot.name}',
      );
    });
  }
}
