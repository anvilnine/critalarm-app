// Captures the real Topic screen against the mock server, off the device.
//
//   fvm flutter test tool/capture_topic_screen.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// SKIP_PAYWALL turns the developer plan switches on, which the `stack` part
// needs to hold or lift a plan.
//
// It boots the app's own dependencies on the mock server, seeds one state,
// opens Home, pushes the topic and writes a PNG named
// <state>_<phone>_<theme>_<scale>x.png. The path of every file is printed.
// The pane scenes open Home on a tablet and pick the topic in the second pane.
//
// It draws the app's ambient canvas the way the app does (AppAmbientShell),
// so the hero's disc and ring are the canvas's.
//
// Two parts, picked with --dart-define=PARTS=screen,stack (default: both):
//   screen   the whole screen in every state, named topic_<state>_...
//   stack    the pass stack at the foot of the sheet, named
//            stack_<state>_<phone>_<theme>_<scale>x_<frame>.png: following
//            the phone, its own look, sound and challenge, a locked plan, a
//            plan not read, the example topic, the tokens loading then two
//            then six, a long topic name and a long sound name, light, dark,
//            320 wide, text scale 1.3 and 2.0 (the flat stack), reduce
//            motion, the whole screen at full height, and the grow into the
//            Look, Sound and Wake-up challenge pages at 0, 0.5 and 1.
//
//   firstframe  the first frame of the screen opened from the Topics list,
//            against the frame once its reads have finished. Not in the
//            default parts. Needs PARTS=firstframe. See
//            _registerFirstFrameCaptures.
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
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_examples.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_hero_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';
import 'capture_pass_kit.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _statesArg = String.fromEnvironment('STATES');
const _only = String.fromEnvironment('ONLY');
const _t = String.fromEnvironment('T');
const _partsArg = String.fromEnvironment('PARTS');

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
    this.plan,
    this.prepare,
    this.isLoadingHeld = false,
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

  /// The plan the phone holds, or null for the developer default.
  final PassPlanState? plan;

  /// Saves what the stack shows (a look, a sound, a challenge, more tokens)
  /// once the app is booted.
  final Future<void> Function(MockServer server)? prepare;

  /// Captures before the mock server has answered, so the tokens and the
  /// sound are still loading.
  final bool isLoadingHeld;
}

/// The preferences that hold [plan], as the developer switches save them.
Map<String, Object> _planPrefs(PassPlanState plan) {
  final preset = plan.preset;
  return {
    if (preset != null)
      for (final entry in preset.holdings.entries)
        DevAccessSwitches.holdingKey(entry.key): entry.value.name,
    if (preset != null && preset.holdsPlanRead)
      DevAccessSwitches.holdsPlanReadKey: true,
    // The kit's plan not read yet holds the plan read open.
    if (!plan.isPlanRead) DevAccessSwitches.holdsPlanReadKey: true,
    if (plan.isOwnServer) DevAccessSwitches.serverModeKey: 'ownServer',
  };
}

/// A sound of the user's own with a name that has to be cut.
const _longSoundName =
    'Morning rooster recorded at the farm with the barn door open';

AlarmSound _ownSound(String name) => AlarmSound(
  id: 'user_capture',
  name: name,
  source: AlarmSoundSource.user,
  path: '/sounds/user_capture.caf',
  duration: const Duration(seconds: 4),
  peaks: [for (var i = 0; i < 48; i++) 0.25 + 0.7 * ((i * 7) % 11) / 10],
);

/// Everything the card of a topic can hold of its own: a look, a sound, a
/// challenge and more tokens.
Future<void> _ownThings(MockServer server) async {
  await getIt<AlarmStyleChoices>().setTopicStyle('prod-db', 'terminal');
  await getIt<AlarmSoundRepository>().setTopicSoundId(
    'prod-db',
    'pager_beep',
  );
  await getIt<ChallengeChoices>().setChoice('prod-db', ChallengeKind.opsMath);
  server.createTopicToken('prod-db');
}

