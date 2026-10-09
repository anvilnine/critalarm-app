// Captures the surfaces that show a locked option before they sell it, off
// the device, on the mock server and the developer plan switches.
//
//   fvm flutter test tool/capture_lock_surfaces.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// It boots the app's dependencies for each shot with the plan the shot
// needs, opens the screen and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x.png. The path of every file is printed.
//
// Scenes (the plan in brackets):
//   challenge_free_row     topic page, Wake-up challenge row, locked (Free)
//   challenge_free_sheet   the tap on that row: the picker sheet with a plan
//                          word on each challenge (Free)
//   challenge_pro_sheet    the same sheet with Pro held: no plan words
//   challenge_pick         a locked challenge picked in the sheet: the
//                          paywall opens (Free)
//   look_pick              a locked look picked in the sheet: the paywall opens
//   look_free_row          topic page, Alarm look row, locked (Free)
//   look_free_sheet        the picker sheet with a plan word on each paid look
//   look_pro_sheet         the same sheet with Pro held
//   weekly_free            Reliability, weekly check row locked: title, line,
//                          switch off, badge (Free)
//   weekly_hosted          the open row (Hosted held)
//   weekly_own             one line saying it is not available (own server)
//   weekly_reading         the plan is still being read: the row is drawn with
//                          no badge (the "Plan still being read" preset)
//   weekly_tap             the switch on the locked row tapped: the Hosted
//                          paywall opens (Free)
//
// At 390 by 844 it writes light and dark at text scale 1.0 and light at 1.3
// and 2.0. At 320 by 640 it writes light and dark at 1.0.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default
//                                build/lock_surfaces)
//   --dart-define=ONLY=<part>,<part>
//                                only the files whose name has one of these
//                                parts
//
// A capture fails when anything overflows. Nothing here plays motion: the
// sheet and the paywall are shown once they have settled.
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
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/presentation/topic_challenge_row.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/topic_alarm_style_row.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/lock_surfaces',
);
const _only = String.fromEnvironment('ONLY');

/// The plan a scene starts in, as the developer switches save it.
enum _Plan {
  free({'dev.access.hosted': 'notHeld', 'dev.access.pro': 'notHeld'}),
  pro({'dev.access.hosted': 'notHeld', 'dev.access.pro': 'held'}),
  hosted({'dev.access.hosted': 'held', 'dev.access.pro': 'notHeld'}),
  own({
    'dev.access.hosted': 'held',
    'dev.access.pro': 'held',
    'dev.access.server': 'ownServer',
  }),
  // The "Plan still being read" preset: nothing held, ready held open.
  reading({
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'notHeld',
    'dev.access.hold_plan_read': true,
  });

  const _Plan(this.prefs);

  final Map<String, Object> prefs;
}

enum _Screen { topic, reliability }

class _Scene {
  const _Scene(this.name, this.plan, this.screen, this.act);

  final String name;
  final _Plan plan;
  final _Screen screen;

  /// What happens on the screen before the capture.
  final Future<void> Function(WidgetTester tester) act;
}

