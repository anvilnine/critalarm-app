// Captures the alarm screen of the setup test with its sample message, off
// the device, with the mock API and a made-up setup.
//
//   fvm flutter test tool/capture_alarm_sample.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// It opens the real alarm screen on an incident the mock server made, saves
// the answer and the setup test id the way setup does, and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced].png. The path of every file is
// printed.
//
// Scenes:
//   ringing_servers        the setup test, answer "My servers and apps"
//   ringing_homelab        the setup test, answer "My homelab"
//   ringing_jobs           the setup test, answer "Builds and scheduled jobs"
//   ringing_home           the setup test, answer "My home"
//   ringing_other          the setup test, answer "Something else": the
//                          server's own words
//   ringing_real_incident  a real incident with an answer saved: unchanged
//   acked_servers          the setup test after "I'm up"
//   first_frame_servers    the first frame that draws the alarm, before the
//                          ring has settled
//   first_frame_acked      the first frame after "I'm up"
//   ack_mid                part way through the change to the acknowledged
//                          screen
//
// Every scene that opens the setup test checks that no frame, from the first
// pump on, holds the server's title.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

/// What the mock server writes for its test alarm. The title is the real
/// server's; its message is the mock's own.
const _serverTitle = 'Crit Alarm test';
const _serverBody = 'Crit Alarm test alarm';

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 640), 24, 0);

/// Which incident a scene opens.
enum _Opens {
  /// The test alarm the server opened for setup, its id saved.
  setupTest,

  /// A real incident.
  real,
}

class _Scene {
  const _Scene(
    this.name, {
    this.use,
    this.opens = _Opens.setupTest,
    this.isAcked = false,
    this.stopsAtFirstFrame = false,
    this.midAckMs,
  });

  final String name;

  /// The answer saved on the phone, or null for none.
  final SetupUse? use;
  final _Opens opens;

  /// "I'm up" is tapped before the capture.
  final bool isAcked;

  /// The capture is the first frame that draws the alarm, taken before the
  /// ring has settled.
  final bool stopsAtFirstFrame;

  /// The capture is this many milliseconds after "I'm up".
  final int? midAckMs;
}

