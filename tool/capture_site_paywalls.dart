// Records the Cloud paywall layouts and the Cloud benefit previews as frame
// sequences, from the real widgets, off the device. Made for the marketing
// site (/pricing), usable for any still or clip of a paywall.
//
//   make site-paywalls                      every id
//   SITE_ONLY=cloud-proof,preview-topics make site-paywalls
//   sh tool/site_paywalls_to_web.sh <out>   frames -> mp4, webm, webp
//
// Ids: one `cloud-<layout>` per layout in PaywallLayoutId (hero, sheet, proof,
// bento, reel, sentence, wipe, doors, receipt; `stage` has no builder and
// falls back to hero, so its frames equal hero's, skip it) and
// `preview-<name>` for the benefit previews (topics, pushes, history,
// weekly-check). Layouts are 1080 x 1920, 30 fps, 6 s, light theme. Previews
// are a square tile on the ambient canvas and play from the start of their
// loop.
//
// Output, in SITE_OUT (default build/site_paywalls, git ignored):
//   <id>/frames/0000.png ...   lossless frames
//   <id>/still.png             the settled frame
//   <id>/meta.json             frames, fps, last_change_frame, errors
//
// Env: SITE_OUT (abs folder), SITE_ONLY (comma list of ids or parts),
// SITE_SECONDS (layout clip length, default 6), SITE_PREVIEW_SECONDS (12).
//
// Things to know:
// - Prices are the mock store's made-up plans (Yearly $39.99, Monthly $4.99),
//   not real store values. Do not present a frame as a store screenshot.
// - Cloud only (`PaywallProduct.hosted`, near the `paywallLayoutLocation`
//   call). Pro needs that product switched and its own ids.
// - No layout needed a scroll to show its rows, so there is no scripted scroll.
// - Needs `make gen` and `make l10n` run once in the worktree.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const double _ratio = 2.625;
const int _fps = 30;
const double _statusBarPt = 40;

String _env(String k, String d) {
  final v = Platform.environment[k];
  return v == null || v.isEmpty ? d : v;
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    final style = SystemChrome.latestStyle;
    final bright = style?.statusBarBrightness;
    final icons = style?.statusBarIconBrightness;
    final light = bright != null
        ? bright == Brightness.dark
        : icons != null && icons == Brightness.light;
    final color = light ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    return IgnorePointer(
      child: SizedBox(
        height: _statusBarPt,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 6, 26, 0),
          child: Row(
            children: [
              Text(
                '3:07',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                  height: 1,
                  color: color,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              CustomPaint(size: const Size(68, 13), painter: _Glyphs(color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glyphs extends CustomPainter {
  const _Glyphs(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    for (var i = 0; i < 4; i++) {
      final h = 4.0 + i * 2.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 4.6, size.height - h, 3.2, h),
          const Radius.circular(0.9),
        ),
        fill,
      );
    }
    final wifi = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const origin = Offset(31, 12.2);
    for (final r in const [4.0, 7.6, 11.2]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: r),
        -math.pi * 0.75,
        math.pi * 0.5,
        false,
        wifi,
      );
    }
    canvas.drawCircle(origin.translate(0, -0.6), 1.4, fill);
    const body = Rect.fromLTWH(43, 1, 22, 11.5);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(3.4)),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(body.deflate(2), const Radius.circular(1.8)),
        fill,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(66.2, 4.6, 1.5, 4.4),
          const Radius.circular(0.8),
        ),
        Paint()..color = color.withValues(alpha: 0.45),
      );
  }

  @override
  bool shouldRepaint(_Glyphs old) => old.color != color;
}

