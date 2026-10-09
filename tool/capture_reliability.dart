// Captures the real "Will it wake me?" screen against the mock server, off
// the device.
//
//   fvm flutter test tool/capture_reliability.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// The proof card scenes set the plan through the developer switches, which
// exist only in a SKIP_PAYWALL build.
//
// It boots the app's own dependencies on the mock server, hands the
// reliability cubit the checks a scene says, opens the screen and writes a
// PNG named reliability_<scene>_<phone>_<theme>_<scale>x_<motion>.png. The
// path of every file is printed.
//
// The motion part of the name is `reduced` for the resting frame (reduce
// motion on, nothing moves) or `t<ms>` for a frame that many milliseconds
// into the clock with motion on. A frame at t1400 shows the dot half way
// along the wire, and one at t2300 shows the last stop swelling as it lands.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=STATES=a,b     only these scenes
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _statesArg = String.fromEnvironment('STATES');
const _only = String.fromEnvironment('ONLY');

/// What the install holds, for the weekly check row in the proof card.
enum _Plan {
  /// Crit Alarm Cloud, Hosted not held.
  cloud,

  /// Crit Alarm Cloud, Hosted held.
  hosted,

  /// A server of the user's own.
  ownServer,

  /// The plan is still being read.
  unread,
}

/// One thing the screen can be, and how the capture sets it up.
class _Scene {
  const _Scene(
    this.name, {
    required this.checks,
    this.loaded = true,
    this.incomplete = false,
    this.testedAgo,
    this.openPassing = false,
    this.plan,
    this.weeks,
    this.weeklyState = WeeklyCheckState.received,
    this.scrollBy,
    this.refuseSwitch = false,
  });

  final String name;
  final List<ReliabilityCheck> Function() checks;
  final bool loaded;

  /// A source that does not answer.
  final bool incomplete;

  /// How long ago a test rang, or null for never.
  final Duration? testedAgo;

  /// Taps the folded "N checks pass" row.
  final bool openPassing;

  /// What the install holds, or null to leave the app as it boots.
  final _Plan? plan;

  /// The eight weeks of the proof log, oldest first, or null to leave the
  /// log empty (except for [testedAgo]). The last is this week.
  final List<ProofMark>? weeks;

  /// The relay's answer for the weekly check when Hosted is held.
  final WeeklyCheckState weeklyState;

  /// Scrolls the page up by this much before the capture.
  final double? scrollBy;

  /// Taps the weekly check switch while the relay is on a plan that refuses
  /// it, so the line under the row shows.
  final bool refuseSwitch;
}

const ProofMark _n = ProofMark.none;
const ProofMark _r = ProofMark.rang;
const ProofMark _f = ProofMark.failed;

const _phoneChecks = <ReliabilityCheckId>[
  ReliabilityCheckIds.notifications,
  ReliabilityCheckIds.fullScreenAlarm,
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityCheckIds.pushTokenConfirmed,
  ReliabilityCheckIds.lastPushReceived,
  ReliabilityCheckIds.systemUpdate,
  ReliabilityCheckIds.phoneMaker,
  ReliabilityCheckIds.missedAlarm,
];

List<ReliabilityCheck> _fine() => [
  for (final id in _phoneChecks)
    ReliabilityCheck(id: id, state: ReliabilityState.fine),
];

List<ReliabilityCheck> _with(
  Map<ReliabilityCheckId, ReliabilityCheck> changed,
) => [
  for (final check in _fine()) changed[check.id] ?? check,
];

ReliabilityCheck _battery() => const ReliabilityCheck(
  id: ReliabilityCheckIds.batteryOptimization,
  state: ReliabilityState.needsLook,
  reason: 'restricted',
  fix: OpenSystemSettingsFix(DevicePermissionType.batteryOptimization),
);

ReliabilityCheck _notifications() => const ReliabilityCheck(
  id: ReliabilityCheckIds.notifications,
  state: ReliabilityState.broken,
  reason: 'denied',
  fix: AskPermissionFix(DevicePermissionType.notifications),
);

ReliabilityCheck _fullScreen() => const ReliabilityCheck(
  id: ReliabilityCheckIds.fullScreenAlarm,
  state: ReliabilityState.broken,
  reason: 'denied',
  fix: OpenSystemSettingsFix(DevicePermissionType.fullScreenIntent),
);

ReliabilityCheck _relay() => const ReliabilityCheck(
  id: ReliabilityCheckIds.pushTokenConfirmed,
  state: ReliabilityState.broken,
  reason: 'refused',
  fix: RunFix(ReliabilityFixAction.reRegisterPushToken),
);

