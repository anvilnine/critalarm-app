// Captures every screen at tablet, foldable and desktop sizes, light and dark,
// from the real widgets on the mock server, and writes a contact sheet.
//
//   make screens-responsive
//   fvm flutter test tool/capture_responsive_matrix.dart --reporter=compact
//
// A tool, not a test: nothing under test/ runs it and its output stays out of
// this repo. Environment, every value optional and comma separated:
//
//   SIZES=ipad-11-landscape,desktop-1440   only these size ids (see _sizes)
//   SCREENS=04_home_face,10_settings       only these screen ids
//   THEMES=light                           light, dark or both
//   OUT=/abs/dir                           where the files go (default below)
//
// Output:
//
//   <OUT>/<size-id>/<theme>/<screen>.png   one capture, device pixel ratio 2
//   <OUT>/errors.json                      every FlutterError, first line only
//   <OUT>/run-log.txt                      what was captured, skipped, broken
//   <OUT>/index.html                       the contact sheet
//
// errors.json keeps the entries of captures this run did not repeat, so a
// subset run into the same folder updates only its own rows. The contact
// sheet is drawn from the PNGs on disk, so it shows earlier captures too.
//
// The screens are the list in tool/capture_routes.dart, which
// tool/capture_all_screens.dart also draws, plus Home with a topic picked and
// History with an entry picked (only where AppSize gives two panes), plain
// History, and the web message composer on the desktop sizes.
//
// Each size boots the app's dependencies again and then registers the
// PlatformCapabilities that size renders as, the value lib/app/di.dart builds
// on that platform. A web size gets `isWeb: true` (no push, no alarm, compose
// on). Other `kIsWeb` reads in lib/app/di.dart (the local store, the native
// locale bridge, the onboarding platform) still see a native build, because
// a widget test cannot change that constant.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';
import 'capture_routes.dart';

const _defaultOut =
    '/Users/pat/Projects/anvilnine/crit-alarm/critalarm-planning/docs/'
    'superpowers/plans/2026-10-28-tablet-desktop-layouts/captures/baseline';

const double _ratio = 2;

// ---------------------------------------------------------------------------
// Sizes
// ---------------------------------------------------------------------------

enum _Renders { ios, android, web }

class _Size {
  const _Size(
    this.id,
    this.width,
    this.height,
    this.renders, {
    this.isIphone = false,
    this.textScale = 1,
    this.hingeX,
    this.hingeY,
    this.note,
  });

  final String id;
  final double width;
  final double height;
  final _Renders renders;
  final bool isIphone;
  final double textScale;

  /// A vertical fold, half opened, at this x (logical pixels).
  final double? hingeX;

  /// A horizontal fold, half opened, at this y (logical pixels).
  final double? hingeY;

  /// Shown on the contact sheet under the size id.
  final String? note;

  TargetPlatform get platform => switch (renders) {
    _Renders.ios => TargetPlatform.iOS,
    _Renders.android => TargetPlatform.android,
    // What a desktop browser on a Mac reports.
    _Renders.web => TargetPlatform.macOS,
  };

  bool get isTwoPane => AppSize(width, height, isIphone: isIphone).isExpanded;

  /// The fold as the platform reports it: physical pixels, zero thickness.
  List<ui.DisplayFeature> get displayFeatures {
    Rect? line;
    if (hingeX != null) {
      line = Rect.fromLTWH(hingeX! * _ratio, 0, 0, height * _ratio);
    } else if (hingeY != null) {
      line = Rect.fromLTWH(0, hingeY! * _ratio, width * _ratio, 0);
    }
    if (line == null) return const [];
    return [
      ui.DisplayFeature(
        bounds: line,
        type: ui.DisplayFeatureType.fold,
        state: ui.DisplayFeatureState.postureHalfOpened,
      ),
    ];
  }

  String get summary {
    final parts = <String>[
      '${width.round()} x ${height.round()}',
      switch (renders) {
        _Renders.ios => isIphone ? 'iOS iPhone' : 'iOS iPad',
        _Renders.android => 'Android',
        _Renders.web => 'web',
      },
      if (textScale != 1) 'text $textScale',
      if (hingeX != null) 'fold at x ${hingeX!.round()}',
      if (hingeY != null) 'fold at y ${hingeY!.round()}',
    ];
    return parts.join(', ');
  }
}