/// Records [seconds] of [boundary] into [dir]/frames (PNG, `outW` x `outH`)
/// plus still.png at full size from the last frame. Writes meta.json.
Future<void> _record(
  WidgetTester tester,
  GlobalKey boundary,
  Directory dir,
  double seconds,
  int fullW,
  int fullH,
  Map<String, Object?> extra,
) async {
  final frames = Directory(p.join(dir.path, 'frames'));
  if (frames.existsSync()) frames.deleteSync(recursive: true);
  frames.createSync(recursive: true);
  final ff = await tester.runAsync(
    () => Process.start('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '${fullW}x$fullH',
      '-framerate',
      '$_fps',
      '-i',
      '-',
      '-vf',
      'scale=${fullW ~/ 2}:${fullH ~/ 2}:flags=lanczos',
      '-start_number',
      '0',
      p.join(frames.path, '%04d.png'),
    ]),
  );
  unawaited(ff!.stderr.transform(utf8.decoder).forEach(stderr.write));
  unawaited(ff.stdout.drain<void>());
  final n = (seconds * _fps).round();
  Uint8List? last;
  var lastChange = 0;
  final errors = <String>[];
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(microseconds: (1e6 / _fps).round()));
    final thrown = tester.takeException();
    if (thrown != null) errors.add('$thrown'.split('\n').first);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: _ratio);
      final data = await image.toByteData();
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (w != fullW || h != fullH) errors.add('frame is ${w}x$h');
      final bytes = data!.buffer.asUint8List();
      if (last == null || !listEquals(last, bytes)) lastChange = i;
      last = Uint8List.fromList(bytes);
      ff.stdin.add(bytes);
      await ff.stdin.flush();
    });
  }
  await tester.runAsync(() async {
    await ff.stdin.close();
    await ff.exitCode;
    // Full size still of the settled (last) frame.
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: _ratio);
    final png = await image.toByteData(format: ImageByteFormat.png);
    File(p.join(dir.path, 'still.png')).writeAsBytesSync(
      png!.buffer.asUint8List(),
    );
    image.dispose();
  });
  final scrollables = <String>[];
  for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
    if (s.position.maxScrollExtent > 0.5) {
      scrollables.add(s.position.maxScrollExtent.toStringAsFixed(1));
    }
  }
  File(p.join(dir.path, 'meta.json')).writeAsStringSync(
    jsonEncode({
      'frames': n,
      'fps': _fps,
      'last_change_frame': lastChange,
      'errors': errors.toSet().toList(),
      'scrollable_extra_points': scrollables,
      ...extra,
    }),
  );
  print(
    '${p.basename(dir.path)}: $n frames, last change at $lastChange'
    '${errors.isEmpty ? '' : ' ERRORS ${errors.toSet()}'}'
    '${scrollables.isEmpty ? '' : ' SCROLL $scrollables'}',
  );
}

void main() {
  final out = Directory(_env('SITE_OUT', 'build/site_paywalls'));
  final only = _env('SITE_ONLY', '');
  final seconds = double.parse(_env('SITE_SECONDS', '6'));
  final previewSeconds = double.parse(_env('SITE_PREVIEW_SECONDS', '12'));

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    final docs = Directory.systemTemp.createTempSync('critalarm_site_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await configureDependencies(useMockApi: true);
    await loadAppFonts();
  });

  bool wanted(String id) =>
      only.isEmpty || only.split(',').any((o) => id.contains(o));

  Future<void> iphone(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    getIt
      ..unregister<PlatformCapabilities>()
      ..registerSingleton<PlatformCapabilities>(
        const PlatformCapabilities(isWeb: false, platform: TargetPlatform.iOS),
      );
  }

  for (final layout in PaywallLayoutId.values) {
    final id = 'cloud-${layout.key}';
    if (!wanted(id)) continue;
    testWidgets('layout $id', (tester) async {
      await iphone(tester);
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = _ratio;
      tester.view.padding = const FakeViewPadding(top: _statusBarPt * _ratio);
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);
      debugDisableShadows = false;
      final boundary = GlobalKey();
      final location = paywallLayoutLocation(layout, PaywallProduct.hosted);
      final router = buildRouter(initialLocation: location);
      await tester.pumpWidget(
        BlocProvider<ThemeCubit>.value(
          value: getIt<ThemeCubit>(),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.light,
            routerConfig: router,
            builder: (context, child) => RepaintBoundary(
              key: boundary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppDeviceScope(
                    isIphone: true,
                    child: AppAmbientShell(
                      router: router,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _StatusBar(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // The route's own open: real time for the mock buy model, no
      // recorded frame. Frame 0 is the first frame pumped after this.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      final dir = Directory(p.join(out.path, id))..createSync(recursive: true);
      await _record(tester, boundary, dir, seconds, 1080, 1920, {
        'id': id,
        'location': location,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      tester.takeException();
      debugDefaultTargetPlatformOverride = null;
      debugDisableShadows = true;
    });
  }

  const previews = <(String, PaywallPreviewId)>[
    ('topics', PaywallPreviewId.topics),
    ('pushes', PaywallPreviewId.pushes),
    ('history', PaywallPreviewId.history),
    ('weekly-check', PaywallPreviewId.weeklyCheck),
  ];
  for (final (name, pid) in previews) {
    final id = 'preview-$name';
    if (!wanted(id)) continue;
    testWidgets('preview $id', (tester) async {
      await iphone(tester);
      tester.view.physicalSize = const Size(1080, 1080);
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      debugDisableShadows = false;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) => RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: context.appColors.canvas,
                child: Center(
                  child: PaywallPreview(pid, size: const Size.square(260)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final dir = Directory(p.join(out.path, id))..createSync(recursive: true);
      await _record(tester, boundary, dir, previewSeconds, 1080, 1080, {
        'id': id,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      tester.takeException();
      debugDefaultTargetPlatformOverride = null;
      debugDisableShadows = true;
    });
  }
}