final _scenes = <_Scene>[
  // The proof card.
  const _Scene(
    'proof_locked',
    checks: _fine,
    testedAgo: Duration(hours: 2),
    plan: _Plan.cloud,
    weeks: [_n, _n, _n, _n, _n, _n, _r, _r],
  ),
  _Scene(
    'proof_on',
    checks: () => _with({ReliabilityCheckIds.batteryOptimization: _battery()}),
    testedAgo: const Duration(hours: 2),
    plan: _Plan.hosted,
    weeks: const [_r, _r, _r, _r, _r, _f, _r, _r],
  ),
  const _Scene(
    'proof_off',
    checks: _fine,
    testedAgo: Duration(hours: 2),
    plan: _Plan.hosted,
    weeklyState: WeeklyCheckState.off,
    weeks: [_n, _n, _r, _n, _r, _n, _r, _r],
  ),
  _Scene(
    'proof_three',
    checks: () => _with({
      ReliabilityCheckIds.notifications: _notifications(),
      ReliabilityCheckIds.fullScreenAlarm: _fullScreen(),
      ReliabilityCheckIds.pushTokenConfirmed: _relay(),
    }),
    plan: _Plan.cloud,
    weeks: const [_n, _n, _n, _n, _n, _n, _n, _n],
  ),
  const _Scene('proof_empty', checks: _fine, plan: _Plan.hosted),
  const _Scene(
    'proof_own',
    checks: _fine,
    testedAgo: Duration(hours: 2),
    plan: _Plan.ownServer,
    weeks: [_n, _n, _n, _n, _n, _n, _r, _r],
  ),
  const _Scene(
    'proof_unread',
    checks: _fine,
    testedAgo: Duration(hours: 2),
    plan: _Plan.unread,
    weeks: [_n, _n, _n, _n, _n, _n, _r, _r],
  ),
  const _Scene(
    'proof_refused',
    checks: _fine,
    testedAgo: Duration(hours: 2),
    plan: _Plan.hosted,
    weeklyState: WeeklyCheckState.off,
    weeks: [_n, _r, _n, _r, _n, _n, _r, _r],
    refuseSwitch: true,
  ),
  _Scene(
    'proof_missed',
    checks: () => [
      ..._fine(),
      const ReliabilityCheck(
        id: WeeklyCheckSource.id,
        state: ReliabilityState.needsLook,
        reason: WeeklyCheckSource.reasonMissed,
        fix: OpenRouteFix(AppRoute.testRing),
      ),
    ],
    plan: _Plan.hosted,
    weeklyState: WeeklyCheckState.missedRepeatedly,
    weeks: const [_r, _r, _r, _n, _n, _n, _f, _n],
  ),
  // The bar's title comes in once the header has scrolled under the bar.
  _Scene(
    'scrolled',
    checks: () => _with({
      ReliabilityCheckIds.notifications: _notifications(),
      ReliabilityCheckIds.fullScreenAlarm: _fullScreen(),
      ReliabilityCheckIds.pushTokenConfirmed: _relay(),
    }),
    plan: _Plan.cloud,
    scrollBy: 260,
  ),
  const _Scene('yes', checks: _fine, testedAgo: Duration(hours: 2)),
  const _Scene('yes_untested', checks: _fine),
  _Scene(
    'maybe',
    checks: () => _with({ReliabilityCheckIds.batteryOptimization: _battery()}),
    testedAgo: const Duration(hours: 2),
  ),
  _Scene(
    'maybe_open',
    checks: () => _with({ReliabilityCheckIds.batteryOptimization: _battery()}),
    openPassing: true,
  ),
  _Scene(
    'no_one',
    checks: () => _with({ReliabilityCheckIds.notifications: _notifications()}),
  ),
  _Scene(
    'no_server',
    checks: () => _with({ReliabilityCheckIds.pushTokenConfirmed: _relay()}),
  ),
  _Scene(
    'no_three',
    checks: () => _with({
      ReliabilityCheckIds.notifications: _notifications(),
      ReliabilityCheckIds.fullScreenAlarm: _fullScreen(),
      ReliabilityCheckIds.pushTokenConfirmed: _relay(),
    }),
  ),
  const _Scene('loading', checks: _fine, loaded: false),
  const _Scene('incomplete', checks: _fine, incomplete: true),
  _Scene(
    'web',
    checks: () => [
      for (final id in const [
        ReliabilityCheckIds.pushTokenConfirmed,
        ReliabilityCheckIds.lastPushReceived,
      ])
        ReliabilityCheck(id: id, state: ReliabilityState.fine),
    ],
    testedAgo: const Duration(days: 3),
  ),
  _Scene(
    'weekly',
    checks: () => [
      ..._fine(),
      const ReliabilityCheck(
        id: WeeklyCheckSource.id,
        state: ReliabilityState.needsLook,
        reason: WeeklyCheckSource.reasonMissed,
        fix: OpenRouteFix(AppRoute.testRing),
      ),
    ],
  ),
];

