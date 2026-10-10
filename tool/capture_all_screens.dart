// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_int_literals
// Tool prints progress to stdout.
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:io';
import 'dart:ui' as ui;
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

import 'capture_fonts.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'api.critalarm.app',
      'admin_token': 'adm_demo_token',
    });
    // `test/flutter_test_config.dart` only runs for files under test/, so
    // this tool loads the strings itself or every label renders as its key.
    await loadTestTranslations();
    await configureDependencies();
    await loadAppFonts();
  });

  // The fourth field pins the platform the screen renders as. It matters for
  // the sound picker, which shows a different note on iOS.
  final screens = <(String, String, FaceState, TargetPlatform?)>[
    ('01_gallery', '/gallery', FaceState.calm, null),
    ('02_onboarding_welcome', '/onboarding', FaceState.calm, null),
    (
      '03_onboarding_permissions',
      '/onboarding/permissions',
      FaceState.alarmed,
      null,
    ),
    ('04_home_face', '/', FaceState.calm, null),
    ('05_topics_list', '/topics', FaceState.calm, null),
    ('06_topic_detail', '/topics/nas-backup', FaceState.worried, null),
    ('07_create_topic', '/topics/new', FaceState.watching, null),
    ('08_critical_alarm', '/alarm', FaceState.alarmed, null),
    ('09_lock_screen', '/lockscreen', FaceState.alarmed, null),
    ('10_settings', '/settings', FaceState.acked, null),
    ('11_paywall_shell', '/paywall', FaceState.acked, null),
    ('12_device_permissions', '/settings/permissions', FaceState.calm, null),
    ('13_permission_denial', '/onboarding/denied', FaceState.worried, null),
    ('14_server_disconnected', '/settings/disconnected', FaceState.calm, null),
    (
      '15_sound_picker_ios',
      '/settings/sounds',
      FaceState.calm,
      TargetPlatform.iOS,
    ),
  ];

  for (final (filename, routePath, fixtureState, platform) in screens) {
    testWidgets('Capture $filename at $routePath', (tester) async {
      getIt<MockServer>().loadFixture(fixtureState);
      debugDefaultTargetPlatformOverride = platform;

      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final repaintBoundaryKey = GlobalKey();
      // A pinned platform means the screen is only meaningful on that one, so
      // it is opened directly rather than walked to from home.
      final router = platform == null
          ? buildRouter()
          : buildRouter(initialLocation: routePath);

      await tester.pumpWidget(
        BlocProvider<ThemeCubit>.value(
          value: getIt<ThemeCubit>(),
          child: MaterialApp.router(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.light,
            routerConfig: router,
            builder: (context, child) => RepaintBoundary(
              key: repaintBoundaryKey,
              child: child,
            ),
          ),
        ),
      );

      router.go(routePath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // A screen whose cubit awaits a platform channel needs real time, not
      // pumped time, before it has anything to draw.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.runAsync(() async {
        final boundary =
            repaintBoundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File('screenshots/$filename.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(pngBytes);
        print('Captured $filename (${pngBytes.length} bytes) -> ${file.path}');
      });

      // Reset inside the test body: the framework checks this before any
      // tear-down callback runs.
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