/// The same, on a plan that holds none of it: the look and the challenge are
/// saved but do not ring, and the sound is an own one.
Future<void> _ownThingsLocked(MockServer server) async {
  await getIt<AlarmStyleChoices>().setTopicStyle('prod-db', 'terminal');
  final sounds = getIt<AlarmSoundRepository>();
  await sounds.addUserSound(_ownSound('My voice'));
  await sounds.setTopicSoundId('prod-db', 'user_capture');
  await getIt<ChallengeChoices>().setChoice('prod-db', ChallengeKind.opsMath);
}

Future<void> _longSound(MockServer server) async {
  final sounds = getIt<AlarmSoundRepository>();
  await sounds.addUserSound(_ownSound(_longSoundName));
  await sounds.setTopicSoundId('prod-db', 'user_capture');
}

Future<void> Function(MockServer) _moreTokens(int total) => (server) async {
  for (var i = 1; i < total; i++) {
    server.createTopicToken('prod-db');
  }
};

/// The scenes of the `stack` part. The plan holds the Pro pack unless a scene
/// says otherwise, so every card can show what a topic holds.
final _stackScenes = <_Scene>[
  const _Scene('follows', 'prod-db', plan: PassPlanState.pro),
  const _Scene(
    'own',
    'prod-db',
    plan: PassPlanState.pro,
    prepare: _ownThings,
  ),
  const _Scene(
    'locked',
    'prod-db',
    plan: PassPlanState.free,
    prepare: _ownThingsLocked,
  ),
  const _Scene('notread', 'prod-db', plan: PassPlanState.notRead),
  const _Scene(
    'example',
    'example',
    isExample: true,
    plan: PassPlanState.pro,
  ),
  const _Scene(
    'tokens0',
    'prod-db',
    plan: PassPlanState.pro,
    isLoadingHeld: true,
  ),
  _Scene(
    'tokens2',
    'prod-db',
    plan: PassPlanState.pro,
    prepare: _moreTokens(2),
  ),
  _Scene(
    'tokens6',
    'prod-db',
    plan: PassPlanState.pro,
    prepare: _moreTokens(6),
  ),
  const _Scene(
    'longname',
    _longName,
    seed: _seedLongName,
    plan: PassPlanState.pro,
  ),
  const _Scene(
    'longsound',
    'prod-db',
    plan: PassPlanState.pro,
    prepare: _longSound,
  ),
];

