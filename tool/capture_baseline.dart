// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Formatting tolerance in developer tool script.
// ignore_for_file: lines_longer_than_80_chars, prefer_int_literals
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capture_fonts.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    await loadAppFonts();
  });

  final screens = [
    ('01_gallery', '/gallery', FaceState.calm),
    ('02_onboarding_welcome', '/onboarding', FaceState.calm),
    ('03_onboarding_permissions', '/onboarding/permissions', FaceState.alarmed),
    ('04_home_face', '/', FaceState.calm),
    ('05_topics_list', '/topics', FaceState.calm),
    ('06_topic_detail', '/topics/nas-backup', FaceState.worried),
    ('07_create_topic', '/topics/new', FaceState.watching),
    ('08_critical_alarm', '/alarm', FaceState.alarmed),
    ('09_lock_screen', '/lockscreen', FaceState.alarmed),
    ('10_settings', '/settings', FaceState.acked),
    ('11_paywall_shell', '/paywall', FaceState.acked),
  ];

  final configs = [
    (
      'before_320',
      const Size(320 * 2, 640 * 2),
      2.0,
      1.0,
      'screenshots/before_320',
    ),
    (
      'before_1_3x',
      const Size(390 * 2, 844 * 2),
      2.0,
      1.3,
      'screenshots/before_1_3x',
    ),
    (
      'before_320_1_3x',
      const Size(320 * 2, 640 * 2),
      2.0,
      1.3,
      'screenshots/before_320_1_3x',
    ),
  ];

  for (final (configName, physSize, dpr, textScale, folder) in configs) {
    for (final (filename, routePath, fixtureState) in screens) {
      testWidgets('Baseline capture $configName $filename', (tester) async {
        final caughtErrors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details.exceptionAsString());
        };

        try {
          getIt<MockServer>().loadFixture(fixtureState);

          tester.view.physicalSize = physSize;
          tester.view.devicePixelRatio = dpr;
          addTearDown(tester.view.reset);

          final repaintBoundaryKey = GlobalKey();
          final router = buildRouter();

          await tester.pumpWidget(
            BlocProvider<ThemeCubit>.value(
              value: getIt<ThemeCubit>(),
              child: MaterialApp.router(
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: ThemeMode.light,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: RepaintBoundary(
                    key: repaintBoundaryKey,
                    child: child,
                  ),
                ),
              ),
            ),
          );

          router.go(routePath);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          await tester.runAsync(() async {
            final boundary =
                repaintBoundaryKey.currentContext?.findRenderObject()
                    as RenderRepaintBoundary?;
            if (boundary == null) {
              print('Could not find boundary for $filename in $configName');
              return;
            }
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final pngBytes = byteData!.buffer.asUint8List();

            final file = File('$folder/$filename.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(pngBytes);
            print(
              '[$configName] Captured $filename (${pngBytes.length} bytes) -> ${file.path}',
            );
          });

          if (caughtErrors.isNotEmpty) {
            print('[$configName][$filename] OVERFLOW/ERRORS:');
            for (final err in caughtErrors) {
              print('   -> $err');
            }
          }
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    }
  }
}