/// A frame to save: the phone, the theme, the text size and the moment.
typedef _Variant = (String, Size, ThemeMode, double, int?);

const _phone = Size(390, 844);
const _narrow = Size(320, 640);
const _tall = Size(390, 1500);
const _narrowTall = Size(320, 1500);

List<_Variant> _variants(String scene) {
  if (scene.startsWith('proof_')) {
    const full = ['proof_locked', 'proof_on', 'proof_three'];
    return [
      ('390x844', _phone, ThemeMode.light, 1.0, null),
      ('390x1500', _tall, ThemeMode.light, 1.0, null),
      ('390x1500', _tall, ThemeMode.dark, 1.0, null),
      ('320x1500', _narrowTall, ThemeMode.light, 1.0, null),
      if (full.contains(scene)) ...[
        ('320x1500', _narrowTall, ThemeMode.dark, 1.0, null),
        ('390x1500', _tall, ThemeMode.light, 1.3, null),
        ('390x1500', _tall, ThemeMode.light, 2.0, null),
        ('320x1500', _narrowTall, ThemeMode.light, 2.0, null),
      ],
    ];
  }
  if (scene == 'scrolled') {
    return [
      ('390x844', _phone, ThemeMode.light, 1.0, null),
      ('390x844', _phone, ThemeMode.dark, 1.0, null),
    ];
  }
  return _regularVariants(scene);
}

List<_Variant> _regularVariants(String scene) => [
  ('390x844', _phone, ThemeMode.light, 1.0, null),
  ('390x844', _phone, ThemeMode.dark, 1.0, null),
  if (const ['yes', 'maybe', 'no_one', 'no_three'].contains(scene)) ...[
    ('320x640', _narrow, ThemeMode.light, 1.0, null),
    ('390x844', _phone, ThemeMode.light, 1.3, null),
    ('390x1500', _tall, ThemeMode.light, 2.0, null),
    ('320x640', _narrow, ThemeMode.light, 2.0, null),
  ],
  if (scene == 'no_three') ('320x640', _narrow, ThemeMode.dark, 1.3, null),
  // The clock has already run about 1.2 s when the screen settles, so these
  // moments sit on top of that: 0 is mid-trip, 1100 is the landing.
  if (scene == 'yes') ...[
    ('390x844', _phone, ThemeMode.light, 1.0, 0),
    ('390x844', _phone, ThemeMode.light, 1.0, 1100),
    ('390x844', _phone, ThemeMode.dark, 1.0, 0),
  ],
  if (scene == 'maybe') ('390x844', _phone, ThemeMode.light, 1.0, 0),
  if (scene == 'no_one') ...[
    ('390x844', _phone, ThemeMode.light, 1.0, 0),
    ('390x844', _phone, ThemeMode.light, 1.0, 600),
  ],
  if (scene == 'no_server') ...[
    ('390x844', _phone, ThemeMode.light, 1.0, 0),
    ('390x844', _phone, ThemeMode.light, 1.0, 500),
  ],
  if (scene == 'no_three') ('390x844', _phone, ThemeMode.light, 1.0, 0),
];

/// Answers with the checks the scene says.
class _FixedSource implements ReliabilityCheckSource {
  _FixedSource(this.checks);

  final List<ReliabilityCheck> checks;

  @override
  Future<List<ReliabilityCheck>> read() async => checks;
}

class _ThrowingSource implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => throw StateError('no answer');
}

/// A reliability cubit that stays in the state before the first read.
class _NeverLoaded extends ReliabilityCubit {
  _NeverLoaded() : super(const []);

  @override
  Future<void> refresh() async {}
}

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  getIt<MockServer>().seedCalm();

  await getIt.unregister<ReliabilityCubit>();
  getIt.registerLazySingleton<ReliabilityCubit>(() {
    if (!scene.loaded) return _NeverLoaded();
    return ReliabilityCubit([
      _FixedSource(scene.checks()),
      if (scene.incomplete) _ThrowingSource(),
    ]);
  });
  await _setPlan(scene);
}

