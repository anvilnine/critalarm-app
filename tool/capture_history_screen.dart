// Captures the real History screen against the mock server, off the device.
//
//   fvm flutter test tool/capture_history_screen.dart
//
// It boots the app's own dependencies on the mock server, seeds one state,
// opens History and writes a PNG named
// <state>_<phone>_<theme>_<scale>x.png. The first state is also captured at
// 375 by 667 and at text scales 1.3 and 2.0. The path of every file is
// printed. The refresh_* captures pull the list down and step through the
// refresh face.
//
// It draws the app's ambient canvas the way the app does (AppAmbientShell),
// so the background is the canvas's own.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=STATES=a,b     only these states
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// Loading and failed hold a History cubit that is told its state, because the
// mock server answers at once and never fails.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/history/presentation/widgets/history_hero.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _statesArg = String.fromEnvironment('STATES');
const _only = String.fromEnvironment('ONLY');

class _Scene {
  const _Scene(this.name, {this.fixed, this.scrollToEnd = false});

  final String name;

  /// Scrolls the list to its last row, to show what sits under the fold.
  final bool scrollToEnd;

  /// The state a History cubit is told instead of reading the phone's copy.
  final HistoryState Function()? fixed;
}

HistoryState _loading() => const HistoryState(status: HistoryStatus.loading);

HistoryState _failed() => const HistoryState(
  status: HistoryStatus.failure,
  errorMessage: 'Could not reach your server.',
);

const _scenes = <_Scene>[
  _Scene('week'),
  _Scene('missed'),
  _Scene('empty'),
  _Scene('planlimit', scrollToEnd: true),
  _Scene('missedend', scrollToEnd: true),
  _Scene('loading', fixed: _loading),
  _Scene('failed', fixed: _failed),
  _Scene('filtered'),
  _Scene('filteredempty'),
];

List<(String, Size, ThemeMode, double)> _variants(String scene) => [
  ('390x844', const Size(390, 844), ThemeMode.light, 1.0),
  ('390x844', const Size(390, 844), ThemeMode.dark, 1.0),
  if (scene == 'week' || scene == 'missed') ...[
    ('375x667', const Size(375, 667), ThemeMode.light, 1.0),
    ('390x844', const Size(390, 844), ThemeMode.light, 1.3),
    ('390x844', const Size(390, 844), ThemeMode.light, 2.0),
  ],
  if (scene == 'week')
    ('1024x768', const Size(1024, 768), ThemeMode.light, 1.0),
];

/// A History cubit that shows the state it is told and reads nothing.
class _FixedHistory extends HistoryCubit {
  _FixedHistory(this.fixed) : super(getIt<IncidentsCubit>());

  final HistoryState fixed;

  @override
  Future<void> load() async => emit(fixed);

  @override
  Future<bool> refresh() async => true;
}

Incident _incident(
  String id,
  String topic, {
  required DateTime opened,
  required String state,
  Duration? answeredAfter,
  Duration? rangFor,
}) {
  final msg = Message(
    id: 'm_$id',
    topic: topic,
    time: opened.millisecondsSinceEpoch ~/ 1000,
    title: 'Alarm on $topic',
    message: 'Capture alarm',
    priority: 5,
    incidentId: id,
  );
  final acked = answeredAfter == null ? null : opened.add(answeredAfter);
  return Incident(
    id: id,
    topic: topic,
    state: state,
    openedAt: opened,
    ackedAt: acked,
    closedAt: state == IncidentStates.closed
        ? acked?.add(const Duration(minutes: 3))
        : null,
    updatedAt: acked ?? opened,
    lastMessageAt: rangFor == null ? opened : opened.add(rangFor),
    messages: [msg],
  );
}

