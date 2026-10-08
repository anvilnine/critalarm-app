// Captures the real Topic screen against the mock server, off the device.
//
//   fvm flutter test tool/capture_topic_screen.dart
//
// It boots the app's own dependencies on the mock server, seeds one state,
// opens Home, pushes the topic and writes a PNG named
// <state>_<phone>_<theme>_<scale>x.png. The path of every file is printed.
// The pane scenes open Home on a tablet and pick the topic in the second pane.
//
// It draws the app's ambient canvas the way the app does (AppAmbientShell),
// so the hero's disc and ring are the canvas's.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=STATES=a,b     only these states
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=T=<seconds>    let motion run this long before the capture
//                                (default: motion held, the resting frame)
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_examples.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
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
const _t = String.fromEnvironment('T');

const _longName = 'payments-service-eu-west-primary-db-replica-lag';

/// One thing the Topic screen can be, and how the capture sets it up.
class _Scene {
  const _Scene(
    this.name,
    this.topic, {
    this.seed,
    this.isPane = false,
    this.isExample = false,
    this.extra = false,
  });

  final String name;

  /// The topic the screen opens on.
  final String topic;

  /// Fills the mock server on top of the calm fixture, or replaces it.
  final void Function(MockServer server, DateTime now)? seed;

  /// Home on a tablet with the topic in the second pane.
  final bool isPane;

  /// The guide's made-up topic, drawn without a server.
  final bool isExample;

  /// Also captured at 375 by 667 and at text scales 1.3 and 2.0.
  final bool extra;
}

Message _msg(
  String topic,
  int n,
  DateTime now, {
  String? title,
  String? body,
  int priority = 3,
  List<String> tags = const [],
}) => Message(
  id: 'm_cap_${topic}_$n',
  topic: topic,
  time:
      now.subtract(Duration(minutes: 7 * n + 3)).millisecondsSinceEpoch ~/ 1000,
  title: title ?? (n.isEven ? 'Back up' : 'Down'),
  message:
      body ??
      (n.isEven
          ? 'api.example.com is back up after 4 min. Status 200, 312 ms.'
          : 'api.example.com is down. Connection timed out after 10 s.'),
  priority: priority,
  tags: tags,
);

void _offWithMessages(MockServer server, DateTime now) {
  server
    ..seedCalm()
    ..seedState(
      messages: [
        for (var i = 1; i >= 0; i--)
          _msg('nas-backup', i, now, tags: const ['backup']),
      ],
    );
}

void _manyMessages(MockServer server, DateTime now) {
  server
    ..seedCalm()
    ..seedState(
      messages: [
        for (var i = 13; i >= 0; i--)
          _msg(
            'prod-db',
            i,
            now,
            priority: i == 1 ? 4 : 3,
            tags: i == 0 ? const ['database', 'critical'] : const [],
          ),
      ],
    );
}

/// Five messages stored out of order. The screen must show the newest three,
/// newest first: "Newest", "Second", "Third".
void _unsortedMessages(MockServer server, DateTime now) {
  const names = ['Newest', 'Second', 'Third', 'Fourth', 'Fifth'];
  server
    ..seedCalm()
    ..seedState(
      messages: [
        for (final i in const [1, 0, 4, 2, 3])
          _msg('prod-db', i, now, title: names[i], body: 'Message number $i.'),
      ],
    );
}

/// Message rows over the date forms: one from today, two from yesterday a
/// minute apart with a title long enough to wrap, then (in `datesold`) one
/// from earlier this year and two from other years.
Message _at(
  String topic,
  int n,
  DateTime at, {
  String title = 'Disk almost full',
}) => Message(
  id: 'm_cap_${topic}_at_$n',
  topic: topic,
  time: at.millisecondsSinceEpoch ~/ 1000,
  title: title,
  message: 'Volume /data is at 94 percent.',
  priority: 3,
  tags: const [],
);

void _datesRecent(MockServer server, DateTime now) {
  final local = now.toLocal();
  final midnight = DateTime(local.year, local.month, local.day);
  const long = 'Replica lag over 30 seconds on the primary replica in eu-west';
  server
    ..seedCalm()
    ..seedState(
      messages: [
        _at('prod-db', 0, midnight.add(const Duration(minutes: 1))),
        _at(
          'prod-db',
          1,
          midnight.subtract(const Duration(hours: 23, minutes: 15)),
          title: long,
        ),
        _at(
          'prod-db',
          2,
          midnight.subtract(const Duration(hours: 23, minutes: 16)),
          title: long,
        ),
      ],
    );
}