const List<_Size> _sizes = [
  _Size('phone', 390, 844, _Renders.ios, isIphone: true, note: 'reference'),
  _Size('ipad-mini-portrait', 744, 1133, _Renders.ios),
  _Size('ipad-11-portrait', 834, 1194, _Renders.ios),
  _Size('ipad-11-landscape', 1194, 834, _Renders.ios),
  _Size('ipad-13-landscape', 1366, 1024, _Renders.ios),
  _Size('android-tablet-portrait', 800, 1280, _Renders.android),
  _Size('android-tablet-landscape', 1280, 800, _Renders.android),
  _Size('desktop-1280', 1280, 800, _Renders.web),
  _Size('desktop-1440', 1440, 900, _Renders.web),
  _Size('desktop-1920', 1920, 1080, _Renders.web),
  _Size('ipad-11-portrait-text13', 834, 1194, _Renders.ios, textScale: 1.3),
  _Size('galaxy-fold-cover', 344, 882, _Renders.android),
  _Size('galaxy-fold-inner-portrait', 690, 829, _Renders.android),
  _Size('galaxy-fold-inner-landscape', 829, 690, _Renders.android),
  _Size('galaxy-fold-book', 690, 829, _Renders.android, hingeX: 345),
  _Size('pixel-fold-cover', 411, 797, _Renders.android),
  _Size('pixel-fold-inner', 841, 701, _Renders.android),
  _Size('pixel-fold-tabletop', 841, 701, _Renders.android, hingeY: 350),
  _Size('razr-cover', 384, 388, _Renders.android),
  _Size(
    'iphone-fold-unfolded',
    720,
    900,
    _Renders.ios,
    isIphone: true,
    note: 'assumed size, no device with public numbers yet',
  ),
];

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

enum _Pick { none, firstTopic, firstHistoryEntry }

class _Screen {
  const _Screen(
    this.id,
    this.path,
    this.fixture, {
    this.pinned,
    this.pick = _Pick.none,
    this.webOnly = false,
    this.missing,
  });

  final String id;
  final String path;
  final FaceState fixture;

  /// Opened directly instead of walked to from home. See CaptureRoute.
  final TargetPlatform? pinned;

  /// A row to tap once the screen has drawn.
  final _Pick pick;

  final bool webOnly;

  /// Why this screen cannot be drawn in this build. Logged, never captured.
  final String? missing;

  /// Why this cell is left out at [size], or null when it is captured.
  String? skipAt(_Size size) {
    if (webOnly && size.renders != _Renders.web) {
      return 'web only, captured at the desktop sizes';
    }
    if (pick != _Pick.none && !size.isTwoPane) {
      return 'one pane at this size, a tap opens the full screen';
    }
    return null;
  }
}

final List<_Screen> _screens = [
  for (final (id, path, fixture, pinned) in allScreenRoutes)
    _Screen(id, path, fixture, pinned: pinned),
  const _Screen(
    '16_home_topic_selected',
    '/',
    FaceState.worried,
    pick: _Pick.firstTopic,
  ),
  const _Screen('17_history', '/history', FaceState.acked),
  const _Screen(
    '18_history_selected',
    '/history',
    FaceState.acked,
    pick: _Pick.firstHistoryEntry,
  ),
  const _Screen(
    '19_message_composer',
    '/compose',
    FaceState.calm,
    webOnly: true,
    missing:
        'no composer route in lib/app/router.dart. '
        'PlatformCapabilities.canComposeMessages exists, but no screen or '
        'route uses it, and the compose button opens /topics/new',
  ),
];

// ---------------------------------------------------------------------------
// Run state
// ---------------------------------------------------------------------------

String _env(String key) => (Platform.environment[key] ?? '').trim();

Set<String> _list(String key) => _env(
  key,
).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

typedef _Err = ({String size, String theme, String screen, String message});

final _errors = <_Err>[];
final _captured = <String>{};
final _log = <String>[];
final _broken = <String, String>{};

String _cell(String size, String theme, String screen) =>
    '$size/$theme/$screen';

String _docsPath = '';

