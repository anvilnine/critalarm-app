// Records short motion clips of the real app, off the device, for videos.
//
// It boots the app's own dependencies on the mock server, builds the real
// router inside the real ambient shell, and then steps the widget tree one
// frame at a time (1/60 s). Every frame is read off the screen and piped to
// ffmpeg, which writes a PNG sequence and an H.264 mp4. Taps and drags go
// through the test binding as pointer events, so the widgets react as they
// do under a finger, and the tool writes down where and when each one
// happened.
//
// This is a tool, not a test. Run it through `tool/capture_motion.sh`, which
// passes the output folder and the dart-defines. Nothing it writes belongs
// in this repo. It never talks to a server: MOCK is switched on in code.
//
//   sh tool/capture_motion.sh                 every clip
//   MOTION_ONLY=alarm.arrive.standard sh tool/capture_motion.sh
//   MOTION_LIST=1 sh tool/capture_motion.sh   print the clip ids, draw nothing
//
// Environment:
//   MOTION_OUT        where the clips go (the content pipeline's ui-motion)
//   MOTION_ONLY       comma separated clip ids, or parts of ids
//   MOTION_STATUSBAR  0 leaves the drawn status bar out
//   MOTION_W, MOTION_H  the frame in pixels. 1080 and 1920 when unset
//   MOTION_RATIO      pixels per point. 2.625 when unset. The phone is
//                     MOTION_W / MOTION_RATIO points wide
//   MOTION_THEME      the phone's theme. Light unless this is `dark`. Videos
//                     show the app in light mode, so the library is light.
//                     The shell script refuses a dark run into the library.
//   GIT_SHA, GIT_DIRTY  written into manifest.json
//
// Three things on a frame are the tool's and not the app's:
//   - The status bar. A widget tree has none, so the tool draws a plain one
//     in the top inset: the clock, signal, wifi and battery. Its colour
//     follows the overlay style the app asked the system for.
//   - The clock. The tool moves the process time zone so the wall clock
//     reads 3:07 at the start of a clip, because alarm stories happen at
//     night. The alarm screen's own clock is handed pumped time, so
//     "Ringing 3 s." counts one second per sixty frames however long a
//     frame takes to save.
//   - The ringing face. The app picks one of its ringing faces at random.
//     The tool does not pin it, so two runs can show different faces.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_hero_parts.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

part 'capture_motion_clips.dart';

// ---------------------------------------------------------------------------
// The frame
// ---------------------------------------------------------------------------

/// Clips are 1080 x 1920 unless the environment says otherwise: a 411 x 731
/// point phone at 2.625x, the size the still snapshots use
/// (`capture_marketing_screens.dart`, `social916`). MOTION_W, MOTION_H and
/// MOTION_RATIO change the physical size and the pixel ratio. The App Store
/// preview size is MOTION_W=886 MOTION_H=1920 MOTION_RATIO=2.3627, a
/// 375 x 812.6 point phone.
final double _ratio = _envDouble('MOTION_RATIO', 2.625);
final int _widthPx = _envInt('MOTION_W', 1080);
final int _heightPx = _envInt('MOTION_H', 1920);
final double _widthPt = _widthPx / _ratio;
final double _heightPt = _heightPx / _ratio;
const int _fps = 60;

/// The top inset the app lays out under, where the tool draws the status
/// bar. 0 when MOTION_STATUSBAR=0.
const double _statusBarPt = 40;

/// The wall clock at the first frame of every clip, as hours, minutes and
/// seconds. An alarm that has rung 14 s then started at 3:07:02.
const (int, int, int) _clipStartsAt = (3, 7, 16);

String _env(String key, String fallback) {
  final v = Platform.environment[key];
  return v == null || v.isEmpty ? fallback : v;
}

int _envInt(String key, int fallback) {
  final v = _env(key, '');
  if (v.isEmpty) return fallback;
  final n = int.tryParse(v);
  if (n == null || n <= 0) {
    throw ArgumentError('$key is a whole number, not $v');
  }
  return n;
}

double _envDouble(String key, double fallback) {
  final v = _env(key, '');
  if (v.isEmpty) return fallback;
  final n = double.tryParse(v);
  if (n == null || n <= 0) throw ArgumentError('$key is a number, not $v');
  return n;
}

final bool _hasStatusBar = _env('MOTION_STATUSBAR', '1') != '0';

