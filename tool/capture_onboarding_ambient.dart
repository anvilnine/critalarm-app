// Captures the ambient shapes behind every setup step, off the device,
// through the real router and the real onboarding shell on the mock server.
//
//   fvm flutter test tool/capture_onboarding_ambient.dart
//
// For each step it saves the step at rest and one frame of the glide into
// it from the step before, taken 120 ms into the 400 ms move. The run starts
// on the third welcome page, so the first glide is the one out of the last
// welcome page. A last pair goes from the connect step back to the welcome.
// Files are named <theme>_<motion>_<order>_<kind>_<step>.png.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default
//                                .scratch-a228/ambient)
//
// A capture is a still of one moment: it does not show anything moving.
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
  defaultValue: '.scratch-a228/ambient',
);

/// A phone to draw on.
class _Phone {
  const _Phone(this.name, this.size, {required this.top, this.bottom = 0});

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390x844', Size(390, 844), top: 47, bottom: 34);

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

/// Every step route in the order the flows run them, then the steps only an
/// older or a remote flow lists.
const _steps = <(String, String)>[
  ('connect', '/onboarding/connect'),
  ('permissions', '/onboarding'),
  ('first_topic', '/onboarding/first-topic'),
  ('real_ring', '/onboarding/real-ring'),
  ('offer', '/onboarding/offer'),
  ('hook_up', '/onboarding/hook-up'),
  ('how_it_rings', '/onboarding/how-it-rings'),
  ('widgets', '/onboarding/widgets'),
  ('legacy_test', '/onboarding/test'),
];

void _sequence({required ThemeMode mode, required bool reduceMotion}) {
  final tag = '${mode.name}_${reduceMotion ? 'still' : 'moving'}';
  testWidgets('capture ambient $tag', (tester) async {
    await _guarded(tag, (errors) async {
      final run = await _open(
        tester,
        phone: _phone,
        mode: mode,
        scale: 1,
        reduceMotion: reduceMotion,
      );
      var order = 0;
      Future<void> shot(String kind, String step) async {
        final name =
            '${tag}_${(order++).toString().padLeft(2, '0')}_${kind}_$step';
        await _save(tester, run, name, errors);
      }

      await tester.pump(const Duration(milliseconds: 500));
      await shot('rest', 'welcome_p1');
      final next = find.text('Next');
      for (var i = 0; i < 2; i++) {
        await tester.tap(next);
        await tester.pump();
        for (var s = 0; s < 8; s++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await shot('rest', 'welcome_p3');

      for (final (name, route) in _steps) {
        run.router.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await shot('mid', 'to_$name');
        for (var s = 0; s < 15; s++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await shot('rest', name);
      }

      // Back over the first step change.
      run.router.go('/onboarding/connect');
      for (var s = 0; s < 15; s++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      run.router.go('/onboarding/welcome');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await shot('mid', 'back_to_welcome');
      for (var s = 0; s < 15; s++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot('rest', 'welcome_again');
    });
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  _sequence(mode: ThemeMode.light, reduceMotion: false);
  _sequence(mode: ThemeMode.dark, reduceMotion: false);
  _sequence(mode: ThemeMode.light, reduceMotion: true);
}
