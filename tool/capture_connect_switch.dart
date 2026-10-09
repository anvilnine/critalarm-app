// Captures the connect step ("Pick a server") through the real router and
// the real onboarding shell on the mock server, in both of its states and
// across the switch between them.
//
//   fvm flutter test tool/capture_connect_switch.dart
//
// Files are named
//   <part>_<size>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=rest,switch (default: all):
//   rest     Crit Alarm Cloud and your own server, at rest.
//   switch   the switch in both directions at 0, 25, 50, 75 and 100 percent
//            of its 300 ms, and a settled frame a second later.
//   fast     three switches in a row, 80 ms apart, then the settled frame.
//   focused  your own server with the address field focused and a keyboard
//            up, then the switch to Cloud while the keyboard goes down.
//   reduced  both states and the frame right after a tap, with the system
//            asking for less motion.
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     .scratch-a231/captures)
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
  defaultValue: '.scratch-a231/captures',
);
const _partsArg = String.fromEnvironment('PARTS');
const _onlyArg = String.fromEnvironment('ONLY');

/// How long the switch takes.
const _switchMs = 300;

/// The keyboard of the focused capture, in logical pixels.
const _keyboard = 300.0;

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
    ? {'rest', 'switch', 'fast', 'focused', 'reduced'}
    : _partsArg.split(',').toSet();

bool _wanted(String name) {
  final only = _onlyArg.split(',').where((p) => p.isNotEmpty);
  return only.isEmpty || only.any(name.contains);
}

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

/// A running shot.
class _Run {
  _Run(this.key, this.router, this.phone);

  final GlobalKey key;
  final GoRouter router;
  final _Phone phone;
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
  router.go('/onboarding/connect');
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await _real(tester, 50);
  }
  // Let every entrance and every answer from the mock server settle.
  await tester.pump(const Duration(seconds: 2));
  return _Run(key, router, phone);
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

/// The toggle in the pinned bar, whichever way it reads.
Finder get _toggle => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data == 'I run my own server' ||
          w.data == 'Use Crit Alarm Cloud instead'),
);

Future<void> _tapToggle(WidgetTester tester) async {
  await tester.tap(_toggle.last, warnIfMissed: false);
  // The tap, the state change and the first frame of the switch.
  await tester.pump();
  await tester.pump();
}

/// Moves on by [ms] in frames of at most 16 ms, so every ticker sees the
/// frames a phone would. [keyboardAt] gives the keyboard height for the time
/// since the tap.
Future<void> _advance(
  WidgetTester tester,
  int ms, {
  double Function(int)? keyboardAt,
  int from = 0,
}) async {
  var done = 0;
  while (done < ms) {
    final each = (ms - done) >= 16 ? 16 : ms - done;
    await tester.pump(Duration(milliseconds: each));
    done += each;
    if (keyboardAt != null) {
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardAt(from + done) * 2,
      );
    }
  }
}

void _restShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('rest')) return;
  final names = [
    _name('cloud', phone, mode, scale, 'rest'),
    _name('own', phone, mode, scale, 'rest'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture rest ${phone.name} ${mode.name} ${scale}x', (
    tester,
  ) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        phone: phone,
        mode: mode,
        scale: scale,
        reduceMotion: false,
      );
      if (_wanted(names[0])) await _save(tester, run, names[0], errors);
      await _tapToggle(tester);
      await _advance(tester, 1500);
      if (_wanted(names[1])) await _save(tester, run, names[1], errors);
    });
  });
}

/// The switch from Cloud to your own server and back, at 0, 25, 50, 75 and
/// 100 percent of its length, then a second later.
void _switchShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('switch')) return;
  const marks = [0, 25, 50, 75, 100];
  final names = [
    for (final m in marks) _name('c2o', phone, mode, scale, 'p$m'),
    _name('c2o', phone, mode, scale, 'settled'),
    for (final m in marks) _name('o2c', phone, mode, scale, 'p$m'),
    _name('o2c', phone, mode, scale, 'settled'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture switch ${phone.name} ${mode.name} ${scale}x', (
    tester,
  ) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        phone: phone,
        mode: mode,
        scale: scale,
        reduceMotion: false,
      );
      var n = 0;
      for (final direction in ['c2o', 'o2c']) {
        await _tapToggle(tester);
        var at = 0;
        for (final m in marks) {
          final target = _switchMs * m ~/ 100;
          if (target > at) await _advance(tester, target - at);
          at = target;
          final name = names[n++];
          if (_wanted(name)) await _save(tester, run, name, errors);
        }
        await _advance(tester, 1000);
        final settled = names[n++];
        if (_wanted(settled)) await _save(tester, run, settled, errors);
        expect(direction, isNotEmpty);
      }
    });
  });
}

