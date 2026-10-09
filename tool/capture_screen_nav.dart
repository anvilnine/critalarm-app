// Captures the page change into a Topic screen and into Settings sub screens,
// frame by frame, so the two can be compared side by side.
//
//   fvm flutter test tool/capture_screen_nav.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Each scene boots the real router and the real ambient shell on the mock
// server, opens the root screen (Topics or Settings), pushes the destination
// the way a tap does, and saves the frame at 0, 25, 50, 75 and 100 percent of
// the transition, then pops it and saves the way back the same way. Files:
//   nav_<scene>_<theme>_<open|back>-t<000..100>.png
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/screen_nav)
//   --dart-define=SCENES=a,b          only these scenes (default: all)
//
// Scenes: topic (/topics/prod-db), about, priorities, server, account,
// developer, personalize, reliability (all under /settings).
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the page moving, and it cannot show the Android predictive
// back gesture.
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
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/captures/screen_nav',
);
const _scenesArg = String.fromEnvironment('SCENES');

/// One page change to capture: where it starts and where it goes.
class _Scene {
  const _Scene(this.name, this.root, this.target);

  final String name;
  final String root;
  final String target;
}

const _scenes = [
  _Scene('topic', '/', '/topics/prod-db'),
  _Scene('about', '/settings', '/settings/about'),
  _Scene('priorities', '/settings', '/settings/priorities'),
  _Scene('server', '/settings', '/settings/server'),
  _Scene('account', '/settings', '/settings/account'),
  _Scene('developer', '/settings', '/settings/developer'),
  _Scene('personalize', '/settings', '/settings/personalize'),
  _Scene('reliability', '/settings', '/settings/reliability'),
];

const _fractions = [0.0, 0.25, 0.5, 0.75, 1.0];

/// The length of the transition the frames are spread over.
const Duration _span = AppDurations.slow;

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 400);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 200);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name,
  List<String> errors,
) => tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
});

Future<void> _frames(
  WidgetTester tester,
  GlobalKey key,
  String prefix,
  List<String> errors,
) async {
  // Two empty pumps build the route and start its controller.
  await tester.pump();
  await tester.pump();
  var elapsed = Duration.zero;
  for (final fraction in _fractions) {
    final target = Duration(
      microseconds: (_span.inMicroseconds * fraction).round(),
    );
    if (target > elapsed) {
      await tester.pump(target - elapsed);
      elapsed = target;
    }
    final percent = (fraction * 100).round().toString().padLeft(3, '0');
    await _save(tester, key, '$prefix-t$percent', errors);
  }
  // Let the rest of it finish before the next direction starts.
  await tester.pump(const Duration(seconds: 1));
}

Set<String> get _wanted => _scenesArg.isEmpty
    ? _scenes.map((s) => s.name).toSet()
    : _scenesArg.split(',').toSet();

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final scene in _scenes) {
    if (!_wanted.contains(scene.name)) continue;
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      final theme = mode == ThemeMode.light ? 'light' : 'dark';
      testWidgets('capture ${scene.name} $theme', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.toString());
        debugDisableShadows = false;
        try {
          SharedPreferences.setMockInitialValues({
            'server_url': 'api.critalarm.app',
            'admin_token': 'adm_demo_token',
            'home_widgets_card_seen': true,
            'setup_checklist_done': true,
            'tour_guides_seen': '["topics","topic","settings","history"]',
            'has_completed_showcase_tour': true,
          });
          await tester.runAsync(() async {
            await getIt.reset();
            await configureDependencies(useMockApi: true);
            getIt<MockServer>().seedCalm();
          });
          const dpr = 2.0;
          tester.view.physicalSize = const Size(390, 844) * dpr;
          tester.view.devicePixelRatio = dpr;
          tester.view.padding = const FakeViewPadding(
            top: 47 * dpr,
            bottom: 34 * dpr,
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
                builder: (context, child) => RepaintBoundary(
                  key: key,
                  // A held clock draws the resting frame of every looping
                  // scene, so two runs of one frame are the same picture.
                  child: PaywallStill(
                    child: AppAmbientShell(
                      router: router,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );
          router.go(scene.root);
          await _settle(tester);

          final base = 'nav_${scene.name}_$theme';
          unawaited(router.push(scene.target));
          await _frames(tester, key, '$base-open', errors);
          router.pop();
          await _frames(tester, key, '$base-back', errors);
        } finally {
          debugDisableShadows = true;
          FlutterError.onError = oldHandler;
        }
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').take(30).join('\n')}');
        }
        expect(errors, isEmpty, reason: 'build error in ${scene.name}');
      });
    }
  }
}