/// The phone's theme for every clip: light, unless MOTION_THEME=dark asks
/// for dark. An alarm look is not a theme: a look that is dark by design
/// (Terminal) stays dark on a light phone, and is recorded as the app
/// draws it.
final String _theme = _env('MOTION_THEME', 'light') == 'dark'
    ? 'dark'
    : 'light';

// ---------------------------------------------------------------------------
// The clock
// ---------------------------------------------------------------------------

/// Moves this process's time zone so the wall clock reads [_clipStartsAt]
/// right now. Dart has no clock to swap under `DateTime.now()`, and the mock
/// server and most screens read it, so the zone is what moves.
void _setWallClockToClipStart() {
  final lib = ffi.DynamicLibrary.process();
  final setenv = lib
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32),
        int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int)
      >('setenv');
  final tzset = lib.lookupFunction<ffi.Void Function(), void Function()>(
    'tzset',
  );
  final utc = DateTime.now().toUtc();
  final (h, m, s) = _clipStartsAt;
  final want = h * 3600 + m * 60 + s;
  final have = utc.hour * 3600 + utc.minute * 60 + utc.second;
  // East of UTC, in seconds, between -12 h and +12 h.
  var east = (want - have) % 86400;
  if (east > 43200) east -= 86400;
  // A POSIX zone counts west, so the sign turns round.
  final sign = east >= 0 ? '-' : '+';
  final a = east.abs();
  String two(int v) => v.toString().padLeft(2, '0');
  final zone =
      'CRT$sign${two(a ~/ 3600)}:${two(a % 3600 ~/ 60)}:${two(a % 60)}';
  final key = 'TZ'.toNativeUtf8();
  final value = zone.toNativeUtf8();
  setenv(key, value, 1);
  tzset();
  malloc
    ..free(key)
    ..free(value);
}

/// Pumped time for the one screen that takes a clock: the alarm screen.
/// It starts at the real time of a clip's first frame and moves one sixtieth
/// of a second per frame.
class _ClipClock {
  DateTime _base = DateTime.now();
  int _frames = 0;

  void restart() {
    _base = DateTime.now();
    _frames = 0;
  }

  void tick() => _frames++;

  DateTime now() =>
      _base.add(Duration(microseconds: (_frames * 1e6 / _fps).round()));

  /// Moves pumped time forward by [by], to meet the real clock.
  void catchUp(Duration by) => _base = _base.add(by);

  /// How far the real clock has run ahead of pumped time. Saving a frame
  /// takes longer than a sixtieth of a second.
  Duration get lag => DateTime.now().difference(now());
}

final _ClipClock _clock = _ClipClock();

// ---------------------------------------------------------------------------
// A clip
// ---------------------------------------------------------------------------

/// What a clip is, for the manifest.
typedef _Clip = ({
  String id,
  String screen,
  String look,
  String? story,
  String theme,
  List<String> features,
  String note,
  Future<void> Function(_Scene scene) run,
});

/// One recording in progress: the frame loop, the gestures and their log.
class _Take {
  _Take(this.tester, this.boundary, this.router, this.dir, this.statusTick);

  final WidgetTester tester;
  final GlobalKey boundary;
  final GoRouter router;
  final Directory dir;
  final ValueNotifier<int> statusTick;

  Process? _ffmpeg;
  int frames = 0;
  final List<Map<String, Object?>> gestures = [];
  final List<String> errors = [];

  /// Bytes of the previous frame, to count frames that did not change.
  Uint8List? _last;
  int changedFrames = 0;

  double get t => frames / _fps;

  MockServer get server => getIt<MockServer>();

  /// Real time, for anything that awaits the mock server, a file or a
  /// platform channel. Pumped time stands still meanwhile.
  Future<void> real(Future<void> Function() body) => tester.runAsync(body);

  /// Lets work that needs real time finish, without recording.
  Future<void> breathe([int ms = 60]) =>
      real(() => Future<void>.delayed(Duration(milliseconds: ms)));

