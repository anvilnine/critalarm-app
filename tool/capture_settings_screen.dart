// Captures the real Settings screen against the mock server, off the device.
//
//   fvm flutter test tool/capture_settings_screen.dart
//
// It boots the app's own dependencies on the mock server, seeds one state,
// opens Settings and writes a PNG named
// <state>_<phone>_<theme>_<scale>x.png. The first state is also captured at
// 375 by 667 and at text scales 1.3 and 2.0. The path of every file is
// printed. The bottom_* states scroll the screen to its end, to show that no
// row went missing.
//
// It draws the app's ambient canvas the way the app does (AppAmbientShell).
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=STATES=a,b     only these states
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// The checks are handed fixed answers, because a test run has no phone to
// read them from. The plan states hand the Settings cubit a fixed account.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/domain/repositories/storage_settings_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
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

/// Which plan the account holds in a scene.
enum _Plan { calm, freeAtCap, hosted, selfHosted }

/// One thing Settings can be, and how the capture sets it up.
class _Scene {
  const _Scene(
    this.name, {
    this.checks = _fineChecks,
    this.loaded = true,
    this.incomplete = false,
    this.plan = _Plan.calm,
    this.scrollToEnd = false,
  });

  final String name;
  final List<ReliabilityCheck> Function() checks;
  final bool loaded;
  final bool incomplete;
  final _Plan plan;
  final bool scrollToEnd;
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

List<ReliabilityCheck> _with(
  ReliabilityCheckId id,
  ReliabilityState state, {
  String? reason,
  ReliabilityFix? fix,
}) => [
  for (final c in _fineChecks())
    if (c.id == id)
      ReliabilityCheck(id: id, state: state, reason: reason, fix: fix)
    else
      c,
];

List<ReliabilityCheck> _lookChecks() => _with(
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityState.needsLook,
  reason: 'on',
  fix: const OpenRouteFix('permissions'),
);

List<ReliabilityCheck> _brokenChecks() => _with(
  ReliabilityCheckIds.notifications,
  ReliabilityState.broken,
  reason: 'denied',
  fix: const OpenRouteFix('permissions'),
);

const _scenes = <_Scene>[
  _Scene('fine'),
  _Scene('look', checks: _lookChecks),
  _Scene('broken', checks: _brokenChecks),
  _Scene('notloaded', loaded: false),
  _Scene('incomplete', incomplete: true),
  _Scene('freecap', plan: _Plan.freeAtCap, scrollToEnd: true),
  _Scene('hosted', plan: _Plan.hosted, scrollToEnd: true),
  _Scene('selfhosted', plan: _Plan.selfHosted, scrollToEnd: true),
  _Scene('bottom', scrollToEnd: true),
  _Scene('bottomlook', checks: _lookChecks, scrollToEnd: true),
];

/// The phones, themes and text sizes each state is captured at.
List<(String, Size, ThemeMode, double)> _variants(String scene) => [
  ('390x844', const Size(390, 844), ThemeMode.light, 1.0),
  ('390x844', const Size(390, 844), ThemeMode.dark, 1.0),
  if (scene == 'fine' || scene == 'look') ...[
    ('375x667', const Size(375, 667), ThemeMode.light, 1.0),
    ('390x844', const Size(390, 844), ThemeMode.light, 1.3),
    ('390x844', const Size(390, 844), ThemeMode.light, 2.0),
  ],
  if (scene == 'look') ...[
    ('375x667', const Size(375, 667), ThemeMode.dark, 1.0),
    ('390x844', const Size(390, 844), ThemeMode.dark, 2.0),
  ],
];

/// Answers with the checks the scene says.
class _FixedSource implements ReliabilityCheckSource {
  _FixedSource(this.checks);

  final List<ReliabilityCheck> checks;

  @override
  Future<List<ReliabilityCheck>> read() async => checks;
}

/// A reliability cubit that stays in the state before the first read.
class _NeverLoaded extends ReliabilityCubit {
  _NeverLoaded() : super(const []);

  @override
  Future<void> refresh() async {}
}

/// A Settings cubit that reads what the mock server gives, then takes the
/// plan the scene says.
class _PlanSettings extends SettingsCubit {
  _PlanSettings(this.plan)
    : super(
        holdings: getIt<Holdings>(),
        featureAccess: getIt<FeatureAccess>(),
        identityStore: getIt(),
        apiSessions: getIt<ApiSessionStore>(),
        getTopics: getIt<GetTopicsUsecase>(),
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        storageSettings: getIt<StorageSettingsRepository>(),
      );

  final _Plan plan;

  @override
  Future<void> load({bool forceDisconnected = false}) async {
    await super.load(forceDisconnected: forceDisconnected);
    if (isClosed) return;
    switch (plan) {
      case _Plan.calm:
        break;
      case _Plan.freeAtCap:
        emit(
          state.copyWith(
            holdsHosted: false,
            access: const AccountAccess(
              DeviceIdentity(
                deviceId: 'dev_capture',
                accountId: 'acc_capture',
                caps: AccountCaps.free,
              ),
            ),
            topics: const [
              Topic(name: 'prod-db', critical: true),
              Topic(name: 'nas-backup', critical: true),
              Topic(name: 'uptime-kuma'),
            ],
          ),
        );
      case _Plan.selfHosted:
        emit(
          state.copyWith(
            serverMode: ServerMode.selfhosted,
            isConnected: true,
            hasStorageSection: true,
          ),
        );
      case _Plan.hosted:
        emit(
          state.copyWith(
            holdsHosted: true,
            access: const AccountAccess(
              DeviceIdentity(
                deviceId: 'dev_capture',
                accountId: 'acc_capture',
                tier: 'pro',
              ),
            ),
            topics: const [
              Topic(name: 'prod-db', critical: true),
              Topic(name: 'nas-backup', critical: true),
              Topic(name: 'home-ha', critical: true),
            ],
            hasStorageSection: true,
          ),
        );
    }
  }
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
    // A source that does not answer leaves a hole in the read.
    return ReliabilityCubit([
      _FixedSource(scene.checks()),
      if (scene.incomplete) _ThrowingSource(),
    ]);
  });
  if (scene.plan != _Plan.calm) {
    await getIt.unregister<SettingsCubit>();
    getIt.registerFactory<SettingsCubit>(() => _PlanSettings(scene.plan));
  }
}

class _ThrowingSource implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => throw StateError('no answer');
}

/// Opens Settings on [scene] at [phone] and lets it settle.
Future<void> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
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
            // Reduce motion: every animation shows its resting frame.
            disableAnimations: true,
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
  router.go('/settings');
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
  if (scene.scrollToEnd) {
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 300));
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
    for (final (phoneName, phone, mode, scale) in _variants(scene.name)) {
      final name = 'settings_${scene.name}_${phoneName}_${mode.name}_${scale}x';
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
}