/// Puts the install in the plan the scene says, through the developer
/// switches, and the relay's answer for the weekly check with it.
Future<void> _setPlan(_Scene scene) async {
  final plan = scene.plan;
  if (plan == null) return;
  final switches = getIt<DevAccessSwitches>();
  if (plan == _Plan.unread) {
    await switches.apply(AccessPreset.planReading);
    return;
  }
  await switches.force(
    Holding.hosted,
    plan == _Plan.hosted ? HoldingState.held : HoldingState.notHeld,
  );
  await switches.force(Holding.pro, HoldingState.notHeld);
  await switches.setServerMode(
    plan == _Plan.ownServer
        ? ServerModeChoice.ownServer
        : ServerModeChoice.cloud,
  );
  await getIt<FeatureAccess>().ready;
  if (plan == _Plan.hosted) {
    getIt<MockServer>().seedWeeklyCheck(scene.weeklyState);
    // A read may be out already. The second is sure to read after the seed.
    final monitor = getIt<WeeklyCheckMonitor>();
    await monitor.refresh(force: true);
    await monitor.refresh(force: true);
  }
}

/// Writes the proof log the scene says: a mark per week, the last one this
/// week, at [_Scene.testedAgo] before now.
Future<void> _fillLog(_Scene scene) async {
  final log = getIt<ProofLog>();
  final now = DateTime.now();
  final ago = scene.testedAgo ?? const Duration(minutes: 5);
  final weeks = scene.weeks;
  if (weeks == null) {
    if (scene.testedAgo != null) await log.markRang(now.subtract(ago));
    return;
  }
  for (var i = 0; i < weeks.length; i++) {
    final back = weeks.length - 1 - i;
    final at = back == 0
        ? now.subtract(ago)
        : now.subtract(Duration(days: 7 * back));
    switch (weeks[i]) {
      case ProofMark.rang:
        await log.markRang(at);
      case ProofMark.failed:
        await log.markFailed(at);
      case ProofMark.none:
        break;
    }
  }
}

/// Opens the screen on [scene] at [phone] and lets it settle. With [atMs] set
/// motion is on and the clock runs that many milliseconds.
Future<void> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
  required int? atMs,
  required GlobalKey key,
}) async {
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: atMs == null,
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
  );
  router.go('/settings/reliability');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  if (scene.openPassing) {
    final folded = find.textContaining('checks pass');
    if (folded.evaluate().isNotEmpty) {
      await tester.tap(folded.first);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
  // The log is written once the screen is up: starting the app clears the
  // phone's account data, the proof log with it.
  await tester.runAsync(() => _fillLog(scene));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
  final scrollBy = scene.scrollBy;
  if (scrollBy != null) {
    await tester.drag(
      find.byType(CustomScrollView).first,
      Offset(0, -scrollBy),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }
  if (scene.refuseSwitch) {
    // The relay refuses the switch for an account that is not on Hosted.
    getIt<MockServer>().accountTier = 'free';
    final toggle = find.byType(AppSwitch);
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle.first);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }
  }
  if (atMs != null) {
    // The clock started when the header was built. Step it in frames.
    var left = atMs;
    while (left > 0) {
      final step = left > 16 ? 16 : left;
      await tester.pump(Duration(milliseconds: step));
      left -= step;
    }
  }
}

/// Writes what [key] shows to [name].png.
Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name,
  List<String> errors,
) => tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
});

void main() {
  final wanted = _statesArg.split(',').where((s) => s.isNotEmpty).toSet();
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final scene in _scenes) {
    if (wanted.isNotEmpty && !wanted.contains(scene.name)) continue;
    for (final (phoneName, phone, mode, scale, atMs) in _variants(scene.name)) {
      final moment = atMs == null ? 'reduced' : 't$atMs';
      final name =
          'reliability_${scene.name}_${phoneName}_${mode.name}_${scale}x_'
          '$moment';
      if (onlyParts.isNotEmpty && !onlyParts.any(name.contains)) continue;
      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        addTearDown(() => FlutterError.onError = oldHandler);

        final key = GlobalKey();
        await _open(
          tester,
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
          atMs: atMs,
          key: key,
        );
        await _save(tester, key, name, errors);
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').first}');
        }
        expect(errors, isEmpty, reason: 'overflow or build error in $name');
      });
    }
  }
}