  /// Pumps without recording, to settle a screen before the first frame.
  Future<void> settle({int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      await breathe(100);
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Starts the recording. Frame 0 is the next frame pumped.
  Future<void> record() async {
    final frameDir = Directory(p.join(dir.path, 'frames'));
    if (frameDir.existsSync()) frameDir.deleteSync(recursive: true);
    frameDir.createSync(recursive: true);
    await real(() async {
      _ffmpeg = await Process.start('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'rawvideo', '-pix_fmt', 'rgba',
        '-s', '${_widthPx}x$_heightPx', '-framerate', '$_fps',
        '-i', '-',
        // The lossless source: one PNG per frame.
        '-map', '0:v', '-c:v', 'png', '-pred', 'mixed',
        '-start_number', '0', p.join(frameDir.path, '%04d.png'),
        // The clip. All intra would be larger for nothing: a film that
        // needs exact frames reads the PNGs.
        '-map', '0:v', '-c:v', 'libx264', '-preset', 'slow', '-crf', '12',
        '-pix_fmt', 'yuv420p', '-g', '30', '-movflags', '+faststart',
        '-color_primaries', 'bt709', '-color_trc', 'bt709',
        '-colorspace', 'bt709',
        p.join(dir.path, 'clip.mp4'),
      ]);
      unawaited(_ffmpeg!.stderr.transform(utf8.decoder).forEach(stderr.write));
      unawaited(_ffmpeg!.stdout.drain<void>());
    });
  }

  Future<void> _finish() async {
    await real(() async {
      await _ffmpeg!.stdin.flush();
      await _ffmpeg!.stdin.close();
      final code = await _ffmpeg!.exitCode;
      if (code != 0) errors.add('ffmpeg ended with $code');
    });
  }

  /// One frame: pump a sixtieth of a second, read the screen, hand it on.
  Future<void> frame() async {
    _clock.tick();
    statusTick.value++;
    await tester.pump(Duration(microseconds: (1e6 / _fps).round()));
    final thrown = tester.takeException();
    if (thrown != null) errors.add('$thrown'.split('\n').first);
    await real(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: _ratio);
      final data = await image.toByteData();
      image.dispose();
      final bytes = data!.buffer.asUint8List();
      if (image.width != _widthPx || image.height != _heightPx) {
        errors.add('frame is ${image.width}x${image.height}');
      }
      final last = _last;
      if (last == null || !_same(last, bytes)) changedFrames++;
      _last = bytes;
      _ffmpeg!.stdin.add(bytes);
      await _ffmpeg!.stdin.flush();
    });
    frames++;
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    // Whole words first: a frame is 8 MB.
    final x = a.buffer.asUint64List(a.offsetInBytes, a.length ~/ 8);
    final y = b.buffer.asUint64List(b.offsetInBytes, b.length ~/ 8);
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  /// Lets [s] seconds pass exactly as [hold] does, clock and all, without
  /// recording them. A clip that carries on from another plays that
  /// clip's run this way first.
  Future<void> skip(double s) async {
    final n = (s * _fps).round();
    for (var i = 0; i < n; i++) {
      _clock.tick();
      statusTick.value++;
      await tester.pump(Duration(microseconds: (1e6 / _fps).round()));
      final thrown = tester.takeException();
      if (thrown != null) errors.add('$thrown'.split('\n').first);
      // Real time, as saving a frame gives, so work in flight can land.
      await breathe(8);
    }
  }

  /// Records [s] seconds with nothing touched.
  Future<void> hold(double s) async {
    final n = (s * _fps).round();
    for (var i = 0; i < n; i++) {
      await frame();
    }
  }

  List<double> _px(Offset at) => [
    double.parse((at.dx * _ratio).toStringAsFixed(1)),
    double.parse((at.dy * _ratio).toStringAsFixed(1)),
  ];

  double _round(double v) => double.parse(v.toStringAsFixed(3));

  /// A tap on the middle of [target]: finger down, [press] seconds, up.
  Future<Offset> tap(
    Finder target, {
    required String what,
    double press = 0.1,
  }) => tapAt(tester.getCenter(target.first), what: what, press: press);

  Future<Offset> tapAt(
    Offset at, {
    required String what,
    double press = 0.1,
  }) async {
    final down = t;
    final gesture = await tester.startGesture(at);
    await hold(press);
    await gesture.up();
    gestures.add({
      'type': 'tap',
      'target': what,
      't': _round(down),
      't_up': _round(t),
      'x': _px(at)[0],
      'y': _px(at)[1],
    });
    return at;
  }