Future<void> _boot(_Size size) async {
  await getIt.reset();
  // After the translations: loading them resets the mock preferences.
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    // A registered device on the free plan, so History has a plan to read
    // its window from.
    'device_id': 'dev_capture',
    'device_token': 'dv_capture',
    'account_id': 'acc_capture',
    'account_tier': 'free',
    'account_caps':
        '{"devices":5,"critical_topics":2,"p4_daily":50,"history_days":7}',
    // A set-up user: no checklist, no feature guide over the screen.
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  // A fresh phone store per size, on a real SQLite file. Without it History
  // has nothing to list.
  _docsPath = Directory.systemTemp.createTempSync('critalarm_matrix_').path;
  await configureDependencies(useMockApi: true);
  // What lib/app/di.dart registers on the platform this size renders as.
  getIt
    ..unregister<PlatformCapabilities>()
    ..registerSingleton<PlatformCapabilities>(
      PlatformCapabilities(
        isWeb: size.renders == _Renders.web,
        platform: size.platform,
      ),
    );
  // Settings leads with the phone's own checks. Under a test clock that read
  // never comes back, so read it once here, in real time.
  await getIt<ReliabilityCubit>().refresh();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    // Cubits that await a platform channel or the mock server need real
    // time, not pumped time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<String?> _tapPick(WidgetTester tester, _Pick pick) async {
  final finder = switch (pick) {
    _Pick.none => null,
    _Pick.firstTopic => find.byType(AppInboxRow),
    _Pick.firstHistoryEntry => find.byType(HistoryRow),
  };
  if (finder == null) return null;
  if (finder.evaluate().isEmpty) return 'no row on screen to pick';
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
  return null;
}

// ---------------------------------------------------------------------------
// Output files
// ---------------------------------------------------------------------------

void _writeErrors(Directory out) {
  final file = File('${out.path}/errors.json');
  final kept = <Map<String, Object?>>[];
  if (file.existsSync()) {
    try {
      final old = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      for (final e in old.cast<Map<String, dynamic>>()) {
        final key = _cell('${e['size']}', '${e['theme']}', '${e['screen']}');
        if (!_captured.contains(key)) kept.add(e);
      }
    } on Object catch (e) {
      print('warning: could not read the old errors.json, replacing it: $e');
    }
  }
  final all =
      [
        ...kept,
        for (final e in _errors)
          {
            'size': e.size,
            'theme': e.theme,
            'screen': e.screen,
            'message': e.message,
          },
      ]..sort(
        (a, b) => _cell(
          '${a['size']}',
          '${a['theme']}',
          '${a['screen']}',
        ).compareTo(_cell('${b['size']}', '${b['theme']}', '${b['screen']}')),
      );
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(all)}\n',
  );
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _css = '''
body{margin:0;padding:16px 24px;background:#fff;color:#111;font:14px/1.4 -apple-system,system-ui,sans-serif}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:17px;margin:32px 0 8px;padding-top:12px;border-top:1px solid #ddd}
h2 code{font-weight:400;color:#555;font-size:13px}
h3{font-size:14px;margin:12px 0 6px;color:#333}
.row{display:flex;gap:14px;overflow-x:auto;padding-bottom:8px;align-items:flex-start}
figure{margin:0;flex:none}
figure img{height:300px;display:block;border:1px solid #ccc;background:#f4f4f4}
.gap{height:300px;width:150px;border:1px dashed #bbb;color:#777;display:flex;align-items:center;justify-content:center;text-align:center;padding:8px;box-sizing:border-box;font-size:12px}
figcaption{font-size:12px;margin-top:4px;max-width:340px}
figcaption b{font-weight:600}
.meta{color:#666}
.err{color:#c00;margin-top:2px;word-break:break-word}
nav a{margin-right:10px}
''';

