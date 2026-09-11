// Developer tool helper for loading fonts and capturing screenshots.
// ignore_for_file: cascade_invocations
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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  Future<ByteData> loadFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final anton = FontLoader('Anton');
  anton.addFont(loadFile('assets/fonts/Anton-Regular.ttf'));
  await anton.load();

  final archivo = FontLoader('Archivo');
  archivo.addFont(loadFile('assets/fonts/Archivo-Regular.ttf'));
  archivo.addFont(loadFile('assets/fonts/Archivo-Medium.ttf'));
  archivo.addFont(loadFile('assets/fonts/Archivo-SemiBold.ttf'));
  archivo.addFont(loadFile('assets/fonts/Archivo-Bold.ttf'));
  archivo.addFont(loadFile('assets/fonts/Archivo-ExtraBold.ttf'));
  await archivo.load();

  final mono = FontLoader('IBMPlexMono');
  mono.addFont(loadFile('assets/fonts/IBMPlexMono-Medium.ttf'));
  await mono.load();

  final bricolage = FontLoader('Bricolage Grotesque');
  bricolage.addFont(loadFile('assets/fonts/Archivo-ExtraBold.ttf'));
  await bricolage.load();

  final instrument = FontLoader('Instrument Sans');
  instrument.addFont(loadFile('assets/fonts/Archivo-Regular.ttf'));
  await instrument.load();

  final jetbrains = FontLoader('JetBrains Mono');
  jetbrains.addFont(loadFile('assets/fonts/IBMPlexMono-Medium.ttf'));
  await jetbrains.load();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'api.critalarm.app',
      'admin_token': 'adm_demo_token',
    });
    await configureDependencies();
    await _loadFonts();
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
    ('12_device_permissions', '/settings/permissions', FaceState.calm),
  ];

  for (final (filename, routePath, fixtureState) in screens) {
    testWidgets('Capture $filename at $routePath', (tester) async {
      getIt<MockServer>().loadFixture(fixtureState);

      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
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
    });
  }
}