  /// A drag from [from] to [to] over [seconds], eased, the finger down for
  /// the whole of it. [flick] lifts while still moving, for a fling.
  Future<void> drag(
    Offset from,
    Offset to, {
    required String what,
    double seconds = 0.4,
    Curve curve = Curves.easeInOut,
    bool flick = false,
  }) async {
    final down = t;
    final gesture = await tester.startGesture(from);
    final n = math.max(2, (seconds * _fps).round());
    final path = <Map<String, Object?>>[];
    await frame();
    for (var i = 1; i <= n; i++) {
      final k = flick ? Curves.easeIn.transform(i / n) : curve.transform(i / n);
      final at = Offset.lerp(from, to, k)!;
      await gesture.moveTo(
        at,
        timeStamp: Duration(microseconds: (t * 1e6).round()),
      );
      path.add({'t': _round(t), 'x': _px(at)[0], 'y': _px(at)[1]});
      await frame();
    }
    await gesture.up(timeStamp: Duration(microseconds: (t * 1e6).round()));
    gestures.add({
      'type': flick ? 'flick' : 'drag',
      'target': what,
      't': _round(down),
      't_up': _round(t),
      'x': _px(from)[0],
      'y': _px(from)[1],
      'to_x': _px(to)[0],
      'to_y': _px(to)[1],
      'path': path,
    });
  }

  /// Something that happens with no finger on the glass: a push landing, a
  /// list reloading. Written down so a film can time a sound to it.
  void mark(String what) => gestures.add({
    'type': 'event',
    'target': what,
    't': _round(t),
  });

  Finder text(String s) => find.text(s);
}