void _seed(MockServer server, _Scene scene) {
  server.seedCalm();
  if (scene.name == 'empty') {
    server.reset();
    return;
  }
  final now = DateTime.now().toUtc();
  DateTime ago(int days, int hour) {
    final d = now.subtract(Duration(days: days));
    return DateTime.utc(d.year, d.month, d.day, hour, 12);
  }

  // seedCalm already holds one closed incident two hours ago. Give the week
  // a shape on top of it.
  final incidents = <Incident>[
    _incident(
      'inc_w1',
      'uptime-kuma',
      opened: ago(0, 0),
      state: IncidentStates.closed,
      answeredAfter: const Duration(seconds: 11),
    ),
    _incident(
      'inc_w2',
      'uptime-kuma',
      opened: ago(1, 3),
      state: IncidentStates.acked,
      answeredAfter: const Duration(seconds: 7),
    ),
    _incident(
      'inc_w3',
      'nas-backup',
      opened: ago(2, 9),
      state: IncidentStates.closed,
      answeredAfter: const Duration(minutes: 2, seconds: 20),
    ),
    _incident(
      'inc_w4',
      'prod-db',
      opened: ago(2, 14),
      state: IncidentStates.acked,
      answeredAfter: const Duration(seconds: 44),
    ),
    _incident(
      'inc_w5',
      'prod-db',
      opened: ago(4, 5),
      state: IncidentStates.closed,
      answeredAfter: const Duration(seconds: 19),
    ),
    if (scene.name == 'missed' ||
        scene.name == 'missedend' ||
        scene.name == 'filtered' ||
        scene.name == 'filteredempty')
      _incident(
        'inc_w6',
        'prod-db',
        opened: ago(3, 3),
        state: IncidentStates.expired,
        rangFor: const Duration(minutes: 10),
      ),
    if (scene.name == 'planlimit') ...[
      _incident(
        'inc_old1',
        'prod-db',
        opened: ago(12, 8),
        state: IncidentStates.closed,
        answeredAfter: const Duration(seconds: 30),
      ),
      _incident(
        'inc_old2',
        'nas-backup',
        opened: ago(20, 8),
        state: IncidentStates.closed,
        answeredAfter: const Duration(seconds: 30),
      ),
    ],
  ];
  server.seedState(
    incidents: incidents,
    messages: [for (final i in incidents) ...i.messages],
  );
}

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    // History reads the plan from the saved account, so give it a free one.
    'device_id': 'dev_capture',
    'device_token': 'dv_capture',
    'account_id': 'acc_capture',
    'account_tier': 'free',
    'account_caps':
        '{"devices":5,"critical_topics":2,"p4_daily":50,"history_days":7}',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  _seed(getIt<MockServer>(), scene);
  final fixed = scene.fixed;
  if (fixed != null) {
    await getIt.unregister<HistoryCubit>();
    getIt.registerFactory<HistoryCubit>(() => _FixedHistory(fixed()));
  }
}

Future<GoRouter> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
  required GlobalKey key,
  bool animate = false,
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
            disableAnimations: !animate,
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
  router.go('/history');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 600));

  if (scene.name.startsWith('filtered')) {
    // A filter applied once the list has loaded.
    final cubit = BlocProvider.of<HistoryCubit>(
      tester.element(find.byType(HistoryHero)),
    );
    final expired = HistoryFilter.none.toggleState(IncidentState.expired);
    cubit.applyFilter(
      scene.name == 'filteredempty'
          ? expired.withWindow(HistoryWindows.day)
          : expired,
    );
    await tester.pump(const Duration(milliseconds: 600));
  }
  if (scene.scrollToEnd) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
    await tester.pump(const Duration(seconds: 1));
  }
  return router;
}

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
    for (final (phoneName, phone, mode, scale) in _variants(scene.name)) {
      final name = '${scene.name}_${phoneName}_${mode.name}_${scale}x';
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

  // A pull to refresh, stepped: the face while the list is pulled, while it
  // works, and when it is done.
  if (wanted.isEmpty || wanted.contains('refresh')) {
    testWidgets('capture refresh', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      addTearDown(() => FlutterError.onError = oldHandler);

      final key = GlobalKey();
      await _open(
        tester,
        _scenes.first,
        phone: const Size(390, 844),
        mode: ThemeMode.light,
        scale: 1,
        key: key,
        animate: true,
      );
      final gesture = await tester.startGesture(const Offset(200, 500));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 100));
      await _save(tester, key, 'refresh_0_pulling', errors);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      await _save(tester, key, 'refresh_1_working', errors);
      // The mock server answers in real time, so wait for the result line.
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 150));
        final refresh = RefreshFaceScope.maybeOf(
          tester.element(find.byType(HistoryHero)),
        );
        if (refresh?.phase == RefreshFacePhase.success) break;
      }
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, key, 'refresh_2_success', errors);
      await tester.pump(const Duration(seconds: 3));
      await _save(tester, key, 'refresh_3_after', errors);
      for (final e in errors) {
        print('  ERROR: ${e.split('\n').first}');
      }
      expect(errors, isEmpty, reason: 'overflow or build error in refresh');
    });
  }
}