/// Three taps 80 ms apart: the switch turns round from where it is.
void _fastShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('fast')) return;
  final names = [
    _name('fast', phone, mode, scale, 'mid'),
    _name('fast', phone, mode, scale, 'settled'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture fast ${phone.name} ${mode.name} ${scale}x', (
    tester,
  ) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        phone: phone,
        mode: mode,
        scale: scale,
        reduceMotion: false,
      );
      await _tapToggle(tester);
      await _advance(tester, 80);
      await _tapToggle(tester);
      await _advance(tester, 80);
      await _tapToggle(tester);
      await _advance(tester, 60);
      if (_wanted(names[0])) await _save(tester, run, names[0], errors);
      await _advance(tester, 1500);
      if (_wanted(names[1])) await _save(tester, run, names[1], errors);
    });
  });
}

/// Your own server with the address field focused and a keyboard up, then
/// the switch to Cloud while the keyboard goes down.
void _focusedShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('focused')) return;
  const marks = [0, 50, 100];
  final names = [
    _name('focused', phone, mode, scale, 'rest'),
    for (final m in marks) _name('focused', phone, mode, scale, 'toCloud$m'),
    _name('focused', phone, mode, scale, 'settled'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture focused ${phone.name} ${mode.name} ${scale}x', (
    tester,
  ) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        phone: phone,
        mode: mode,
        scale: scale,
        reduceMotion: false,
      );
      await _tapToggle(tester);
      await _advance(tester, 1000);
      // Focus the address field and bring the keyboard up.
      final field = find.byType(EditableText).first;
      await tester.tap(field, warnIfMissed: false);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 2);
      await _advance(tester, 600);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'the address field should hold focus',
      );
      if (_wanted(names[0])) await _save(tester, run, names[0], errors);

      // The keyboard goes down over 250 ms from the tap.
      double down(int ms) => _keyboard * (1 - (ms / 250).clamp(0.0, 1.0));
      await _tapToggle(tester);
      var at = 0;
      for (var i = 0; i < marks.length; i++) {
        final target = _switchMs * marks[i] ~/ 100;
        if (target > at) {
          await _advance(tester, target - at, keyboardAt: down, from: at);
        }
        at = target;
        if (_wanted(names[1 + i])) {
          await _save(tester, run, names[1 + i], errors);
        }
      }
      await _advance(tester, 1000);
      for (final field in tester.widgetList<EditableText>(
        find.byType(EditableText, skipOffstage: false),
      )) {
        expect(
          field.focusNode.hasFocus,
          isFalse,
          reason: 'no field should hold focus after the switch to Cloud',
        );
      }
      if (_wanted(names.last)) await _save(tester, run, names.last, errors);
    });
  });
}

void _reducedShots({
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
}) {
  if (!_parts.contains('reduced')) return;
  final names = [
    _name('reduced', phone, mode, scale, 'cloud'),
    _name('reduced', phone, mode, scale, 'ownAfterTap'),
    _name('reduced', phone, mode, scale, 'cloudAfterTap'),
  ];
  if (!names.any(_wanted)) return;
  testWidgets('capture reduced ${phone.name} ${mode.name} ${scale}x', (
    tester,
  ) async {
    await _guarded(names.first, (errors) async {
      final run = await _open(
        tester,
        phone: phone,
        mode: mode,
        scale: scale,
        reduceMotion: true,
      );
      if (_wanted(names[0])) await _save(tester, run, names[0], errors);
      await _tapToggle(tester);
      // One frame after the tap: nothing is left to play.
      await tester.pump(const Duration(milliseconds: 16));
      if (_wanted(names[1])) await _save(tester, run, names[1], errors);
      await _tapToggle(tester);
      await tester.pump(const Duration(milliseconds: 16));
      if (_wanted(names[2])) await _save(tester, run, names[2], errors);
    });
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final phone in const [_tall, _narrow]) {
    _restShots(phone: phone, mode: ThemeMode.light, scale: 1);
    _switchShots(phone: phone, mode: ThemeMode.light, scale: 1);
    _restShots(phone: phone, mode: ThemeMode.dark, scale: 1);
    _switchShots(phone: phone, mode: ThemeMode.dark, scale: 1);
    for (final scale in const [1.3, 2.0]) {
      _restShots(phone: phone, mode: ThemeMode.light, scale: scale);
      _switchShots(phone: phone, mode: ThemeMode.light, scale: scale);
    }
    _reducedShots(phone: phone, mode: ThemeMode.light, scale: 1);
  }
  _fastShots(phone: _tall, mode: ThemeMode.light, scale: 1);
  _focusedShots(phone: _tall, mode: ThemeMode.light, scale: 1);
  _focusedShots(phone: _narrow, mode: ThemeMode.light, scale: 1);
  _focusedShots(phone: _tall, mode: ThemeMode.dark, scale: 1);
}
