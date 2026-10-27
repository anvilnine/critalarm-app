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
//   THEMES=light                           light or dark (unset: both)
//   OUT=/abs/dir                           where the files go (default below)
//   FOLD_GUIDE=1                           draw the fold as a 1 px guide line
//                                          on the hinge rows
//
// Output:
//
//   <OUT>/<size-id>/<theme>/<screen>.png   one capture, device pixel ratio 2
//   <OUT>/errors.json                      every FlutterError, note and failure
//   <OUT>/run-log.txt                      what was captured, skipped, broken
//   <OUT>/index.html                       the contact sheet
//
// errors.json keeps the entries of captures this run did not repeat, so a
// subset run into the same folder updates only its own rows. The contact
// sheet is drawn from the PNGs on disk, so it shows earlier captures too.
//
// The screens are allScreenRoutes in tool/capture_routes.dart, which
// tool/capture_all_screens.dart also draws, then responsiveScreenRoutes and
// the tap routes from the same file, which only this tool draws, plus Home
// with a topic picked and History with an entry picked (only where the
// scaffold shows a detail pane: AppScreenScaffold.showsDetailFor), plain
// History, and the web message composer on the desktop sizes.
//
// Each capture boots the app's dependencies again and then registers the
// PlatformCapabilities that size renders as, the value lib/app/di.dart builds
// on that platform. A web size gets `isWeb: true` (no push, no alarm, compose
// on). Other `kIsWeb` reads in lib/app/di.dart (the local store, the native
// locale bridge, the onboarding platform) still see a native build, because
// a widget test cannot change that constant. The override also comes after
// configureDependencies, so anything that build resolved already, such as
// the ReliabilityCubit and the services it reads, keeps the native value.
//
// Each errors.json entry has a `kind`: `flutter_error` (a FlutterError the
// screen raised), `note` (the tool could not do a step, such as finding a row
// to pick, or a geometry check failed), `failed` (the capture threw) or
// `fold_overlap` (on a hinge row, a text, button or face overlaps the fold
// band at scroll 0; see tool/fold_clearance.dart). A fold_overlap entry also
// carries `widget`, `label`, `rect` ([left, top, right, bottom]) and `chrome`
// (true for the shell's tab bar or rail). Notes show in grey on the sheet.
//
// Every capture measures the tab bar and the rail from the render tree and
// prints the numbers (`geometry ...` lines, also in run-log.txt), with a
// PASS or FAIL for the rules that apply at that size: the bar left of the
// band in book posture, the rail below the band in tabletop posture, the rail
// inside the 1600 frame on a wider window, the cover bar 8 above the safe
// area and icons only, and two panes on Home where the size is expanded.
//
// The clock is not pinned. Screens and the mock fixtures read DateTime.now()
// and lib/ has no clock to swap, so times, "Today" labels and relative ages
// change from run to run. A comparison between two runs must ignore them.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:async';
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
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'alarm_geometry.dart';
import 'capture_fonts.dart';
import 'capture_routes.dart';
import 'capture_settings_checks.dart';
import 'fold_clearance.dart';
import 'paywall_geometry.dart';
import 'wp3_geometry.dart';
import 'wp6_geometry.dart';

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

  /// True where a screen with a detail shows it beside the list, by the
  /// scaffold's own rule: book posture at any width, or an expanded window
  /// that is not in tabletop posture.
  bool get isTwoPane => AppScreenScaffold.showsDetailFor(
    AppSize(width, height, isIphone: isIphone),
    AppFold.fromFeatures(displayFeatures, Size(width, height)),
  );

  /// The fold as the platform reports it: zero thickness, in logical pixels
  /// (the engine divides by the device pixel ratio before Flutter sees it).
  Rect? get hingeLine {
    if (hingeX != null) return Rect.fromLTWH(hingeX!, 0, 0, height);
    if (hingeY != null) return Rect.fromLTWH(0, hingeY!, width, 0);
    return null;
  }

  List<ui.DisplayFeature> get displayFeatures {
    final line = hingeLine;
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
  _Size(
    'galaxy-fold-book-text13',
    690,
    829,
    _Renders.android,
    hingeX: 345,
    textScale: 1.3,
  ),
  _Size('pixel-fold-cover', 411, 797, _Renders.android),
  _Size('pixel-fold-inner', 841, 701, _Renders.android),
  _Size('pixel-fold-tabletop', 841, 701, _Renders.android, hingeY: 350),
  _Size('pixel-fold-inner-book', 841, 701, _Renders.android, hingeX: 420),
  _Size('razr-cover', 384, 388, _Renders.android),
  _Size('razr-cover-text13', 384, 388, _Renders.android, textScale: 1.3),
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

enum _Pick { none, firstTopic, firstHistoryEntry, acknowledge, text }

class _Screen {
  const _Screen(
    this.id,
    this.path,
    this.fixture, {
    this.pinned,
    this.pick = _Pick.none,
    this.webOnly = false,
    this.missing,
    this.pickBeforeChecks = false,
    this.pushAfter,
    this.popAfter = false,
    this.tapKey,
    this.paneTapKey,
  });

  /// A location pushed once [path] has drawn, the way a button on that
  /// screen would push it.
  final String? pushAfter;

  /// Pops the top page once [pushAfter] has drawn: the back button.
  final bool popAfter;

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

  /// The tap opens the screen this cell is about, so the measuring and the
  /// fold walk run after it instead of before.
  final bool pickBeforeChecks;

  /// The `LocaleKeys` key of the text a [_Pick.text] screen taps.
  final String? tapKey;

  /// The `LocaleKeys` key of the text tapped next, inside the detail pane,
  /// where there is one. See `paneTapRoutes`.
  final String? paneTapKey;

  /// Why this cell is left out at [size], or null when it is captured.
  String? skipAt(_Size size) {
    if (webOnly && size.renders != _Renders.web) {
      return 'web only, captured at the desktop sizes';
    }
    if (pinned != null && pinned != size.platform) {
      return 'pinned to ${pinned!.name}, captured only at those sizes';
    }
    if ((pick == _Pick.firstTopic || pick == _Pick.firstHistoryEntry) &&
        !size.isTwoPane) {
      return 'one pane at this size, a tap opens the full screen';
    }
    return null;
  }
}

final List<_Screen> _screens = [
  for (final (id, path, fixture, pinned) in [
    ...allScreenRoutes,
    ...responsiveScreenRoutes,
  ])
    _Screen(id, path, fixture, pinned: pinned),
  for (final (id, path, fixture, tapKey) in tapScreenRoutes)
    _Screen(
      id,
      path,
      fixture,
      pick: _Pick.text,
      tapKey: tapKey,
      paneTapKey: paneTapRoutes[id],
    ),
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
  // Read message on the ringing alarm pushes the topic: on an expanded
  // window the alarm must stay on the stack under it.
  const _Screen(
    'wp3_alarm_read_message',
    '/alarm',
    FaceState.alarmed,
    pushAfter: '/topics/nas-backup',
  ),
  // All messages from Home's pane (prod-db, the first topic), then back:
  // Home with the pane, never a lone topic page.
  const _Screen(
    'wp3_messages_back',
    '/',
    FaceState.calm,
    pushAfter: '/topics/prod-db/messages',
    popAfter: true,
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
  for (final (id, path, fixture) in acknowledgedCaptureRoutes)
    _Screen(
      id,
      path,
      fixture,
      pick: _Pick.acknowledge,
      pickBeforeChecks: true,
    ),
];

// ---------------------------------------------------------------------------
// Run state
// ---------------------------------------------------------------------------

String _env(String key) => (Platform.environment[key] ?? '').trim();

Set<String> _list(String key) => _env(
  key,
).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

typedef _Err = ({
  String size,
  String theme,
  String screen,
  String kind,
  String message,
  Map<String, Object?> extra,
});

const _flutterError = 'flutter_error';
const _note = 'note';
const _failed = 'failed';
const _foldOverlap = 'fold_overlap';

bool get _foldGuide => _env('FOLD_GUIDE') == '1';

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
  // A fresh phone store per capture, on a real SQLite file. Without it History
  // has nothing to list. The last capture's folder goes first.
  if (_docsPath.isNotEmpty) {
    try {
      Directory(_docsPath).deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  }
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

Future<String?> _tapPick(
  WidgetTester tester,
  _Pick pick, {
  String? tapKey,
  bool inPane = false,
}) async {
  final finder = switch (pick) {
    _Pick.none => null,
    _Pick.firstTopic => find.byType(AppInboxRow),
    _Pick.firstHistoryEntry => find.byType(HistoryRow),
    _Pick.acknowledge => find.widgetWithText(
      AppButton,
      LocaleKeys.critical_alarm_acknowledge_button.tr(),
    ),
    _Pick.text => find.text(tapKey!.tr()),
  };
  if (finder == null) return null;
  if (finder.evaluate().isEmpty) return 'no row on screen to pick';
  var target = finder.first;
  if (pick == _Pick.text) {
    // The text of a row in the list on top, not the same words on a page
    // beside it in a detail pane or on a screen under the top route. With
    // [inPane], the other way round: the words on the page in the pane.
    final inList = finder.evaluate().where(
      (e) =>
          (e.findAncestorWidgetOfExactType<AppDetailPane>() != null) ==
              inPane &&
          (ModalRoute.of(e)?.isCurrent ?? true),
    );
    if (inList.isEmpty) {
      return inPane ? 'no text in the pane to tap' : 'no row on screen to pick';
    }
    final chosen = inList.first;
    target = find.byElementPredicate((e) => e == chosen);
    // A small screen can hold the text below the fold of the list. Bring it
    // to the middle, clear of the bars that float over the list's edges.
    unawaited(Scrollable.ensureVisible(chosen, alignment: 0.5));
    await tester.pump();
  }
  await tester.tap(target, warnIfMissed: false);
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
            'kind': e.kind,
            'message': e.message,
            ...e.extra,
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
.note{color:#777;margin-top:2px;word-break:break-word}
nav a{margin-right:10px}
''';

void _writeIndex(Directory out) {
  final errorsFile = File('${out.path}/errors.json');
  final errors = <String, List<(String, String)>>{};
  if (errorsFile.existsSync()) {
    final list = jsonDecode(errorsFile.readAsStringSync()) as List<dynamic>;
    for (final e in list.cast<Map<String, dynamic>>()) {
      errors
          .putIfAbsent(
            _cell('${e['size']}', '${e['theme']}', '${e['screen']}'),
            () => [],
          )
          .add(('${e['kind'] ?? _flutterError}', '${e['message']}'));
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
      'and failed captures from errors.json. Grey lines are tool notes. '
      'Times on screen are the run time, not pinned.</p>',
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
              errors[_cell(size.id, theme, screen.id)] ??
              const <(String, String)>[];
          for (final (kind, m) in cellErrors) {
            final css = kind == _note ? 'note' : 'err';
            b.write('<div class="$css">${_esc(m)}</div>');
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
    if (_docsPath.isNotEmpty) {
      try {
        Directory(_docsPath).deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    }
    _writeErrors(out);
    _writeIndex(out);
    final flutterErrors = _errors.where((e) => e.kind == _flutterError);
    final withErrors = {
      for (final e in flutterErrors) _cell(e.size, e.theme, e.screen),
    };
    final folds = _errors.where((e) => e.kind == _foldOverlap);
    final chromeFolds = folds.where((e) => e.extra['chrome'] == true).length;
    final summary = [
      'captures written: ${_captured.length}',
      'captures with errors: ${withErrors.length}',
      'FlutterErrors recorded: ${flutterErrors.length}',
      'notes: ${_errors.where((e) => e.kind == _note).length}',
      'failed captures: ${_errors.where((e) => e.kind == _failed).length}',
      'fold overlaps: ${folds.length} ($chromeFolds in shell chrome)',
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
          // A fresh boot per capture, in a group of its own so it runs in
          // real time. Shared singletons outlive a screen: once the alarm
          // screen has rung, every later tab screen hands over to it.
          group(rel, () {
            setUpAll(() => _boot(size));
            testWidgets('capture', (tester) async {
              final messages = <String>{};
              void record(
                String message, {
                String kind = _flutterError,
                Map<String, Object?> extra = const {},
              }) {
                final first = message.trim().split('\n').first;
                if (messages.add(first)) {
                  _errors.add((
                    size: size.id,
                    theme: theme.name,
                    screen: screen.id,
                    kind: kind,
                    message: first,
                    extra: extra,
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
                      BlocProvider<ThemeCubit>.value(
                        value: getIt<ThemeCubit>(),
                      ),
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
                        child: Stack(
                          textDirection: TextDirection.ltr,
                          children: [
                            AppDeviceScope(
                              isIphone: size.isIphone,
                              child: AppAmbientShell(
                                router: router,
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                            if (_foldGuide && size.hingeLine != null)
                              Positioned.fromRect(
                                rect: _guideRect(size.hingeLine!),
                                child: const IgnorePointer(
                                  child: ColoredBox(color: Color(0xFFFF00C8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                if (screen.pinned == null) router.go(screen.path);
                await _settle(tester);
                if (screen.pushAfter case final pushed?) {
                  unawaited(router.push<void>(pushed));
                  await _settle(tester);
                  if (screen.popAfter) {
                    router.pop();
                    await _settle(tester);
                  }
                }
                // The fold must reach the screens where the size puts it.
                final line = size.hingeLine;
                if (line != null) {
                  final seen = MediaQuery.of(
                    boundary.currentContext!,
                  ).displayFeatures.map((f) => f.bounds).toList();
                  print('hinge $rel: MediaQuery displayFeatures $seen');
                  if (seen.length != 1 || seen.single != line) {
                    record(
                      'capture note: fold expected at $line, got $seen',
                      kind: _note,
                    );
                  }
                }
                // A tap that opens the screen under test goes first.
                if (screen.pickBeforeChecks) {
                  final pickProblem = await _tapPick(tester, screen.pick);
                  if (pickProblem != null) {
                    record('capture note: $pickProblem', kind: _note);
                  }
                }
                // The geometry the layout rules promise, read off the render
                // tree rather than judged by eye.
                final appSize = AppSize(
                  size.width,
                  size.height,
                  isIphone: size.isIphone,
                );
                final windowFold = AppFold.fromFeatures(
                  size.displayFeatures,
                  Size(size.width, size.height),
                );
                // The route on top: a pushed page's own location, or the
                // tab's when nothing is pushed.
                String location() => router
                    .routerDelegate
                    .currentConfiguration
                    .last
                    .matchedLocation;
                for (final (line, failed) in [
                  ..._measure(tester, size, screen),
                  ...settingsChecksAtRest(
                    tester,
                    screenId: screen.id,
                    size: appSize,
                    fold: windowFold,
                    location: location(),
                  ),
                ]) {
                  print('geometry $rel: $line');
                  _log.add('geometry $rel: $line');
                  if (failed) {
                    record('geometry check failed: $line', kind: _note);
                  }
                }

                // On a hinge row nothing that reads may sit on the fold, at
                // scroll 0, before any pick.
                if (line != null) {
                  final fold = AppFold.fromFeatures(
                    size.displayFeatures,
                    Size(size.width, size.height),
                  );
                  final overlaps = findFoldOverlaps(
                    tester,
                    fold.band,
                    Offset.zero & Size(size.width, size.height),
                  );
                  for (final o in overlaps) {
                    final r = o.rect;
                    final where = o.isChrome ? 'shell chrome' : 'screen body';
                    record(
                      'fold_overlap: ${o.widget}'
                      '${o.label.isEmpty ? '' : ' "${o.label}"'} in $where '
                      'at ${_rectText(r)}',
                      kind: _foldOverlap,
                      extra: {
                        'widget': o.widget,
                        'label': o.label,
                        'rect': [r.left, r.top, r.right, r.bottom],
                        'chrome': o.isChrome,
                      },
                    );
                  }
                  final chrome = overlaps.where((o) => o.isChrome).length;
                  final summary =
                      'fold band ${_rectText(fold.band)}: '
                      '${overlaps.length} overlaps ($chrome in shell chrome)';
                  print('fold $rel: $summary');
                  _log.add('fold     $rel: $summary');
                }

                // The order a screen reader walks the ringing alarm (WP2).
                if (screen.id == '08_critical_alarm') {
                  for (final (line, failed) in await ringingReadingOrder(
                    tester,
                  )) {
                    print('reading  $rel: $line');
                    _log.add('reading  $rel: $line');
                    if (failed) {
                      record('geometry check failed: $line', kind: _note);
                    }
                  }
                }

                // After the walk: the walk reads the screen at scroll 0, and a
                // pick can scroll or open something.
                if (!screen.pickBeforeChecks) {
                  final pickProblem = await _tapPick(
                    tester,
                    screen.pick,
                    tapKey: screen.tapKey,
                  );
                  if (pickProblem != null) {
                    record('capture note: $pickProblem', kind: _note);
                  }
                }
                // The next tap, on the page the first tap opened in the pane.
                if (screen.paneTapKey != null &&
                    AppScreenScaffold.showsDetailFor(appSize, windowFold)) {
                  final paneProblem = await _tapPick(
                    tester,
                    _Pick.text,
                    tapKey: screen.paneTapKey,
                    inPane: true,
                  );
                  if (paneProblem != null) {
                    record('capture note: $paneProblem', kind: _note);
                  }
                }
                for (final (line, failed) in settingsChecksAfterTap(
                  tester,
                  screenId: screen.id,
                  size: appSize,
                  fold: windowFold,
                  location: location(),
                )) {
                  print('geometry $rel: $line');
                  _log.add('geometry $rel: $line');
                  if (failed) {
                    record('geometry check failed: $line', kind: _note);
                  }
                }

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
                  '${messages.isEmpty ? 'ok      ' : 'issues  '} $rel'
                  '${messages.isEmpty ? '' : ' (${messages.length})'}',
                );
                print('captured $rel${messages.isEmpty ? '' : ' with errors'}');

                // A screen can start a timer as it closes. Take the tree down
                // and let those run out, or the test ends with one pending.
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 1));
              } on Object catch (e) {
                record('capture failed: $e', kind: _failed);
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
          });
        }
      }
    });
  }
}

String _rectText(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

/// The 1 px FOLD_GUIDE line along a zero-thickness fold.
Rect _guideRect(Rect line) => line.width == 0
    ? Rect.fromLTWH(line.left - 0.5, line.top, 1, line.height)
    : Rect.fromLTWH(line.left, line.top - 0.5, line.width, 1);

/// The painted box of the one widget of type [T] on screen, or null.
Rect? _paintedOf<T extends Widget>(WidgetTester tester) {
  for (final element in find.byType(T).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null) return rect;
  }
  return null;
}

/// Measures the tab bar, the rail and the panes, and checks them against the
/// rules for [size]. Each line comes with true when its check failed.
List<(String, bool)> _measure(WidgetTester tester, _Size size, _Screen screen) {
  final window = Size(size.width, size.height);
  final appSize = AppSize(size.width, size.height, isIphone: size.isIphone);
  final fold = AppFold.fromFeatures(size.displayFeatures, window);
  // A paywall has no bar: it is measured on its own (WP5).
  final paywall = measurePaywall(
    tester,
    window: window,
    size: appSize,
    fold: fold,
  );
  if (paywall != null) return paywall;
  final bar = _paintedOf<AppFloatingTabBar>(tester);
  final rail = _paintedOf<AppNavRail>(tester);
  final lines = <(String, bool)>[
    // WP6: onboarding and New topic. See tool/wp6_geometry.dart.
    ...wp6Measure(tester, screen.id, window: window, size: appSize, fold: fold),
    // The ringing alarm (WP2): "I'm up" on screen at rest, and the rules of
    // the cover and wide layouts. Nothing when no alarm is on screen.
    ...measureRingingAlarm(tester, window: window, size: appSize, fold: fold),
  ];
  final wp3 = wp3Measure(
    tester,
    sizeId: size.id,
    screenId: screen.id,
    window: window,
    size: appSize,
    fold: fold,
    textScale: size.textScale,
  );
  if (bar == null && rail == null) {
    return [...lines, ('no tab bar or rail on screen', false), ...wp3];
  }

  if (bar != null) {
    final iconsOnly = find
        .byType(AppFloatingTabBar)
        .evaluate()
        .map((e) => (e.widget as AppFloatingTabBar).iconsOnly)
        .first;
    lines.add(('bar ${_rectText(bar)}, icons only $iconsOnly', false));
    if (fold.isBook) {
      final ok = bar.right <= fold.band.left;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} bar right ${bar.right.toStringAsFixed(1)} '
            '<= band left ${fold.band.left.toStringAsFixed(1)}',
        !ok,
      ));
    }
    if (fold.isTabletop) {
      final ok = bar.top >= fold.band.bottom;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} bar top ${bar.top.toStringAsFixed(1)} '
            '>= band bottom ${fold.band.bottom.toStringAsFixed(1)}',
        !ok,
      ));
    }
    if (appSize.isCover) {
      // The test view has no safe area, so the bar sits 8 above the edge.
      final gap = size.height - bar.bottom;
      final ok =
          (gap - AppFloatingTabBar.coverEdgeGap).abs() < 0.5 && iconsOnly;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} cover bar ${gap.toStringAsFixed(1)} above '
            'the safe area (want ${AppFloatingTabBar.coverEdgeGap}), '
            'icons only $iconsOnly',
        !ok,
      ));
    }
  }
  if (rail != null) {
    lines.add(('rail ${_rectText(rail)}', false));
    if (fold.isTabletop) {
      final ok = rail.top >= fold.band.bottom;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} rail top ${rail.top.toStringAsFixed(1)} '
            '>= band bottom ${fold.band.bottom.toStringAsFixed(1)}',
        !ok,
      ));
    }
    if (appSize.frameInset > 0) {
      final ok = rail.left >= appSize.frameInset;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} rail left ${rail.left.toStringAsFixed(1)} '
            '>= frame inset ${appSize.frameInset.toStringAsFixed(1)}',
        !ok,
      ));
    }
  }
  if (screen.id == '04_home_face' &&
      AppScreenScaffold.showsDetailFor(appSize, fold)) {
    final panes = _paintedOf<AppDetailPane>(tester);
    final ok = panes != null;
    lines.add((
      '${ok ? 'PASS' : 'FAIL'} Home shows two panes'
          '${panes == null ? '' : ', detail ${_rectText(panes)}'}',
      !ok,
    ));
  }
  return [...lines, ...wp3];
}