void _datesOld(MockServer server, DateTime utcNow) {
  final now = utcNow.toLocal();
  server
    ..seedCalm()
    ..seedState(
      messages: [
        _at('prod-db', 0, DateTime(now.year, now.month, now.day - 9, 0, 45)),
        _at('prod-db', 1, DateTime(now.year - 1, now.month, now.day, 0, 45)),
        _at('prod-db', 2, DateTime(now.year - 1, now.month, now.day, 0, 44)),
      ],
    );
}

void _seedLongName(MockServer server, DateTime now) {
  server
    ..seedCalm()
    ..seedState(
      topics: [Topic(name: _longName, createdAt: now)],
      messages: [
        _msg(
          _longName,
          0,
          now,
          title:
              'Replica lag over 30 seconds on the primary replica in eu-west',
          body:
              'Replication delay stayed above the limit for ten minutes. '
              'Writes are still going through.',
        ),
      ],
    );
}

const _scenes = <_Scene>[
  _Scene('on', 'prod-db', extra: true),
  _Scene('off', 'nas-backup', seed: _offWithMessages, extra: true),
  _Scene('empty', 'home-ha'),
  _Scene('many', 'prod-db', seed: _manyMessages),
  _Scene('unsorted', 'prod-db', seed: _unsortedMessages),
  _Scene('dates', 'prod-db', seed: _datesRecent, extra: true),
  _Scene('datesold', 'prod-db', seed: _datesOld),
  _Scene('longname', _longName, seed: _seedLongName, extra: true),
  _Scene('warning', 'nas-backup', seed: _worried),
  _Scene('pane', 'prod-db', isPane: true),
  _Scene('example', 'example', isExample: true),
];

void _worried(MockServer server, DateTime now) => server.seedWorried();

/// The phones, themes and text sizes each state is captured at.
List<(String, Size, ThemeMode, double)> _variants(_Scene scene) => scene.isPane
    ? [
        ('1024x768', const Size(1024, 768), ThemeMode.light, 1.0),
        ('1024x768', const Size(1024, 768), ThemeMode.dark, 1.0),
      ]
    : [
        ('390x844', const Size(390, 844), ThemeMode.light, 1.0),
        ('390x844', const Size(390, 844), ThemeMode.dark, 1.0),
        if (scene.extra) ...[
          ('375x667', const Size(375, 667), ThemeMode.light, 1.0),
          ('390x844', const Size(390, 844), ThemeMode.light, 1.3),
          ('375x667', const Size(375, 667), ThemeMode.light, 1.3),
          ('390x844', const Size(390, 844), ThemeMode.light, 2.0),
        ],
      ];

class _FixedSource implements ReliabilityCheckSource {
  _FixedSource(this.checks);

  final List<ReliabilityCheck> checks;

  @override
  Future<List<ReliabilityCheck>> read() async => checks;
}

class _NoMissedFeed implements MissedAlarmFeed {
  @override
  Future<MissedFact?> read() async => null;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {}
}

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  final server = getIt<MockServer>();
  final seed = scene.seed;
  if (seed == null) {
    server.seedCalm();
  } else {
    seed(server, DateTime.now().toUtc());
  }
  await getIt.unregister<ReliabilityCubit>();
  getIt.registerLazySingleton<ReliabilityCubit>(
    () => ReliabilityCubit([
      _FixedSource([
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
      ]),
    ]),
  );
  await getIt.unregister<MissedAlarmFeed>();
  getIt.registerLazySingleton<MissedAlarmFeed>(_NoMissedFeed.new);
}

Future<void> _settle(WidgetTester tester) async {
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
}

/// A few more frames, so a frame that failed a layout assertion is laid out
/// again before the capture.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _app(
  ThemeMode mode,
  double scale,
  bool animate,
  GlobalKey key, {
  required GoRouter router,
}) => BlocProvider<ThemeCubit>.value(
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
);