/// Scrolls what [finder] finds to the middle of the screen.
Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await Scrollable.ensureVisible(
    tester.element(finder.first),
    alignment: 0.5,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _challengeRow(WidgetTester tester) async {
  await _show(tester, find.byType(TopicChallengeRow));
}

Future<void> _challengeSheet(WidgetTester tester) async {
  await _challengeRow(tester);
  await tester.tap(find.byType(TopicChallengeRow));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _challengePick(WidgetTester tester) async {
  await _challengeSheet(tester);
  await tester.tap(find.text(LocaleKeys.challenges_ops_math_name.tr()));
  await _afterPick(tester);
}

/// Lets the sheet close, the plan be awaited and the paywall open.
Future<void> _afterPick(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await _real(tester, 400);
  }
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _lookRow(WidgetTester tester) async {
  await _show(tester, find.byType(TopicAlarmStyleRow));
}

Future<void> _lookSheet(WidgetTester tester) async {
  await _lookRow(tester);
  await tester.tap(find.byType(TopicAlarmStyleRow));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _lookPick(WidgetTester tester) async {
  await _lookSheet(tester);
  await tester.tap(find.text(LocaleKeys.alarm_styles_terminal.tr()));
  await _afterPick(tester);
}

Future<void> _weekly(WidgetTester tester) async {
  await _show(tester, find.text(LocaleKeys.weekly_check_title.tr()));
}

Future<void> _weeklyTap(WidgetTester tester) async {
  await _weekly(tester);
  await tester.tap(find.byType(AppSwitch).first);
  await tester.pump();
  await _real(tester, 600);
  await tester.pump(const Duration(seconds: 2));
}

const _scenes = <_Scene>[
  _Scene('challenge_free_row', _Plan.free, _Screen.topic, _challengeRow),
  _Scene('challenge_free_sheet', _Plan.free, _Screen.topic, _challengeSheet),
  _Scene('challenge_pro_sheet', _Plan.pro, _Screen.topic, _challengeSheet),
  _Scene('challenge_pick', _Plan.free, _Screen.topic, _challengePick),
  _Scene('look_pick', _Plan.free, _Screen.topic, _lookPick),
  _Scene('look_free_row', _Plan.free, _Screen.topic, _lookRow),
  _Scene('look_free_sheet', _Plan.free, _Screen.topic, _lookSheet),
  _Scene('look_pro_sheet', _Plan.pro, _Screen.topic, _lookSheet),
  _Scene('weekly_free', _Plan.free, _Screen.reliability, _weekly),
  _Scene('weekly_hosted', _Plan.hosted, _Screen.reliability, _weekly),
  _Scene('weekly_own', _Plan.own, _Screen.reliability, _weekly),
  _Scene('weekly_reading', _Plan.reading, _Screen.reliability, _weekly),
  _Scene('weekly_tap', _Plan.free, _Screen.reliability, _weeklyTap),
];

const _variants = <(String, Size, ThemeMode, double)>[
  ('390x844', Size(390, 844), ThemeMode.light, 1.0),
  ('390x844', Size(390, 844), ThemeMode.dark, 1.0),
  ('390x844', Size(390, 844), ThemeMode.light, 1.3),
  ('390x844', Size(390, 844), ThemeMode.light, 2.0),
  ('320x640', Size(320, 640), ThemeMode.light, 1.0),
  ('320x640', Size(320, 640), ThemeMode.dark, 1.0),
];

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
    ...scene.plan.prefs,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  final server = getIt<MockServer>()..seedCalm();
  if (scene.plan == _Plan.hosted) {
    // Enrolled, with the last round received.
    server.seedWeeklyCheck(WeeklyCheckState.received);
  }
  if (scene.screen == _Screen.reliability) {
    // A read may be out already. The second call is sure to read after the
    // seed.
    final monitor = getIt<WeeklyCheckMonitor>();
    await monitor.refresh(force: true);
    await monitor.refresh(force: true);
  }
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

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<GlobalKey> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
}) async {
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
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
            disableAnimations: true,
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
  );
  router.go('/');
  await _settle(tester);
  unawaited(
    router.push(
      scene.screen == _Screen.topic
          ? '/topics/prod-db'
          : '/settings/reliability',
    ),
  );
  await _settle(tester);
  await tester.pump(const Duration(seconds: 2));
  await _frames(tester);
  return key;
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

/// The one layout assertion that reduce motion trips: an `AnimatedSize` with
/// a zero duration marks itself dirty while it lays out when its child
/// changes size. It exists in a debug build only.
bool _isKnownReduceMotionAssert(String error) =>
    error.contains('RenderAnimatedSize was mutated in its own performLayout');

void main() {
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final scene in _scenes) {
    for (final (phoneName, phone, mode, scale) in _variants) {
      final name = '${scene.name}_${phoneName}_${mode.name}_${scale}x';
      if (onlyParts.isNotEmpty && !onlyParts.any(name.contains)) continue;
      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          if (_isKnownReduceMotionAssert(text)) {
            print('  NOTE: $text');
            return;
          }
          errors.add(d.toString());
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        final key = await _open(
          tester,
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
        );
        await scene.act(tester);
        await _frames(tester);
        await _save(tester, key, name, errors);
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').take(40).join('\n')}');
        }
        expect(errors, isEmpty, reason: 'overflow or build error in $name');
      });
    }
  }
}
