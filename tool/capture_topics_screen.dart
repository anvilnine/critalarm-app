// Captures the real Topics screen against the mock server, off the device.
//
//   fvm flutter test tool/capture_topics_screen.dart
//
// It boots the app's own dependencies on the mock server, seeds one state,
// opens Home and writes a PNG named
// <state>_<phone>_<theme>_<scale>x.png. Idle is also captured at 375 by 667
// and at text scales 1.3 and 2.0. The path of every file is printed.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=STATES=a,b     only these states
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=T=<seconds>    let motion run this long before the capture
//                                (default: motion held, the resting frame)
//
// The mock server cannot stay unreachable or hold a request open, and it has
// no way to be "no server", so those three states use a Home cubit that is
// told its state. The
// checks and the missed alarm entry are also handed fixed answers, because a
// test run has no phone to read them from.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
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
const _t = String.fromEnvironment('T');

/// One thing Home can be, and how the capture sets it up.
class _Scene {
  const _Scene(
    this.name, {
    this.checks = _fineChecks,
    this.missed = false,
    this.fixedHome,
  });

  final String name;
  final List<ReliabilityCheck> Function() checks;
  final bool missed;

  /// The state a Home cubit is told instead of reading the mock server.
  final HomeState Function()? fixedHome;
}

List<ReliabilityCheck> _fineChecks() => [
  for (final id in const [
    ReliabilityCheckIds.notifications,
    ReliabilityCheckIds.fullScreenAlarm,
    ReliabilityCheckIds.batteryOptimization,
    ReliabilityCheckIds.pushTokenConfirmed,
    ReliabilityCheckIds.lastPushReceived,
    ReliabilityCheckIds.systemUpdate,
    ReliabilityCheckIds.phoneMaker,
  ])
    ReliabilityCheck(id: id, state: ReliabilityState.fine),
];

List<ReliabilityCheck> _batteryChecks() => [
  for (final c in _fineChecks())
    if (c.id == ReliabilityCheckIds.batteryOptimization)
      const ReliabilityCheck(
        id: ReliabilityCheckIds.batteryOptimization,
        state: ReliabilityState.needsLook,
        reason: 'on',
        fix: OpenRouteFix('permissions'),
      )
    else
      c,
];

HomeState _noServerHome() =>
    const HomeState(status: HomeStatus.failure, hasServer: false);

HomeState _loadingHome() => const HomeState(status: HomeStatus.loading);

HomeState _staleHome() {
  final now = DateTime.now();
  HomeTopicItem row(String name, String preview, Duration ago) => HomeTopicItem(
    name: name,
    meta: '',
    priority: PriorityLevel.defaultPriority,
    preview: preview,
    lastMessageAt: now.subtract(ago),
    ringsThroughSilent: name == 'prod-db',
  );
  return HomeState(
    status: HomeStatus.success,
    isStale: true,
    lastKnownGoodAt: now.subtract(const Duration(hours: 2)),
    topicItems: [
      row('prod-db', 'Replica lag is back to normal', const Duration(hours: 3)),
      row('nas-backup', 'Backup finished, 412 GB', const Duration(hours: 9)),
      row('uptime-kuma', 'api.example.com is up', const Duration(days: 1)),
    ],
  );
}

const _scenes = <_Scene>[
  _Scene('idle'),
  _Scene('issue', checks: _batteryChecks),
  _Scene('missed', missed: true),
  _Scene('acknowledged'),
  _Scene('notopics'),
  _Scene('onetopic'),
  _Scene('noserver', fixedHome: _noServerHome),
  _Scene('loading', fixedHome: _loadingHome),
  _Scene('stale', fixedHome: _staleHome),
];

/// The phones, themes and text sizes each state is captured at.
List<(String, Size, ThemeMode, double)> _variants(String scene) => [
  ('390x844', const Size(390, 844), ThemeMode.light, 1.0),
  ('390x844', const Size(390, 844), ThemeMode.dark, 1.0),
  if (scene == 'idle') ...[
    ('375x667', const Size(375, 667), ThemeMode.light, 1.0),
    ('390x844', const Size(390, 844), ThemeMode.light, 1.3),
    ('390x844', const Size(390, 844), ThemeMode.light, 2.0),
  ],
];

/// Answers with the checks the scene says, so the card counts them.
class _FixedSource implements ReliabilityCheckSource {
  _FixedSource(this.checks);