/// Opens the scene's screen at [phone] and lets it settle.
Future<void> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
  required bool animate,
  required GlobalKey key,
}) async {
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  if (scene.isExample || !animate) {
    // The guide's made-up topic, or the resting frame: the screen on its own,
    // with no router and no canvas, so it draws its own disc. A pushed page
    // keeps the page under it drawn when reduce motion is on (the page is not
    // opaque and the transition that fades the old one out is skipped), so a
    // pushed capture would show both.
    final cubit = scene.isExample
        ? (TopicDetailCubit(
            getIt(),
            getIt(),
            getIt(),
            getIt(),
          )..showExample(FeatureGuideExamples.topicDetail()))
        : null;
    if (cubit != null) addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: !animate,
          ),
          child: RepaintBoundary(
            key: key,
            // The canvas is the shell's in the app, so the scene draws no
            // disc of its own there. Say so here too.
            child: scene.isExample
                ? AmbientScope(
                    child: ColoredBox(
                      color: Theme.of(context).extension<AppColors>()!.canvas,
                      child: child,
                    ),
                  )
                : child,
          ),
        ),
        home: BlocProvider<ThemeCubit>.value(
          value: getIt<ThemeCubit>(),
          child: TopicDetailScreen(
            topicName: scene.isExample ? 'example' : scene.topic,
            cubit: cubit,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    if (!scene.isExample) {
      // The mock server answers in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }
    return;
  }

  final router = buildRouter();
  await tester.pumpWidget(_app(mode, scale, animate, key, router: router));
  router.go('/');
  await _settle(tester);
  if (scene.isPane) {
    await tester.tap(find.text(scene.topic).first);
    await _settle(tester);
    return;
  }
  unawaited(router.push('/topics/${scene.topic}'));
  await _settle(tester);
  // The push runs on the fake clock, so give it all the time it needs.
  await tester.pump(const Duration(seconds: 2));
  await _frames(tester);
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

/// The one layout assertion that reduce motion trips. An `AnimatedSize` with a
/// zero duration marks itself dirty while it lays out when its child changes
/// size. Nineteen widgets in the app are built that way, the tokens block on
/// this screen among them, and the assertion exists in a debug build only.
bool _isKnownReduceMotionAssert(String error) =>
    error.contains('RenderAnimatedSize was mutated in its own performLayout');

void main() {
  final wanted = _statesArg.split(',').where((s) => s.isNotEmpty).toSet();
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();
  final second = double.tryParse(_t);

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  // Every state with motion on, after three seconds, so each fade and each
  // size change has finished. The disc, the dots and the face are wherever
  // their loops are at that second.
  //
  // `rest` is the same screen with reduce motion on: the resting frame.
  for (final scene in _scenes) {
    if (wanted.isNotEmpty && !wanted.contains(scene.name)) continue;
    final variants = [
      for (final v in _variants(scene)) (v.$1, v.$2, v.$3, v.$4, ''),
      if (scene.extra)
        ('390x844', const Size(390, 844), ThemeMode.light, 1.0, '_rest'),
      if (scene.extra || scene.name == 'many')
        ('390x844', const Size(390, 844), ThemeMode.light, 1.0, '_end'),
    ];
    for (final (phoneName, phone, mode, scale, kind) in variants) {
      final rest = kind == '_rest';
      final name =
          'topic_${scene.name}_${phoneName}_${mode.name}_${scale}x$kind';
      if (onlyParts.isNotEmpty && !onlyParts.any(name.contains)) continue;
      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          if (rest && _isKnownReduceMotionAssert(text)) {
            print('  NOTE: $text');
            return;
          }
          errors.add(d.toString());
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        final key = GlobalKey();
        await _open(
          tester,
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
          animate: !rest,
          key: key,
        );
        if (!rest) {
          await tester.pump(
            Duration(milliseconds: ((second ?? 3) * 1000).round()),
          );
        }
        await _frames(tester);
        if (kind == '_end' && !scene.isPane && !scene.isExample) {
          // Scroll to the foot of the page: Delete topic.
          await tester.scrollUntilVisible(
            find.text('Delete topic'),
            400,
            scrollable: find
                .descendant(
                  of: find.byType(TopicDetailScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump(const Duration(seconds: 1));
          await _frames(tester);
        }
        await _save(tester, key, name, errors);
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').take(40).join('\n')}');
        }
        expect(errors, isEmpty, reason: 'overflow or build error in $name');
      });
    }
  }
}
