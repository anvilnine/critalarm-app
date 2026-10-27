// Captures the first launch welcome pages off the device, through the real
// router and the real onboarding shell on the mock server.
//
//   fvm flutter test tool/capture_welcome_word.dart
//
// Files are named
//   <part>_<size>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=word,pages (default: all):
//   word     page 1 at 0.3 s, 1.5 s, 3.5 s, 5 s and 6.5 s of its clock, and
//            under reduced motion (the settled frame). Light and dark at 390
//            by 844, light at 320 by 640, and the text sizes 1.3 and 2.0.
//            At 2.0 the picture is dropped and the shared title is back.
//   pages    pages 2 and 3 at rest (the curl and the widgets), in the same
//            sizes, light, dark and under reduced motion.
//   swipe    the three pages at rest and the frames between them while a
//            finger holds the pager at page values 0.25, 0.5 and 0.75, going
//            forward from page 1 to 2 and from 2 to 3 and coming back from
//            3 to 2 and from 2 to 1. Light and dark at 390 by 844, light at
//            320 by 640, and the text sizes 1.3 and 2.0. Under reduced
//            motion the pager does not follow a finger, so it shows the
//            three pages at rest only.
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     .scratch-a228/captures)
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
  defaultValue: '.scratch-a228/captures',
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
    ? {'word', 'pages', 'swipe'}
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
  router.go('/onboarding/welcome');
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
  _Phone phone,
  ThemeMode mode,
  double scale,
  String frame,
) => '${part}_${phone.name}_${mode.name}_${scale}x_$frame';