void _writeIndex(Directory out) {
  final errorsFile = File('${out.path}/errors.json');
  final errors = <String, List<String>>{};
  if (errorsFile.existsSync()) {
    final list = jsonDecode(errorsFile.readAsStringSync()) as List<dynamic>;
    for (final e in list.cast<Map<String, dynamic>>()) {
      errors
          .putIfAbsent(
            _cell('${e['size']}', '${e['theme']}', '${e['screen']}'),
            () => [],
          )
          .add('${e['message']}');
    }
  }

  var shots = 0;
  final b = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="en"><head><meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<title>Responsive capture matrix</title>')
    ..writeln('<style>$_css</style></head><body>')
    ..writeln('<h1>Responsive capture matrix</h1>')
    ..writeln(
      '<p class="meta">Generated ${DateTime.now().toUtc().toIso8601String()} '
      'by tool/capture_responsive_matrix.dart. Device pixel ratio 2. '
      'Click an image for the full-size file. Red lines are FlutterErrors '
      'from errors.json.</p>',
    )
    ..write('<nav>');
  for (final s in _screens) {
    b.write('<a href="#${_esc(s.id)}">${_esc(s.id)}</a>');
  }
  b.writeln('</nav>');

  for (final screen in _screens) {
    b.writeln(
      '<h2 id="${_esc(screen.id)}">${_esc(screen.id)} '
      '<code>${_esc(screen.path)}</code></h2>',
    );
    if (screen.missing != null) {
      b.writeln(
        '<p class="err">Could not render: ${_esc(screen.missing!)}</p>',
      );
    }
    for (final theme in const ['light', 'dark']) {
      b
        ..writeln('<h3>$theme</h3>')
        ..writeln('<div class="row">');
      for (final size in _sizes) {
        final rel = '${size.id}/$theme/${screen.id}.png';
        final label =
            '<figcaption><b>${_esc(size.id)}</b><br>'
            '<span class="meta">${_esc(size.summary)}'
            '${size.note == null ? '' : '<br>${_esc(size.note!)}'}'
            '</span>';
        final skip = screen.skipAt(size);
        if (File('${out.path}/$rel').existsSync()) {
          shots++;
          final alt = '${screen.id} $theme ${size.id}';
          b.write(
            '<figure><a href="${_esc(rel)}"><img loading="lazy" '
            'src="${_esc(rel)}" alt="${_esc(alt)}"></a>$label',
          );
          final cellErrors =
              errors[_cell(size.id, theme, screen.id)] ?? const <String>[];
          for (final m in cellErrors) {
            b.write('<div class="err">${_esc(m)}</div>');
          }
          b.writeln('</figcaption></figure>');
        } else if (skip != null) {
          // Cells that never apply are left out so the row stays short.
          continue;
        } else {
          final why = screen.missing != null
              ? 'could not render'
              : 'not captured yet';
          b.writeln(
            '<figure><div class="gap">$why</div>$label</figcaption></figure>',
          );
        }
      }
      b.writeln('</div>');
    }
  }
  b.writeln('</body></html>');
  File('${out.path}/index.html').writeAsStringSync(b.toString());
  print('Wrote ${out.path}/index.html with $shots captures');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final out = Directory(_env('OUT').isEmpty ? _defaultOut : _env('OUT'));
  final wantSizes = _list('SIZES');
  final wantScreens = _list('SCREENS');
  final wantThemes = _list('THEMES');

  final unknown = [
    ...wantSizes.where((id) => !_sizes.any((s) => s.id == id)),
    ...wantScreens.where((id) => !_screens.any((s) => s.id == id)),
    ...wantThemes.where((t) => t != 'light' && t != 'dark'),
  ];
  if (unknown.isNotEmpty) {
    throw ArgumentError(
      'Unknown SIZES, SCREENS or THEMES value: ${unknown.join(', ')}.\n'
      'Sizes: ${_sizes.map((s) => s.id).join(', ')}\n'
      'Screens: ${_screens.map((s) => s.id).join(', ')}',
    );
  }

  final sizes = [
    for (final s in _sizes)
      if (wantSizes.isEmpty || wantSizes.contains(s.id)) s,
  ];
  final screens = [
    for (final s in _screens)
      if (wantScreens.isEmpty || wantScreens.contains(s.id)) s,
  ];
  final themes = [
    for (final t in const [ThemeMode.light, ThemeMode.dark])
      if (wantThemes.isEmpty || wantThemes.contains(t.name)) t,
  ];
  final clock = Stopwatch();

  setUpAll(() async {
    clock.start();
    await loadTestTranslations();
    await loadAppFonts();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => _docsPath,
        );
    out.createSync(recursive: true);
  });

  tearDownAll(() {
    _writeErrors(out);
    _writeIndex(out);
    final withErrors = {
      for (final e in _errors) _cell(e.size, e.theme, e.screen),
    };
    final summary = [
      'captures written: ${_captured.length}',
      'captures with errors: ${withErrors.length}',
      'FlutterErrors recorded: ${_errors.length}',
      'routes that could not render: ${_broken.length}',
      for (final MapEntry(:key, :value) in _broken.entries) '  $key: $value',
      'wall time: ${clock.elapsed.inSeconds} s',
    ];
    File('${out.path}/run-log.txt').writeAsStringSync(
      '${[..._log, '', ...summary].join('\n')}\n',
    );
    summary.forEach(print);
  });

  for (final size in sizes) {
    group(size.id, () {
      setUpAll(() => _boot(size));

      for (final theme in themes) {
        for (final screen in screens) {
          final rel = _cell(size.id, theme.name, screen.id);
          final skip = screen.skipAt(size);
          if (skip != null) {
            _log.add('skipped  $rel: $skip');
            continue;
          }
          if (screen.missing != null) {
            _log.add('broken   $rel: ${screen.missing}');
            _broken[screen.id] = screen.missing!;
            continue;
          }
          testWidgets('capture $rel', (tester) async {
            final messages = <String>{};
            void record(String message) {
              final first = message.trim().split('\n').first;
              if (messages.add(first)) {
                _errors.add((
                  size: size.id,
                  theme: theme.name,
                  screen: screen.id,
                  message: first,
                ));
              }
            }

            final oldHandler = FlutterError.onError;
            FlutterError.onError = (d) => record(d.exceptionAsString());
            debugDefaultTargetPlatformOverride = size.platform;
            try {
              getIt<MockServer>().loadFixture(screen.fixture);
              tester.view
                ..physicalSize = Size(size.width, size.height) * _ratio
                ..devicePixelRatio = _ratio
                ..displayFeatures = size.displayFeatures;
              tester.platformDispatcher.textScaleFactorTestValue =
                  size.textScale;
              addTearDown(tester.view.reset);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );

              // The shared cubits outlive one capture, so they reload from
              // the freshly seeded mock before the screen reads them.
              await tester.runAsync(() async {
                await getIt<TopicsCubit>().refresh();
                await getIt<IncidentsCubit>().refresh(full: true);
              });

              final boundary = GlobalKey();
              final router = screen.pinned == null
                  ? buildRouter()
                  : buildRouter(initialLocation: screen.path);

              // The same cubits and scopes lib/app/app.dart puts above its
              // router.
              await tester.pumpWidget(
                MultiBlocProvider(
                  providers: [
                    BlocProvider<IncidentsCubit>.value(
                      value: getIt<IncidentsCubit>(),
                    ),
                    BlocProvider<TopicsCubit>.value(
                      value: getIt<TopicsCubit>(),
                    ),
                    BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
                    BlocProvider<AppearanceCubit>.value(
                      value: getIt<AppearanceCubit>(),
                    ),
                  ],
                  child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: buildLightTheme(),
                    darkTheme: buildDarkTheme(),
                    themeMode: theme,
                    routerConfig: router,
                    builder: (context, child) => RepaintBoundary(
                      key: boundary,
                      child: AppDeviceScope(
                        isIphone: size.isIphone,
                        child: AppAmbientShell(
                          router: router,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (screen.pinned == null) router.go(screen.path);
              await _settle(tester);
              final pickProblem = await _tapPick(tester, screen.pick);
              if (pickProblem != null) record('capture note: $pickProblem');

              await tester.runAsync(() async {
                final render =
                    boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await render.toImage(pixelRatio: _ratio);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File('${out.path}/$rel.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(data!.buffer.asUint8List());
              });
              _captured.add(rel);
              _log.add(
                '${messages.isEmpty ? 'ok      ' : 'errors  '} $rel'
                '${messages.isEmpty ? '' : ' (${messages.length})'}',
              );
              print('captured $rel${messages.isEmpty ? '' : ' with errors'}');

              // A screen can start a timer as it closes. Take the tree down
              // and let those run out, or the test ends with one pending.
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 1));
            } on Object catch (e) {
              record('capture failed: $e');
              _broken.putIfAbsent(
                screen.id,
                () => '$e'.split('\n').first,
              );
              _log.add('failed   $rel: ${'$e'.split('\n').first}');
              print('FAILED $rel: $e');
            } finally {
              FlutterError.onError = oldHandler;
              // Reset inside the test body: the framework checks this before
              // any tear-down callback runs.
              debugDefaultTargetPlatformOverride = null;
            }
          });
        }
      }
    });
  }
}
