// Captures the two other first welcome pages (night falls, stays silent) and
// the default first page, off the device, through the real router and the
// real onboarding shell on the mock server. The other two are opened the way
// Developer options opens them, with `first=night` and `first=silent` in a
// replay, so nothing is saved.
//
//   fvm flutter test tool/capture_welcome_first_pages.dart
//
// Files are named
//   <part>_<hero>_<size>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=frames,still,swipe,default
// (default: all):
//   frames   the hero at several seconds of its clock: light and dark at 390
//            by 844, light at 320 by 640, and the text sizes 1.3 and 2.0.
//   still    the settled frame under reduced motion, light and dark.
//   swipe    the pager held at 0.25, 0.5 and 0.75 of the way to page 2, with
//            the hero in its busiest moment.
//   default  the first page with no first= value: still the word page.
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     .scratch-welcome)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
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

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: '.scratch-welcome',
);
const _partsArg = String.fromEnvironment('PARTS');
const _onlyArg = String.fromEnvironment('ONLY');

/// A phone to draw on.
class _Phone {
  const _Phone(this.name, this.size, {required this.top, this.bottom = 0});

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _tall = _Phone('390x844', Size(390, 844), top: 47, bottom: 34);
const _narrow = _Phone('320x640', Size(320, 640), top: 20);

Set<String> get _parts => _partsArg.isEmpty
    ? {'frames', 'still', 'swipe', 'default'}
    : _partsArg.split(',').toSet();

bool _wanted(String name) {
  final only = _onlyArg.split(',').where((p) => p.isNotEmpty);
  return only.isEmpty || only.any(name.contains);
}

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

/// A running shot.
class _Run {
  _Run(this.key, this.router);

  final GlobalKey key;
  final GoRouter router;
}

Future<_Run> _open(
  WidgetTester tester, {
  required String location,
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  required bool reduceMotion,
}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await configureDependencies(useMockApi: true);
    getIt<MockServer>().seedCalm();
  });
  const dpr = 2.0;
  tester.view.physicalSize = phone.size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: phone.top * dpr,
    bottom: phone.bottom * dpr,
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
            themeMode: mode,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduceMotion,
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
  await _real(tester);
  router.go(location);
  // Frames of no length, so the clock of the first page starts at 0 on the
  // frame it appears.
  for (var i = 0; i < 12; i++) {
    await tester.pump();
    await _real(tester, 50);
  }
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

String _name(
  String part,
  _Hero hero,
  _Phone phone,
  ThemeMode mode,
  double scale,
  String frame,
) => '${part}_${hero.name}_${phone.name}_${mode.name}_${scale}x_$frame';

/// A first page to capture and how to open it.
class _Hero {
  const _Hero(this.name, this.location, this.moments);

  final String name;
  final String location;

  /// The seconds of its clock worth looking at across one pass.
  final List<double> moments;

  /// Where its story is at its busiest, for the swipe and the text sizes.
  double get busiest => name == 'night' ? 6.2 : 5.2;
}

const _night = _Hero('night', '/onboarding/welcome?demo=true&first=night', [
  0.4,
  1.8,
  2.6,
  3.6,
  5.0,
  5.7,
  6.6,
  9.4,
]);
const _silent = _Hero('silent', '/onboarding/welcome?demo=true&first=silent', [
  0.3,
  1.2,
  2.2,
  3.2,
  4.1,
  4.7,
  5.6,
  7.4,
]);
const _word = _Hero('word', '/onboarding/welcome', [5.0]);

/// Runs the clock forward in whole frames of 100 ms.
Future<void> _advance(WidgetTester tester, double seconds) async {
  var left = (seconds * 1000).round();
  while (left > 0) {
    final each = left >= 100 ? 100 : left;
    await tester.pump(Duration(milliseconds: each));
    left -= each;
  }
}

/// The hero at each of [seconds] of its clock, one file for each.
void _frameShots({
  required _Hero hero,
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  required List<double> seconds,
  String part = 'frames',
}) {
  if (!_parts.contains(part)) return;
  String label(double s) => 't${s.toStringAsFixed(1).replaceAll('.', '_')}';
  final names = [
    for (final s in seconds) _name(part, hero, phone, mode, scale, label(s)),
  ];
  if (!names.any(_wanted)) return;
  testWidgets(
    'capture $part ${hero.name} ${phone.name} ${mode.name} ${scale}x',
    (
      tester,
    ) async {
      await _guarded(names.first, (errors) async {
        final run = await _open(
          tester,
          location: hero.location,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: false,
        );
        var at = 0.0;
        for (var i = 0; i < seconds.length; i++) {
          final step = seconds[i] - at;
          if (step > 0) {
            await _advance(tester, step);
          } else {
            await tester.pump();
          }
          at = seconds[i];
          if (_wanted(names[i])) await _save(tester, run, names[i], errors);
        }
      });
    },
  );
}