/// Page 1 at [seconds] of its clock, one file for each, in one run.
void _wordShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  required List<double> seconds,
  bool reduceMotion = false,
  String? frameName,
}) {
  if (!_parts.contains('word')) return;
  final frames = reduceMotion
      ? ['settled']
      : [
          for (final s in seconds)
            '${frameName ?? 't'}${s.toStringAsFixed(1).replaceAll('.', '_')}',
        ];
  final names = [
    for (final f in frames) _name('word', phone, mode, scale, f),
  ];
  if (!names.any(_wanted)) return;
  testWidgets(
    'capture word ${phone.name} ${mode.name} ${scale}x'
    '${reduceMotion ? ' reduced' : ''}',
    (tester) async {
      await _guarded(names.first, (errors) async {
        final run = await _open(
          tester,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: reduceMotion,
        );
        if (reduceMotion) {
          await tester.pump(const Duration(milliseconds: 500));
          if (_wanted(names.first)) {
            await _save(tester, run, names.first, errors);
          }
          return;
        }
        var at = 0.0;
        for (var i = 0; i < seconds.length; i++) {
          final step = seconds[i] - at;
          if (step > 0) {
            // Whole frames of 100 ms, so every ticker sees a clock that is
            // a multiple of a tenth of a second.
            var left = (step * 1000).round();
            while (left > 0) {
              final each = left >= 100 ? 100 : left;
              await tester.pump(Duration(milliseconds: each));
              left -= each;
            }
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

/// Pages 2 and 3 at rest, 2.5 s after each page has come to rest.
void _pageShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
}) {
  if (!_parts.contains('pages')) return;
  final frame = reduceMotion ? 'still' : 'rest';
  final names = [
    _name('page2', phone, mode, scale, frame),
    _name('page3', phone, mode, scale, frame),
  ];
  if (!names.any(_wanted)) return;
  testWidgets(
    'capture pages ${phone.name} ${mode.name} ${scale}x'
    '${reduceMotion ? ' reduced' : ''}',
    (tester) async {
      await _guarded(names.first, (errors) async {
        final run = await _open(
          tester,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: reduceMotion,
        );
        final next = find.text('Next');
        for (var i = 0; i < 2; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          // At the largest text the button is below the fold of a scroll.
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pump();
          // The slide takes 400 ms and the page then rests.
          await tester.pump(const Duration(milliseconds: 500));
          for (var s = 0; s < 25; s++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (_wanted(names[i])) await _save(tester, run, names[i], errors);
        }
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

/// The three pages at rest, and the pager held at 0.25, 0.5 and 0.75 of the
/// way between neighbours, forward and back.
void _swipeShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
}) {
  if (!_parts.contains('swipe')) return;
  const marks = [0.25, 0.5, 0.75];
  String mark(double v) => (v * 100).round().toString().padLeft(3, '0');
  String name(String frame) => _name('swipe', phone, mode, scale, frame);
  final rests = reduceMotion
      ? ['still1', 'still2', 'still3']
      : ['rest1', 'rest2', 'rest3'];
  final names = [
    for (final r in rests) name(r),
    if (!reduceMotion) ...[
      name('wiggle_025'),
      for (final v in marks) name('fwd12_${mark(v)}'),
      for (final v in marks) name('fwd23_${mark(v)}'),
      for (final v in marks) name('back32_${mark(v)}'),
      for (final v in marks) name('back21_${mark(v)}'),
    ],
  ];
  if (!names.any(_wanted)) return;
  testWidgets(
    'capture swipe ${phone.name} ${mode.name} ${scale}x'
    '${reduceMotion ? ' reduced' : ''}',
    (tester) async {
      await _guarded(names.first, (errors) async {
        final run = await _open(
          tester,
          phone: phone,
          mode: mode,
          scale: scale,
          reduceMotion: reduceMotion,
        );
        final width = phone.size.width;
        Future<void> shot(String frame) async {
          if (_wanted(name(frame))) {
            await _save(tester, run, name(frame), errors);
          }
        }

        Future<void> rest({int seconds = 5}) async {
          for (var i = 0; i < seconds * 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        if (reduceMotion) {
          await rest(seconds: 1);
          await shot(rests[0]);
          final next = find.text('Next');
          for (var i = 1; i < 3; i++) {
            await tester.ensureVisible(next);
            await tester.tap(next);
            await tester.pump();
            await rest(seconds: 1);
            await shot(rests[i]);
          }
          return;
        }

        // Page 1, with the block up and the face shouting.
        await rest();
        await shot(rests[0]);

        Future<void> drag({
          required String label,
          required double from,
          required double to,
          required List<double> values,
          required String rest0,
        }) async {
          final gesture = await tester.startGesture(
            Offset(width / 2, phone.size.height * 0.4),
          );
          for (final v in values) {
            await _holdAt(tester, gesture, from + (to - from) * v, width);
            await shot('${label}_${mark(v)}');
          }
          await gesture.up();
          await rest(seconds: 3);
          if (rest0.isNotEmpty) await shot(rest0);
        }

        // The pager out to half way and back to a quarter, with the first page
        // still alive: its face and title fade back in, uncut.
        final wiggle = await tester.startGesture(
          Offset(width / 2, phone.size.height * 0.4),
        );
        await _holdAt(tester, wiggle, 0.5, width);
        await _holdAt(tester, wiggle, 0.25, width);
        await shot('wiggle_025');
        await wiggle.up();
        await tester.pump(const Duration(milliseconds: 600));

        await drag(
          label: 'fwd12',
          from: 0,
          to: 1,
          values: marks,
          rest0: rests[1],
        );
        await drag(
          label: 'fwd23',
          from: 1,
          to: 2,
          values: marks,
          rest0: rests[2],
        );
        await drag(
          label: 'back32',
          from: 2,
          to: 1,
          values: marks,
          rest0: '',
        );
        await drag(
          label: 'back21',
          from: 1,
          to: 0,
          values: marks,
          rest0: '',
        );
      });
    },
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  const all = [0.3, 1.5, 3.5, 5.0, 6.5];

  // Page 1.
  _wordShots(
    phone: _tall,
    mode: ThemeMode.light,
    scale: 1,
    seconds: all,
  );
  _wordShots(
    phone: _tall,
    mode: ThemeMode.dark,
    scale: 1,
    seconds: const [0.3, 3.5, 5.0],
  );
  _wordShots(
    phone: _narrow,
    mode: ThemeMode.light,
    scale: 1,
    seconds: all,
  );
  _wordShots(
    phone: _narrow,
    mode: ThemeMode.dark,
    scale: 1,
    seconds: const [5.0],
  );
  for (final scale in const [1.3, 2.0]) {
    for (final phone in const [_tall, _narrow]) {
      _wordShots(
        phone: phone,
        mode: ThemeMode.light,
        scale: scale,
        seconds: const [1.5, 5.0],
      );
    }
  }
  _wordShots(
    phone: _tall,
    mode: ThemeMode.dark,
    scale: 2,
    seconds: const [5.0],
  );
  for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
    for (final phone in const [_tall, _narrow]) {
      _wordShots(
        phone: phone,
        mode: mode,
        scale: 1,
        seconds: const [],
        reduceMotion: true,
      );
    }
  }
  for (final scale in const [1.3, 2.0]) {
    _wordShots(
      phone: _tall,
      mode: ThemeMode.light,
      scale: scale,
      seconds: const [],
      reduceMotion: true,
    );
  }

  // The first pass ends at 7 s and, with nobody having touched it, the pages
  // move on by themselves: this shows page 2 by 9 s.
  _wordShots(
    phone: _tall,
    mode: ThemeMode.light,
    scale: 1,
    seconds: const [6.9, 7.2, 9.0],
    frameName: 'handon',
  );

  // Pages 2 and 3.
  for (final phone in const [_tall, _narrow]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      _pageShots(phone: phone, mode: ThemeMode.light, scale: scale);
    }
  }
  _pageShots(phone: _tall, mode: ThemeMode.dark, scale: 1);
  _pageShots(
    phone: _tall,
    mode: ThemeMode.light,
    scale: 1,
    reduceMotion: true,
  );
  _pageShots(
    phone: _narrow,
    mode: ThemeMode.light,
    scale: 1,
    reduceMotion: true,
  );

  // The swipe, with a finger holding the pager between pages.
  _swipeShots(phone: _tall, mode: ThemeMode.light, scale: 1);
  _swipeShots(phone: _tall, mode: ThemeMode.dark, scale: 1);
  _swipeShots(phone: _narrow, mode: ThemeMode.light, scale: 1);
  _swipeShots(phone: _tall, mode: ThemeMode.light, scale: 1.3);
  _swipeShots(phone: _tall, mode: ThemeMode.light, scale: 2);
  _swipeShots(phone: _narrow, mode: ThemeMode.light, scale: 1.3);
  _swipeShots(
    phone: _tall,
    mode: ThemeMode.light,
    scale: 1,
    reduceMotion: true,
  );
  _swipeShots(
    phone: _narrow,
    mode: ThemeMode.dark,
    scale: 1,
    reduceMotion: true,
  );
}