const _scenes = <_Scene>[
  _Scene('ringing_servers', use: SetupUse.servers),
  _Scene('ringing_homelab', use: SetupUse.homelab),
  _Scene('ringing_jobs', use: SetupUse.jobs),
  _Scene('ringing_home', use: SetupUse.home),
  _Scene('ringing_other', use: SetupUse.other),
  _Scene('ringing_real_incident', use: SetupUse.servers, opens: _Opens.real),
  _Scene('acked_servers', use: SetupUse.servers, isAcked: true),
  _Scene('first_frame_servers', use: SetupUse.servers, stopsAtFirstFrame: true),
  _Scene(
    'first_frame_acked',
    use: SetupUse.servers,
    isAcked: true,
    stopsAtFirstFrame: true,
  ),
  _Scene('ack_mid', use: SetupUse.servers, isAcked: true, midAckMs: 120),
];

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await configureDependencies();
    await loadAppFonts();
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    double scale = 1,
    bool isReduced = false,
  }) {
    final name =
        '${scene.name}_${phone.name}_${mode.name}_${scale}x'
        '${isReduced ? '_reduced' : ''}';
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());

      const dpr = 2.0;
      tester.view.physicalSize = phone.size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.view.padding = FakeViewPadding(
        top: phone.top * dpr,
        bottom: phone.bottom * dpr,
      );
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);

      // A made-up setup: one critical topic, the test alarm the server
      // opened for it, and the answer saved on the phone.
      final server = getIt<MockServer>()
        ..reset()
        ..seedState(topics: [const Topic(name: 'prod-db', critical: true)]);
      final String incidentId;
      switch (scene.opens) {
        case _Opens.setupTest:
          incidentId = server.triggerTest(topic: 'prod-db');
        case _Opens.real:
          incidentId =
              server
                  .publishMessage(
                    'prod-db',
                    title: 'Primary database down',
                    message: 'Connection pool exhausted',
                    priority: 5,
                  )
                  .incidentId ??
              '';
      }
      final store = getIt<SetupUseStore>();
      final ring = getIt<SetupTestRing>();
      await ring.clear();
      await store.clear();
      if (scene.use != null) await store.save(scene.use!);
      if (scene.opens == _Opens.setupTest) await ring.hold(incidentId);

      final isSample =
          scene.opens == _Opens.setupTest &&
          scene.use != null &&
          scene.use != SetupUse.other;

      final boundaryKey = GlobalKey();
      final semantics = tester.ensureSemantics();
      debugDisableShadows = false;
      final router = buildRouter(initialLocation: '/incidents/$incidentId');
      var frames = 0;
      var framesWithServerTitle = 0;

      /// One frame, and a check that it never holds the server's title for
      /// the setup test when the answer has a sample.
      Future<void> pump([
        Duration by = const Duration(milliseconds: 16),
      ]) async {
        await tester.pump(by);
        frames++;
        if (isSample && find.text(_serverTitle).evaluate().isNotEmpty) {
          framesWithServerTitle++;
        }
      }

      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
              BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: isReduced,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: AppAmbientShell(
                    router: router,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
        frames++;

        // Frame by frame until the loading screen is gone, so the first
        // frame that draws the alarm is the one seen. The mock answers
        // without a timer.
        var guard = 0;
        while (guard++ < 60 &&
            (CriticalAlarmCubit.current?.state.status !=
                    CriticalAlarmStatus.ringing ||
                find.text('Loading the alarm').evaluate().isNotEmpty)) {
          await pump();
        }
        final cubit = CriticalAlarmCubit.current!;
        expect(cubit.state.status, CriticalAlarmStatus.ringing);

        if (!scene.stopsAtFirstFrame || scene.isAcked) {
          // The ring settles.
          for (var i = 0; i < 8; i++) {
            await pump(const Duration(milliseconds: 150));
          }
        }

        if (scene.isAcked) {
          // "I'm up", through the same call the button makes.
          await tester.runAsync(cubit.acknowledge);
          if (scene.midAckMs != null) {
            await pump(Duration(milliseconds: scene.midAckMs!));
          } else if (scene.stopsAtFirstFrame) {
            await pump();
          } else {
            // Long enough for the three ticks to settle.
            for (var i = 0; i < 20; i++) {
              await pump(const Duration(milliseconds: 200));
            }
          }
        }

        // What the screen holds, against what the scene stands for.
        if (isSample && scene.isAcked) {
          // The setup test's acknowledged screen lists what was proved and
          // draws no message, so only the server's words are ruled out.
          expect(find.text(_serverTitle), findsNothing);
          expect(find.text(_serverBody), findsNothing);
          expect(cubit.state.title, _sampleFor(scene.use!));
          expect(framesWithServerTitle, 0);
        } else if (isSample) {
          final sample = _sampleFor(scene.use!);
          expect(find.text(sample), findsOneWidget);
          expect(
            find.text('This is what a real one looks like.'),
            findsOneWidget,
          );
          expect(find.text(_serverTitle), findsNothing);
          expect(find.text(_serverBody), findsNothing);
          expect(
            framesWithServerTitle,
            0,
            reason:
                'the server title was drawn in $framesWithServerTitle of '
                '$frames frames',
          );
        } else if (scene.opens == _Opens.real) {
          expect(find.text('Primary database down'), findsOneWidget);
          expect(find.text('Connection pool exhausted'), findsOneWidget);
        } else {
          // Something else: the server's own words.
          expect(find.text(_serverTitle), findsOneWidget);
          expect(find.text(_serverBody), findsOneWidget);
        }

        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: dpr);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          print(
            '${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path} '
            '(frames $frames, with server title $framesWithServerTitle)',
          );
        });

        if (scene.isAcked) {
          // Past the wait for the follow-up the acknowledge may open, so no
          // timer outlives the capture.
          await tester.pump(const Duration(seconds: 2));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(seconds: 1));
        }
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        semantics.dispose();
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
        await ring.clear();
        await store.clear();
      }
    });
  }

  // The matrix: both themes, a 320 wide phone and a normal one, three text
  // sizes, and the settled frame under reduced motion. The scenes that catch
  // a moment keep to two sizes and the motion that is on.
  for (final scene in _scenes) {
    final isMoment = scene.stopsAtFirstFrame || scene.midAckMs != null;
    for (final phone in [_phone, _narrow]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in isMoment ? [1.0, 2.0] : [1.0, 1.3, 2.0]) {
          capture(scene, phone: phone, mode: mode, scale: scale);
          if (!isMoment) {
            capture(
              scene,
              phone: phone,
              mode: mode,
              scale: scale,
              isReduced: true,
            );
          }
        }
      }
    }
  }
}

String _sampleFor(SetupUse use) => switch (use) {
  SetupUse.servers => 'Replication lag 14 min',
  SetupUse.homelab => 'Nextcloud is down',
  SetupUse.jobs => 'Nightly backup missed its check-in',
  SetupUse.home => 'Freezer is above -10 C',
  SetupUse.other => '',
};