/// The settled frame under reduced motion.
void _stillShots({
  required _Hero hero,
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('still')) return;
  final name = _name('still', hero, phone, mode, scale, 'settled');
  if (!_wanted(name)) return;
  testWidgets(
    'capture still ${hero.name} ${phone.name} ${mode.name} ${scale}x',
    (
      tester,
    ) async {
      await _guarded(name, (errors) async {
        final run = await _open(
          tester,
          location: hero.location,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: true,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await _save(tester, run, name, errors);
      });
    },
  );
}

PageController _pager(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!;

/// Holds [gesture] until the pager shows [target] as its page value.
Future<void> _holdAt(
  WidgetTester tester,
  TestGesture gesture,
  double target,
  double width,
) async {
  final pager = _pager(tester);
  for (var i = 0; i < 80; i++) {
    final remaining = target - pager.page!;
    if (remaining.abs() < 0.003) break;
    await gesture.moveBy(Offset(-remaining * width, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 16));
}

/// The pager held at 0.25, 0.5 and 0.75 of the way to page 2, with the hero
/// at its busiest. Then the page at rest after the swipe.
void _swipeShots({
  required _Hero hero,
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('swipe')) return;
  const marks = [0.25, 0.5, 0.75];
  String mark(double v) => (v * 100).round().toString().padLeft(3, '0');
  String name(String frame) => _name('swipe', hero, phone, mode, scale, frame);
  final names = [
    name('rest1'),
    for (final v in marks) name('fwd12_${mark(v)}'),
    name('rest2'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets(
    'capture swipe ${hero.name} ${phone.name} ${mode.name} ${scale}x',
    (
      tester,
    ) async {
      await _guarded(names.first, (errors) async {
        final run = await _open(
          tester,
          location: hero.location,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: false,
        );
        Future<void> shot(String frame) async {
          if (_wanted(name(frame))) {
            await _save(tester, run, name(frame), errors);
          }
        }

        await _advance(tester, hero.busiest);
        await shot('rest1');
        final width = phone.size.width;
        final gesture = await tester.startGesture(
          Offset(width / 2, phone.size.height * 0.4),
        );
        for (final v in marks) {
          await _holdAt(tester, gesture, v, width);
          await shot('fwd12_${mark(v)}');
        }
        await gesture.up();
        await _advance(tester, 3);
        await shot('rest2');
      });
    },
  );
}

/// The hand-on: with nobody having touched the page, the first pass ends and
/// page 2 opens by itself.
void _handOnShots({required _Hero hero}) {
  if (!_parts.contains('frames')) return;
  final names = [
    for (final s in const [0.2, 1.0, 3.0])
      _name(
        'handon',
        hero,
        _tall,
        ThemeMode.light,
        1,
        't${s.toStringAsFixed(1).replaceAll('.', '_')}',
      ),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture handon ${hero.name}', (tester) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        location: hero.location,
        phone: _tall,
        mode: ThemeMode.light,
        scale: 1,
        reduceMotion: false,
      );
      // Just under the end of the pass, then 0.2, 1.0 and 3.0 s after it.
      final loop = hero.name == 'night' ? 10.0 : 8.0;
      await _advance(tester, loop - 0.1);
      var at = 0.0;
      const after = [0.2, 1.0, 3.0];
      for (var i = 0; i < after.length; i++) {
        await _advance(tester, after[i] - at);
        at = after[i];
        if (_wanted(names[i])) await _save(tester, run, names[i], errors);
      }
    });
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final hero in const [_night, _silent]) {
    // Across one pass.
    _frameShots(
      hero: hero,
      phone: _tall,
      mode: ThemeMode.light,
      scale: 1,
      seconds: hero.moments,
    );
    _frameShots(
      hero: hero,
      phone: _tall,
      mode: ThemeMode.dark,
      scale: 1,
      seconds: [hero.moments[0], hero.moments[3], hero.moments[5]],
    );
    _frameShots(
      hero: hero,
      phone: _narrow,
      mode: ThemeMode.light,
      scale: 1,
      seconds: [
        hero.moments[0],
        hero.moments[2],
        hero.moments[4],
        hero.moments[5],
        hero.moments[6],
      ],
    );
    _frameShots(
      hero: hero,
      phone: _narrow,
      mode: ThemeMode.dark,
      scale: 1,
      seconds: [hero.moments[5]],
    );
    for (final scale in const [1.3, 2.0]) {
      for (final phone in const [_tall, _narrow]) {
        _frameShots(
          hero: hero,
          phone: phone,
          mode: ThemeMode.light,
          scale: scale,
          seconds: [hero.moments[3], hero.busiest],
        );
      }
    }
    _handOnShots(hero: hero);

    // Reduced motion.
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final phone in const [_tall, _narrow]) {
        _stillShots(hero: hero, phone: phone, mode: mode, scale: 1);
      }
    }
    for (final scale in const [1.3, 2.0]) {
      _stillShots(
        hero: hero,
        phone: _tall,
        mode: ThemeMode.light,
        scale: scale,
      );
    }

    // The swipe.
    _swipeShots(hero: hero, phone: _tall, mode: ThemeMode.light, scale: 1);
    _swipeShots(hero: hero, phone: _tall, mode: ThemeMode.dark, scale: 1);
    _swipeShots(hero: hero, phone: _narrow, mode: ThemeMode.light, scale: 1);
    _swipeShots(hero: hero, phone: _tall, mode: ThemeMode.light, scale: 1.3);
  }

  // The default first page is still the word page.
  _frameShots(
    hero: _word,
    phone: _tall,
    mode: ThemeMode.light,
    scale: 1,
    seconds: _word.moments,
    part: 'default',
  );
  _frameShots(
    hero: _word,
    phone: _narrow,
    mode: ThemeMode.light,
    scale: 1,
    seconds: _word.moments,
    part: 'default',
  );
}