/// Lets the sound host answer a read of peaks, so the Sound card's bars move.
void _mockSoundHost() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(SoundHost.channelName),
          (call) async => switch (call.method) {
            'readPeaks' => <double>[
              for (var i = 0; i < 48; i++) 0.2 + 0.75 * ((i * 5) % 9) / 8,
            ],
            'capabilities' => <String, Object?>{'can_import_sounds': false},
            _ => null,
          },
        );
  addTearDown(
    () => messenger.setMockMethodCallHandler(
      const MethodChannel(SoundHost.channelName),
      null,
    ),
  );
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
    if (scene.plan != null) ..._planPrefs(scene.plan!),
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
  await scene.prepare?.call(server);
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
  _mockSoundHost();
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  if (scene.isExample || scene.isLoadingHeld || !animate) {
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
            isExample: scene.isExample,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    if (!scene.isExample && !scene.isLoadingHeld) {
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

Set<String> get _parts =>
    _partsArg.isEmpty ? {'screen', 'stack'} : _partsArg.split(',').toSet();

/// Scrolls the screen to its foot, where the stack and Delete topic are.
Future<void> _toFoot(WidgetTester tester) async {
  final delete = find.text('Delete topic');
  if (delete.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(
    delete,
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

/// Runs [body] with every framework error collected, then fails on one.
Future<void> _guarded(
  String name,
  Future<void> Function(List<String> errors) body, {
  bool isRest = false,
}) async {
  final errors = <String>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (d) {
    final text = d.exceptionAsString();
    if (isRest && _isKnownReduceMotionAssert(text)) {
      print('  NOTE: $text');
      return;
    }
    errors.add(d.toString());
  };
  debugDisableShadows = false;
  try {
    await body(errors);
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = oldHandler;
  }
  for (final e in errors) {
    print('  ERROR: ${e.split('\n').take(40).join('\n')}');
  }
  expect(errors, isEmpty, reason: 'overflow or build error in $name');
}

String _stackName(
  String state,
  String phone,
  ThemeMode mode,
  double scale,
  String frame,
) => 'stack_${state}_${phone}_${mode.name}_${scale}x_$frame';

/// The pass stack: one capture per state, size, theme and text scale, the
/// resting frame under reduce motion, the whole screen at full height, and
/// the grow into the three pages.
void _registerStackCaptures() {
  if (!_parts.contains('stack')) return;
  final wanted = _statesArg.split(',').where((s) => s.isNotEmpty).toSet();
  const phone = Size(390, 844);
  const narrow = Size(320, 640);
  const tall = Size(390, 1700);
  const light = ThemeMode.light;

  void shot(
    _Scene scene, {
    required String phoneName,
    required Size size,
    required ThemeMode mode,
    double scale = 1,
    String frame = 'foot',
    bool isRest = false,
  }) {
    if (wanted.isNotEmpty && !wanted.contains(scene.name)) return;
    final name = _stackName(scene.name, phoneName, mode, scale, frame);
    if (_only.isNotEmpty && !_only.split(',').any(name.contains)) return;
    testWidgets('capture $name', (tester) async {
      await _guarded(name, (errors) async {
        final key = GlobalKey();
        await _open(
          tester,
          scene,
          phone: size,
          mode: mode,
          scale: scale,
          animate: !isRest,
          key: key,
        );
        if (!isRest) await tester.pump(const Duration(seconds: 3));
        await _frames(tester);
        if (frame == 'foot' && !scene.isLoadingHeld) await _toFoot(tester);
        await _save(tester, key, name, errors);
      }, isRest: isRest);
    });
  }

  for (final scene in _stackScenes) {
    shot(scene, phoneName: '390x844', size: phone, mode: light);
    shot(scene, phoneName: '390x844', size: phone, mode: ThemeMode.dark);
  }
  final main = [
    for (final scene in _stackScenes)
      if (const {'follows', 'own', 'locked'}.contains(scene.name)) scene,
  ];
  for (final scene in main) {
    shot(scene, phoneName: '320x640', size: narrow, mode: light);
    shot(scene, phoneName: '320x640', size: narrow, mode: ThemeMode.dark);
    shot(scene, phoneName: '390x844', size: phone, mode: light, scale: 1.3);
    shot(scene, phoneName: '390x844', size: phone, mode: light, scale: 2);
    shot(scene, phoneName: '320x640', size: narrow, mode: light, scale: 2);
    shot(
      scene,
      phoneName: '390x844',
      size: phone,
      mode: light,
      frame: 'rest',
      isRest: true,
    );
    shot(
      scene,
      phoneName: '390x1700',
      size: tall,
      mode: light,
      frame: 'full',
    );
  }
  // The long values at the sizes where they are cut.
  for (final scene in _stackScenes) {
    if (!const {'longname', 'longsound'}.contains(scene.name)) continue;
    shot(scene, phoneName: '320x640', size: narrow, mode: light);
    shot(scene, phoneName: '390x844', size: phone, mode: light, scale: 2);
  }
  for (final scene in _stackScenes) {
    if (scene.name == 'example') {
      shot(
        scene,
        phoneName: '390x1700',
        size: tall,
        mode: light,
        frame: 'full',
      );
    }
    if (scene.name == 'tokens2') {
      shot(scene, phoneName: '390x844', size: phone, mode: light, scale: 2);
    }
  }

  // The grow from a card into its page, at 0, 0.5 and 1 of the route.
  final own = _stackScenes.firstWhere((scene) => scene.name == 'own');
  for (final pass in [PassId.look, PassId.sound, PassId.challenge]) {
    for (final mode in [light, ThemeMode.dark]) {
      final base = _stackName(
        'grow-${pass.name}',
        '390x844',
        mode,
        1,
        'open',
      );
      if (_only.isNotEmpty && !_only.split(',').any(base.contains)) continue;
      testWidgets('capture $base', (tester) async {
        await _guarded(base, (errors) async {
          final key = GlobalKey();
          await _open(
            tester,
            own,
            phone: phone,
            mode: mode,
            scale: 1,
            animate: true,
            key: key,
          );
          await tester.pump(const Duration(seconds: 1));
          await _toFoot(tester);
          final card = find.byKey(ValueKey('topic-pass-${pass.name}'));
          expect(card, findsOneWidget, reason: 'no card for ${pass.name}');
          await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
          // The route is built and its clock is at zero.
          await tester.pump();
          await tester.pump();
          const openMs = 600;
          var elapsed = 0;
          for (final fraction in const [0.0, 0.5, 1.0]) {
            final target = (openMs * fraction).round();
            if (target > elapsed) {
              await tester.pump(Duration(milliseconds: target - elapsed));
              elapsed = target;
            }
            final frame =
                't${(fraction * 100).round().toString().padLeft(3, '0')}';
            await _save(
              tester,
              key,
              _stackName('grow-${pass.name}', '390x844', mode, 1, frame),
              errors,
            );
          }
        });
      });
    }
  }
}

/// Starts a snapshot of [key]'s boundary at two pixels per point. The scene is
/// taken when this is called, so a frame can be held while real time passes
/// before it is read with [_pixels].
Future<ui.Image> _shoot(GlobalKey key) {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return boundary.toImage(pixelRatio: 2);
}

/// Reads a snapshot from [_shoot], writes it as `<name>.png` and returns its
/// pixels.
Future<({int width, Uint8List rgba})> _pixels(
  WidgetTester tester,
  Future<ui.Image> shot,
  String name,
) async {
  final read = await tester.runAsync(() async {
    final image = await shot;
    final raw = await image.toByteData();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    print('FIT  ${file.path}');
    final width = image.width;
    image.dispose();
    return (width: width, rgba: raw!.buffer.asUint8List());
  });
  return read!;
}

/// How many pixels of [area] differ between [a] and [b] by more than a few
/// steps in any channel, and how many pixels [area] has.
(int, int) _differing(
  ({int width, Uint8List rgba}) a,
  ({int width, Uint8List rgba}) b,
  Rect area,
) {
  var count = 0;
  var total = 0;
  for (var y = (area.top * 2).floor(); y < (area.bottom * 2).ceil(); y++) {
    for (var x = (area.left * 2).floor(); x < (area.right * 2).ceil(); x++) {
      total++;
      final at = (y * a.width + x) * 4;
      for (var c = 0; c < 4; c++) {
        if ((a.rgba[at + c] - b.rgba[at + c]).abs() > 6) {
          count++;
          break;
        }
      }
    }
  }
  return (count, total);
}

/// The first frame of the Topic screen when it is opened from the Topics
/// list, against the same screen once every read has finished.
///
/// Home is built first, so the app-level lists and the glances are filled the
/// way they are when a topic is tapped. Then the screen is built alone under
/// the app's own ambient shell, with reduce motion on so the frames are the
/// resting ones, and three frames are taken:
///
///   first    the frame `pumpWidget` builds, before anything has run
///   early    600 ms later with no read finished (the route has settled, the
///            canvas has taken the topic's profile)
///   settled  after the mock server has answered and the screen has redrawn
///
/// The Critical delivery card and the canvas behind the hero must match
/// between early and settled. The first frame still has the canvas of Home,
/// because the screen hands its profile to the shell after its first frame
/// (the push moves it across with the route). The `cold` scene has no lists
/// loaded, which is a link into a topic with nothing in memory: the card
/// shows its dots until the read ends.
///
/// Prints the number of differing pixels over the card and over everything
/// above the sheet, and the height of the Tokens pass card in each frame.
void _registerFirstFrameCaptures() {
  if (!_parts.contains('firstframe')) return;
  const phone = Size(390, 1500);
  const scene = _Scene('firstframe', 'prod-db');

  void shot({
    required String topic,
    required String label,
    required ThemeMode mode,
    required bool isWarm,
  }) {
    final base = 'firstframe_${label}_${mode.name}${isWarm ? '' : '_cold'}';
    if (_only.isNotEmpty && !_only.split(',').any(base.contains)) return;
    testWidgets('capture $base', (tester) async {
      await _guarded(base, isRest: true, (errors) async {
        _mockSoundHost();
        await tester.runAsync(() => _boot(scene));
        tester.view.physicalSize = phone * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final router = buildRouter();
        if (isWarm) {
          // Home first, so the lists and the glances are filled.
          final home = GlobalKey();
          await tester.pumpWidget(_app(mode, 1, true, home, router: router));
          router.go('/');
          await _settle(tester);
          await tester.pumpWidget(const SizedBox.shrink());
        }

        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: RepaintBoundary(
                key: key,
                child: AppAmbientShell(
                  router: router,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
            home: BlocProvider<ThemeCubit>.value(
              value: getIt<ThemeCubit>(),
              child: TopicDetailScreen(topicName: topic),
            ),
          ),
        );
        // Every snapshot is started on its frame and read afterwards, because
        // reading lets real time pass and the mock server answer.
        final firstShot = _shoot(key);
        final firstCard = tester.getRect(find.byType(TopicCriticalCard));
        final firstTokens = tester.getSize(
          find.byKey(const ValueKey('topic-pass-tokens')),
        );

        await tester.pump(const Duration(milliseconds: 600));
        await _frames(tester);
        final earlyShot = _shoot(key);

        final first = await _pixels(tester, firstShot, '${base}_1_first');
        final early = await _pixels(tester, earlyShot, '${base}_2_early');

        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 900)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await _frames(tester);
        final card = tester.getRect(find.byType(TopicCriticalCard));
        final tokens = tester.getSize(
          find.byKey(const ValueKey('topic-pass-tokens')),
        );
        final settled = await _pixels(
          tester,
          _shoot(key),
          '${base}_3_settled',
        );

        final above = Rect.fromLTRB(0, 0, phone.width, card.bottom);
        for (final (name, frame) in [('first', first), ('early', early)]) {
          final (cardPx, cardTotal) = _differing(frame, settled, card);
          final (abovePx, aboveTotal) = _differing(frame, settled, above);
          print(
            'DIFF $base $name vs settled: card $cardPx of $cardTotal px, '
            'everything above the sheet $abovePx of $aboveTotal px',
          );
        }
        print(
          'RECT $base card first $firstCard settled $card; '
          'tokens card first $firstTokens settled $tokens',
        );
      });
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    shot(topic: 'prod-db', label: 'on', mode: mode, isWarm: true);
    shot(topic: 'nas-backup', label: 'off', mode: mode, isWarm: true);
  }
  shot(topic: 'prod-db', label: 'on', mode: ThemeMode.light, isWarm: false);
}

void main() {
  final wanted = _statesArg.split(',').where((s) => s.isNotEmpty).toSet();
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();
  final second = double.tryParse(_t);

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  _registerStackCaptures();
  _registerFirstFrameCaptures();

  // Every state with motion on, after three seconds, so each fade and each
  // size change has finished. The disc, the dots and the face are wherever
  // their loops are at that second.
  //
  // `rest` is the same screen with reduce motion on: the resting frame.
  for (final scene in _scenes) {
    if (!_parts.contains('screen')) break;
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