// ---------------------------------------------------------------------------
// The status bar the tool draws
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.tick, required this.fallbackDark});

  final ValueListenable<int> tick;

  /// Whether the screen under the bar is dark when the app has asked the
  /// system for nothing.
  final bool fallbackDark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, _) {
        // What the app last asked the system for. On an iPhone a dark
        // status bar brightness means light glyphs.
        final style = SystemChrome.latestStyle;
        final bright = style?.statusBarBrightness;
        final icons = style?.statusBarIconBrightness;
        final light = bright != null
            ? bright == Brightness.dark
            : icons != null
            ? icons == Brightness.light
            : fallbackDark;
        final color = light ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
        final (h, m, _) = _clipStartsAt;
        return IgnorePointer(
          child: SizedBox(
            height: _statusBarPt,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 6, 26, 0),
              child: Row(
                children: [
                  Text(
                    '$h:${m.toString().padLeft(2, '0')}',
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
                  CustomPaint(
                    size: const Size(68, 13),
                    painter: _StatusGlyphs(color),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Signal bars, wifi and a battery, drawn plainly.
class _StatusGlyphs extends CustomPainter {
  const _StatusGlyphs(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    // Four signal bars.
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
    // Wifi: three arcs from one point.
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
    // Battery.
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
  bool shouldRepaint(_StatusGlyphs old) => old.color != color;
}

// ---------------------------------------------------------------------------
// The phone the clips are recorded on
// ---------------------------------------------------------------------------

/// Reports every permission the app checks as granted, as the still
/// snapshots do: a film shows a phone that is set up.
class _AllGranted implements DevicePermissionsRepository {
  _AllGranted(this._real);

  final DevicePermissionsRepository _real;

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() async {
    final result = await _real.getPermissions();
    final items = result.getOrNull() ?? const <DevicePermissionItem>[];
    return [
      for (final item in items)
        item.copyWith(status: DevicePermissionStatus.granted),
    ].toSuccess();
  }

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async => DevicePermissionStatus.granted.toSuccess();

  @override
  Future<AppResult<bool>> openPermissionSettings(
    DevicePermissionType type,
  ) async => false.toSuccess();

  @override
  Future<AppResult<bool>> openAppSettings() async => false.toSuccess();
}

String _dbPath = '';

String _appVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return line.substring('version:'.length).trim();
}

/// `id -> show-early` from the feature table, so the manifest can say which
/// clips show something content may not yet present as available.
Map<String, String> _readShowEarly(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final out = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    if (!line.startsWith('| F-')) continue;
    final cells = line.split('|').map((c) => c.trim()).toList();
    // | id | capability | ios | android | plan | state | since | show-early |
    if (cells.length < 9) continue;
    out[cells[1]] = cells[8];
  }
  return out;
}

void main() {
  final outDir = Directory(
    _env('MOTION_OUT', '../critalarm-content-pipeline/ui-motion'),
  );
  final only = _env('MOTION_ONLY', '');
  final listOnly = _env('MOTION_LIST', '') == '1';
  final showEarly = _readShowEarly(
    _env('MOTION_FEATURES', '../critalarm-planning/features.md'),
  );
  final entries = <Map<String, Object?>>[];
  final clips = _allClips();

  if (listOnly) {
    test('list', () {
      for (final c in clips) {
        print('${c.id}  ${c.screen}  ${c.look}  ${c.story ?? '-'}');
      }
    });
    return;
  }

  setUpAll(() async {
    // After the translations: loading them resets the mock preferences.
    await loadTestTranslations();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://api.critalarm.app',
      'admin_token': 'adm_motion',
      'device_id': 'dev_motion',
      'device_token': 'dt_motion',
      'account_id': 'acc_motion',
      'account_tier': 'free',
      'account_caps': '{"history_days": 7}',
      // Asks and guides a film should not carry.
      'home_prompt_account_dismissed_at': nowMs,
      'home_prompt_consent_asked_at': nowMs,
      'home_prompt_review_asked_at': nowMs,
      'home_prompt_feedback_asked_at': nowMs,
    });
    final docs = Directory.systemTemp.createTempSync('critalarm_motion_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => docs.path,
      )
      ..setMockMethodCallHandler(
        const MethodChannel(AlarmHost.channelName),
        (call) async => switch (call.method) {
          'authorizationStatus'
              when defaultTargetPlatform == TargetPlatform.iOS =>
            AlarmAuthorization.authorized.name,
          _ => null,
        },
      );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    _dbPath = p.join(docs.path, LocalStore.fileName);
    // MOCK on, whatever the build defines: no clip can reach a real server.
    await configureDependencies(useMockApi: true);
    final real = getIt<DevicePermissionsRepository>();
    getIt
      ..unregister<DevicePermissionsRepository>()
      ..registerSingleton<DevicePermissionsRepository>(_AllGranted(real));
    await _giveAlarmScreenThePumpedClock();
    await getIt<ReliabilityCubit>().refresh();
    await loadAppFonts();
  });

  tearDownAll(() {
    if (entries.isEmpty) return;
    entries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final manifestFile = File(p.join(outDir.path, 'manifest.json'));
    // A run of some clips keeps the entries of the others.
    final kept = <Map<String, Object?>>[];
    if (only.isNotEmpty && manifestFile.existsSync()) {
      try {
        final old = jsonDecode(manifestFile.readAsStringSync()) as Map;
        final ids = {for (final e in entries) e['id']};
        for (final c in (old['clips'] as List? ?? const [])) {
          if (c is Map && !ids.contains(c['id'])) {
            kept.add(c.cast<String, Object?>());
          }
        }
      } on Object catch (_) {
        // An unreadable manifest is replaced.
      }
    }
    final all = [...kept, ...entries]
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final manifest = {
      'app_version': _appVersion(),
      'app_commit': _env('GIT_SHA', 'unknown'),
      'app_commit_dirty': _env('GIT_DIRTY', 'false') == 'true',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'generator': 'critalarm-app tool/capture_motion.dart',
      'method': 'off-device',
      'locale': 'en',
      'platform': 'iOS',
      'size': [_widthPx, _heightPx],
      'points': [_widthPt, _heightPt],
      'pixel_ratio': _ratio,
      'fps': _fps,
      'theme': _theme,
      'status_bar': _hasStatusBar
          ? {
              'drawn_by': 'tool',
              'glyphs':
                  'dark on a light screen, light on a dark one: they '
                  'follow what the app asks the system for',
              'clock':
                  '${_clipStartsAt.$1}:'
                  '${_clipStartsAt.$2.toString().padLeft(2, '0')}',
              'rect': [0, 0, _widthPx, (_statusBarPt * _ratio).round()],
            }
          : null,
      'gesture_units': 'clip pixels from the top left, seconds from frame 0',
      'clips': all,
    };
    manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    print('Wrote ${entries.length} clips to ${outDir.path}');
  });

  for (final clip in clips) {
    if (only.isNotEmpty && !only.split(',').any(clip.id.contains)) continue;
    testWidgets('clip ${clip.id}', (tester) async {
      final dir = Directory(p.join(outDir.path, 'clips', clip.id))
        ..createSync(recursive: true);
      final server = getIt<MockServer>()..reset();
      await tester.runAsync(() async {
        final db = await databaseFactory.openDatabase(_dbPath);
        await db.delete('messages');
        await db.delete('incidents');
        final prefs = getIt<SharedPreferences>();
        for (final key in prefs.getKeys().toList()) {
          if (key.startsWith('alarm_style') ||
              key.startsWith(ChallengeChoices.choiceKeyPrefix) ||
              key.startsWith(ChallengeChoices.owedKeyPrefix)) {
            await prefs.remove(key);
          }
        }
        await getIt<ProPackDevSwitch>().setHeld(isHeld: false);
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      getIt
        ..unregister<PlatformCapabilities>()
        ..registerSingleton<PlatformCapabilities>(
          const PlatformCapabilities(
            isWeb: false,
            platform: TargetPlatform.iOS,
          ),
        );

      tester.view.physicalSize = Size(
        _widthPx.toDouble(),
        _heightPx.toDouble(),
      );
      tester.view.devicePixelRatio = _ratio;
      if (_hasStatusBar) {
        tester.view.padding = FakeViewPadding(top: _statusBarPt * _ratio);
        tester.view.viewPadding = tester.view.padding;
      }
      addTearDown(tester.view.reset);
      debugDisableShadows = false;

      final boundary = GlobalKey();
      final statusTick = ValueNotifier<int>(0);
      final themeMode = clip.theme == 'light'
          ? ThemeMode.light
          : ThemeMode.dark;

      _setWallClockToClipStart();
      _clock.restart();
      final scene = _Scene(tester, server)
        // The clip seeds the mock, then names its first route. Nothing is
        // recorded until it calls `record` on the take it gets back.
        .._open = (route) async {
          await tester.runAsync(() async {
            await getIt<TopicsCubit>().refresh();
            await getIt<IncidentsCubit>().refresh(full: true);
          });
          final router = buildRouter(initialLocation: route);
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider<IncidentsCubit>.value(
                  value: getIt<IncidentsCubit>(),
                ),
                BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
                BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
                BlocProvider<AppearanceCubit>.value(
                  value: getIt<AppearanceCubit>(),
                ),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: themeMode,
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
                      if (_hasStatusBar)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _StatusBar(
                            tick: statusTick,
                            fallbackDark: themeMode == ThemeMode.dark,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          final take = _Take(tester, boundary, router, dir, statusTick);
          await take.settle();
          return take;
        };

      Object? failure;
      try {
        await clip.run(scene);
      } on Object catch (e, st) {
        failure = e;
        print('FAILED ${clip.id}: $e\n$st');
      }
      final take = scene.take;
      if (take != null && take._ffmpeg != null) await take._finish();

      // Let closing timers run out, as the still capture does.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();
      debugDefaultTargetPlatformOverride = null;
      debugDisableShadows = true;

      if (failure != null || take == null) {
        fail('${clip.id} did not record: $failure');
      }
      final done = take;
      final n = done.frames;
      if (n == 0) fail('${clip.id} recorded no frame');
      // The first and the last frame, as stills.
      final framesDir = p.join(dir.path, 'frames');
      String name(int i) => '${i.toString().padLeft(4, '0')}.png';
      File(p.join(framesDir, name(0))).copySync(p.join(dir.path, 'first.png'));
      File(
        p.join(framesDir, name(n - 1)),
      ).copySync(p.join(dir.path, 'last.png'));

      final moving = done.changedFrames / n;
      entries.add({
        'id': clip.id,
        'file': 'clips/${clip.id}/clip.mp4',
        'frames_dir': 'clips/${clip.id}/frames',
        'frame_pattern': 'clips/${clip.id}/frames/%04d.png',
        'first_frame': 'clips/${clip.id}/first.png',
        'last_frame': 'clips/${clip.id}/last.png',
        'frame_count': n,
        'size': [_widthPx, _heightPx],
        'fps': _fps,
        'length_s': double.parse((n / _fps).toStringAsFixed(3)),
        'method': 'off-device',
        'screen': clip.screen,
        'look': clip.look,
        'story': clip.story,
        'theme': clip.theme,
        'note': clip.note,
        'gestures': done.gestures,
        if (_joins[clip.id] != null) 'join': _joins[clip.id],
        'features': [
          for (final f in clip.features)
            {'id': f, 'show_early': showEarly[f] ?? 'unknown'},
        ],
        'show_early': clip.features.every((f) => showEarly[f] == 'yes')
            ? 'yes'
            : 'no',
        'frames_that_changed': done.changedFrames,
        'share_of_frames_that_changed': double.parse(moving.toStringAsFixed(3)),
        if (done.errors.isNotEmpty) 'errors': done.errors.toSet().toList(),
      });
      print(
        'clip ${clip.id}: $n frames, ${(n / _fps).toStringAsFixed(2)} s, '
        '${done.changedFrames} changed, ${done.gestures.length} gestures'
        '${done.errors.isEmpty ? '' : ', ERRORS ${done.errors.toSet()}'}',
      );
      if (done.changedFrames < n * 0.1) {
        fail('${clip.id} barely moves: ${done.changedFrames} of $n frames');
      }
    });
  }
}