  final List<ReliabilityCheck> checks;

  @override
  Future<List<ReliabilityCheck>> read() async => checks;
}

/// A missed alarm entry that never reaches the phone's record.
class _FixedMissedFeed implements MissedAlarmFeed {
  _FixedMissedFeed(this.fact);

  final MissedFact? fact;

  @override
  Future<MissedFact?> read() async => fact;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {}
}

/// A Home cubit that shows the state it is told and reads nothing.
class _FixedHome extends HomeCubit {
  _FixedHome(this.fixed)
    : super(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        null,
        const Duration(seconds: 5),
        getIt(),
        null,
      );

  final HomeState fixed;

  @override
  Future<void> load() async => emit(fixed);

  @override
  Future<bool> refresh() async => true;
}

void _seed(MockServer server, _Scene scene) {
  final now = DateTime.now().toUtc();
  switch (scene.name) {
    case 'notopics':
      server.seedWatching();
    case 'onetopic':
      server.seedCalm();
      ['nas-backup', 'prod-db', 'home-ha'].forEach(server.deleteTopic);
    case 'acknowledged':
      server.seedCalm();
      final msg = Message(
        id: 'm_ack_capture',
        topic: 'prod-db',
        time:
            now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
            1000,
        title: 'Primary database down',
        message: 'Connection pool exhausted',
        priority: 5,
        incidentId: 'inc_ack_capture',
      );
      server.seedState(
        incidents: [
          Incident(
            id: 'inc_ack_capture',
            topic: 'prod-db',
            state: IncidentStates.acked,
            openedAt: now.subtract(const Duration(minutes: 5)),
            ackedAt: now.subtract(const Duration(minutes: 1)),
            updatedAt: now.subtract(const Duration(minutes: 1)),
            deskTimerFiresAt: now.add(const Duration(minutes: 9)),
            lastMessageAt: now.subtract(const Duration(minutes: 5)),
            messages: [msg],
          ),
        ],
        messages: [msg],
      );
    default:
      server.seedCalm();
  }
}

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    // The widgets card is shown once. Only idle keeps it, as a cream card.
    if (scene.name != 'idle') 'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    // The guide offer and the asks are other screens' business.
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  _seed(getIt<MockServer>(), scene);

  await getIt.unregister<ReliabilityCubit>();
  getIt.registerLazySingleton<ReliabilityCubit>(
    () => ReliabilityCubit([_FixedSource(scene.checks())]),
  );
  await getIt.unregister<MissedAlarmFeed>();
  final now = DateTime.now();
  getIt.registerLazySingleton<MissedAlarmFeed>(
    () => _FixedMissedFeed(
      scene.missed
          ? MissedFact(
              notice: MissedAlarmNotice(
                incidentIds: const ['inc_missed'],
                topic: 'prod-db',
                at: now.subtract(const Duration(hours: 1)),
                reason: MissedReason.rangUnanswered,
              ),
              ringDuration: const Duration(minutes: 10),
            )
          : null,
    ),
  );
  final fixed = scene.fixedHome;
  if (fixed != null) {
    await getIt.unregister<HomeCubit>();
    getIt.registerFactory<HomeCubit>(() => _FixedHome(fixed()));
  }
}

void main() {
  final wanted = _statesArg.split(',').where((s) => s.isNotEmpty).toSet();
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();
  final second = double.tryParse(_t);

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final scene in _scenes) {
    if (wanted.isNotEmpty && !wanted.contains(scene.name)) continue;
    for (final (phoneName, phone, mode, scale) in _variants(scene.name)) {
      final name = '${scene.name}_${phoneName}_${mode.name}_${scale}x';
      if (onlyParts.isNotEmpty && !onlyParts.any(name.contains)) continue;
      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        addTearDown(() => FlutterError.onError = oldHandler);

        await tester.runAsync(() => _boot(scene));
        tester.view.physicalSize = phone * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final key = GlobalKey();
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
                  disableAnimations: second == null,
                ),
                child: RepaintBoundary(key: key, child: child),
              ),
            ),
          ),
        );
        router.go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // The mock server answers in real time, so let it.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        if (second != null) {
          await tester.pump(Duration(milliseconds: (second * 1000).round()));
        }

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
        });
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').first}');
        }
        expect(errors, isEmpty, reason: 'overflow or build error in $name');
      });
    }
  }
}
