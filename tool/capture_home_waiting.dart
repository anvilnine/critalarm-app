// Captures Home while it waits for the first message, off the device, with a
// made-up setup and no server.
//
//   fvm flutter test tool/capture_home_waiting.dart
//
// It boots the app's own dependencies on the mock server, saves the answer
// from the setup question and the tool of the first topic on the fake phone,
// opens the real Home and writes a PNG named
// <scene>_<frame>_<phone>_<theme>_<scale>x[_reduced].png. The path of every
// file is printed.
//
// Scenes:
//   home_waiting_servers    answer "My servers and apps", no tool saved
//   home_waiting_homelab    answer "My homelab", no tool saved
//   home_waiting_jobs       answer "Builds and scheduled jobs", no tool saved
//   home_waiting_home       answer "My home", no tool saved
//   home_waiting_other      answer "Something else"
//   home_waiting_none       no answer saved: the line Home always had
//   home_waiting_tool_wins  answer "My servers and apps", Uptime Kuma saved
//   home_waiting_unseeded   as a phone that has just finished setup: the
//                           checklist has not looked at it yet
//   home_setup_critical_off the first topic has Critical delivery off, so
//                           the card is the setup card from the first frame
//   home_cold_waiting       a phone opened again after setup, holding no topic
//                           list: the waiting card is a guess, the saved tool
//                           names its line once the list has answered
//   home_cold_critical_off  as above with Critical off: the guess is the
//                           waiting card and the list turns it into the setup
//                           card (the one change the card can still make)
//   home_stored_critical_off  a phone opened again after setup, with the
//                           topic list kept from the last answer read before
//                           the first frame: Critical off, so the card is
//                           the setup card from the first frame and never
//                           changes
//   home_stored_critical_on   as above with Critical on: the waiting card
//                           from the first frame
//   home_walkthrough_sheet  the walkthrough offer over the card
//
// Frames (the "frame" part of a name):
//   first      the first frame in which the card is drawn
//   plus16     16 ms later
//   plus120    120 ms after the first frame
//   (none)     settled
//   mid        the walkthrough sheet part way through its rise
//   plus150    the changes scene only: 150 ms after the first frame
//   plus210    the changes scene only: 210 ms after the first frame
//
// Every scene but the two cold ones and the two stored ones starts as a phone
// does after setup in the same run of the app: the topic list setup loaded is
// held in memory before Home opens. The stored ones start as a phone does at
// launch: the list is read from the local store before the first frame
// (`TopicsCubit.loadHeld`), and the server has not answered yet.
//
// Each scene is drawn at a 390 and a 320 wide phone, light and dark. Settled
// frames come at text scales 1.0, 1.3 and 2.0 and once more under reduced
// motion. The first, plus16 and plus120 frames come at 1.0 and 2.0, and under
// reduced motion for the first one.
//
// The run fails when a frame before the card has its answer shows another
// kind's words ("PHONE CHECKS", "asking the server", the dots), when a
// settled frame lacks the scene's line, when two words of one slot are on
// screen at the same time, and when anything overflows. The walkthrough sheet
// is held to the last one at every size.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
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
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feature_guides/presentation/widgets/feature_guide_offer_sheet.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

/// The line Home showed before there were answers. The words come from
/// `en.json`, written out here so the capture does not use the code it checks.
const _plainLine = 'send the first line';

/// One made-up phone and what the capture looks for on it.
class _Scene {
  const _Scene(
    this.name, {
    required this.topic,
    required this.line,
    this.firstLine,
    this.use,
    this.tool,
    this.opensSheet = false,
    this.isSeeded = true,
    this.isCritical = true,
    this.isListHeld = true,
    this.isListStored = false,
  });

  final String name;

  /// The topic the card watches.
  final String topic;

  /// The saved answer's wire id, or null for none.
  final String? use;

  /// The saved tool's id on [topic], or null for none.
  final String? tool;

  /// The words the settled card has to show under "Not yet".
  final String line;

  /// The words the first frames of a cold scene may show instead of [line].
  /// The saved tool sits on a topic the phone cannot name before the list
  /// loads, so the line may change once the list has. Null means [line] from
  /// the first frame.
  final String? firstLine;

  /// Opens the walkthrough offer over Home.
  final bool opensSheet;

  /// The checklist has already looked at this phone. False is a phone that
  /// has just finished setup.
  final bool isSeeded;

  /// The topic has Critical delivery on. Off, the card is the setup card.
  final bool isCritical;

  /// The app holds the topic list in memory before Home opens, as it does
  /// after setup in the same run. False is a phone opened again after setup.
  final bool isListHeld;

  /// The list comes from the phone's local store, read before the first
  /// frame, and not from the server. [isListHeld] stays true: the app holds
  /// the list when Home opens, only the way it got it differs.
  final bool isListStored;

  /// The card ends on the setup card, not the waiting card.
  bool get endsOnSetup => !isCritical;

  /// The words every frame may show, or null when the first frames are a
  /// guess the list corrects and only the overlap is checked.
  Set<String>? get allowedWords {
    if (endsOnSetup) {
      return isListHeld ? {'SETUP', 'next: turn on Critical'} : null;
    }
    return {'FIRST MESSAGE', line, if (!isListHeld) ?firstLine};
  }
}

const _scenes = <_Scene>[
  _Scene(
    'home_waiting_servers',
    topic: 'prod-db',
    use: 'servers',
    line: 'send the first line from your server',
  ),
  _Scene(
    'home_waiting_homelab',
    topic: 'uptime-kuma',
    use: 'homelab',
    line: 'press Test in Uptime Kuma',
  ),
  _Scene(
    'home_waiting_jobs',
    topic: 'nightly-backup',
    use: 'jobs',
    line: 'run the job once',
  ),
  _Scene(
    'home_waiting_home',
    topic: 'home-assistant',
    use: 'home',
    line: 'run the action in Home Assistant',
  ),
  _Scene(
    'home_waiting_other',
    topic: 'prod-db',
    use: 'other',
    line: _plainLine,
  ),
  _Scene('home_waiting_none', topic: 'prod-db', line: _plainLine),
  _Scene(
    'home_waiting_tool_wins',
    topic: 'prod-db',
    use: 'servers',
    tool: 'uptime_kuma',
    line: 'press Test in Uptime Kuma',
  ),
  _Scene(
    'home_cold_waiting',
    topic: 'prod-db',
    use: 'servers',
    tool: 'uptime_kuma',
    line: 'press Test in Uptime Kuma',
    firstLine: 'send the first line from your server',
    isListHeld: false,
  ),
  _Scene(
    'home_waiting_unseeded',
    topic: 'uptime-kuma',
    use: 'homelab',
    line: 'press Test in Uptime Kuma',
    isSeeded: false,
  ),
  _Scene(
    'home_setup_critical_off',
    topic: 'prod-db',
    use: 'servers',
    line: 'send the first line from your server',
    isCritical: false,
  ),
  _Scene(
    'home_cold_critical_off',
    topic: 'prod-db',
    use: 'servers',
    line: 'send the first line from your server',
    isCritical: false,
    isListHeld: false,
  ),
  _Scene(
    'home_stored_critical_off',
    topic: 'prod-db',
    use: 'servers',
    line: 'send the first line from your server',
    isCritical: false,
    isListStored: true,
  ),
  _Scene(
    'home_stored_critical_on',
    topic: 'prod-db',
    use: 'servers',
    line: 'send the first line from your server',
    isListStored: true,
  ),
  _Scene(
    'home_walkthrough_sheet',
    topic: 'uptime-kuma',
    use: 'homelab',
    tool: 'uptime_kuma',
    line: 'press Test in Uptime Kuma',
    opensSheet: true,
  ),
];

class _Phone {
  const _Phone(this.name, this.size);

  final String name;
  final Size size;
}

const _phones = [
  _Phone('390', Size(390, 844)),
  _Phone('320', Size(320, 640)),
];

const _scales = [1.0, 1.3, 2.0];

/// Answers with fine checks, so the card never has an issue to show.
class _FineSource implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => [
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
}

/// A missed alarm entry that never reaches the phone's record.
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
    // Setup left early: the checklist is on, the first message has not come.
    if (scene.isSeeded) 'setup_checklist_seeded': true,
    'setup_checklist_set_up_here': true,
    'home_widgets_card_seen': true,
    // The answer and the tool, as the setup steps save them.
    if (scene.use != null) 'setup_use': scene.use!,
    if (scene.tool != null) 'topic_tool_template.${scene.topic}': scene.tool!,
    // The guide offer is shown by hand in the sheet scene.
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
  });
  await getIt.reset();
  // A stored scene gives the app a local store holding the last list. The
  // address is the one saved above, and there is no account on the mock.
  LocalStore? store;
  if (scene.isListStored) {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await store.topics.replaceAll(
      heldScopeFor(serverUrl: 'api.critalarm.app', accountId: null)!,
      [Topic(name: scene.topic, critical: scene.isCritical)],
    );
  }
  await configureDependencies(useMockApi: true, openedStore: store);
  getIt<MockServer>()
    ..seedWatching()
    ..createTopic(name: scene.topic, critical: scene.isCritical);
  if (scene.isListStored) {
    // What `main` does before the first frame.
    await getIt<TopicsCubit>().loadHeld();
    expect(getIt<TopicsCubit>().state.isKept, isTrue);
  } else if (scene.isListHeld) {
    // Setup's last steps load the topic list before Home opens.
    await getIt<TopicsCubit>().ensureLoaded();
  }

  await getIt.unregister<ReliabilityCubit>();
  getIt.registerLazySingleton<ReliabilityCubit>(
    () => ReliabilityCubit([_FineSource()]),
  );
  await getIt.unregister<MissedAlarmFeed>();
  getIt.registerLazySingleton<MissedAlarmFeed>(_NoMissedFeed.new);
}

/// Writes what [key] shows to [name].png. [errors] only picks the FIT or BAD
/// label printed with the path.
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

/// The words of the card that are on screen at all, one list per slot (the
/// label and the foot each swap on their own).
///
/// A word that is fading out or in still counts when its opacity is above a
/// hair, so two words in one slot means two texts drawn over each other.
List<List<String>> _visibleWords(WidgetTester tester) {
  final slots = <List<String>>[];
  final switchers = find.descendant(
    of: find.byType(AppStatusCard),
    matching: find.byType(AnimatedSwitcher),
  );
  for (final element in switchers.evaluate()) {
    final words = <String>[];
    final fades = find.descendant(
      of: find.byElementPredicate((e) => e == element),
      matching: find.byType(FadeTransition),
    );
    for (final fade in tester.widgetList<FadeTransition>(fades)) {
      if (fade.opacity.value <= 0.01) continue;
      final text = find.descendant(
        of: find.byWidget(fade),
        matching: find.byType(Text),
      );
      for (final t in tester.widgetList<Text>(text)) {
        words.add(t.data ?? '');
      }
    }
    slots.add(words);
  }
  return slots;
}

/// Checks one frame. Two words in one slot is always a failure. So is a word
/// the scene does not have: another kind's words ("PHONE CHECKS", the dots,
/// "asking the server") before the card has its answer, or the wrong card.
void _checkFrame(WidgetTester tester, _Scene scene, String frame) {
  final slots = _visibleWords(tester);
  for (final words in slots) {
    expect(
      words.length,
      lessThanOrEqualTo(1),
      reason: '$frame of ${scene.name} drew $words over each other',
    );
  }
  final allowed = scene.allowedWords;
  if (allowed == null) return;
  expect(
    [for (final words in slots) ...words],
    everyElement(isIn(allowed)),
    reason: '$frame of ${scene.name} showed words the scene does not have',
  );
}

/// Pumps one 16 ms frame and lets the mock server answer in real time.
Future<void> _step(WidgetTester tester, [int ms = 16]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
}

/// Opens Home and walks it to the settled card, checking every frame on the
/// way.
///
/// The first frame is the first one in which the card is drawn. It, the frame
/// 16 ms after it and the one 120 ms after it are written when [timeline]
/// names them, before the mock server has been given any real time to answer.
/// Then the run steps until the card has its answer and lets the rest of Home
/// settle.
Future<GoRouter> _open(
  WidgetTester tester,
  _Scene scene, {
  required _Phone phone,
  required ThemeMode mode,
  required double scale,
  required bool isReduced,
  required GlobalKey key,
  required List<String> errors,
  required String Function(String frame) nameOf,
  required Set<String> timeline,
}) async {
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone.size * 2;
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
            disableAnimations: isReduced,
          ),
          // The canvas behind every screen, as the app has it.
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
  router.go('/');

  // The first frame with the card in it, no real time given to the server.
  var drawn = false;
  for (var i = 0; i < 20 && !drawn; i++) {
    await tester.pump();
    drawn = find.byType(AppStatusCard).evaluate().isNotEmpty;
  }
  expect(drawn, isTrue, reason: 'no card in ${scene.name}');
  // A cold scene that ends on the setup card changes its words on the way:
  // the frames that cross the change are saved and checked for overlap.
  final crossesChange = scene.endsOnSetup && !scene.isListHeld;
  _checkFrame(tester, scene, 'the first frame');
  if (timeline.contains('first')) {
    await _save(tester, key, nameOf('first'), errors);
  }
  var elapsed = 0;
  for (final (frame, at) in const [
    ('plus16', 16),
    ('plus120', 120),
    ('plus150', 150),
    ('plus210', 210),
  ]) {
    if (at > 120 && !crossesChange) break;
    await tester.pump(Duration(milliseconds: at - elapsed));
    elapsed = at;
    _checkFrame(tester, scene, 'the frame at $at ms');
    if (timeline.contains(frame)) {
      await _save(tester, key, nameOf(frame), errors);
    }
  }

  // Step until the list has answered and the card shows the scene's end.
  bool hasEnded() =>
      find.text(scene.topic).evaluate().isNotEmpty &&
      find.text(scene.endsOnSetup ? 'SETUP' : scene.line).evaluate().isNotEmpty;
  var isEnded = hasEnded();
  for (var i = 0; i < 120 && !isEnded; i++) {
    await _step(tester);
    _checkFrame(tester, scene, 'step $i');
    isEnded = hasEnded();
  }
  expect(isEnded, isTrue, reason: 'no settled card in ${scene.name}');
  if (!scene.endsOnSetup) {
    expect(
      find.text(scene.line),
      findsOneWidget,
      reason: 'the waiting card of ${scene.name} lacks its line',
    );
    expect(find.text('Not yet'), findsOneWidget);
  }

  // Let the rest of Home settle, checking the card stays put.
  for (var i = 0; i < 6; i++) {
    await _step(tester, 100);
    _checkFrame(tester, scene, 'settling $i');
    if (!scene.endsOnSetup) {
      expect(find.text(scene.line), findsOneWidget);
    }
  }
  return router;
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await loadTestTranslations();
    await loadAppFonts();
  });

  /// One run: opens [scene] at [phone] and writes the settled file, and the
  /// frames [timeline] names on the way.
  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    required double scale,
    bool isReduced = false,
    Set<String> timeline = const {},
  }) {
    String nameOf(String frame) {
      final stem = frame.isEmpty ? scene.name : '${scene.name}_$frame';
      return '${stem}_${phone.name}_${mode.name}_${scale}x'
          '${isReduced ? '_reduced' : ''}';
    }

    final frames = {'', ...timeline}.where((f) => _wanted(nameOf(f)));
    if (frames.isEmpty) return;
    testWidgets('capture ${nameOf('')}', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      addTearDown(() => FlutterError.onError = oldHandler);
      try {
        final key = GlobalKey();
        final router = await _open(
          tester,
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
          isReduced: isReduced,
          key: key,
          errors: errors,
          nameOf: nameOf,
          timeline: {for (final f in frames) f},
        );
        if (scene.opensSheet) {
          final context =
              router.routerDelegate.navigatorKey.currentState!.overlay!.context;
          // The router's own context, read the line before: it is still
          // mounted.
          // ignore: use_build_context_synchronously
          unawaited(showFeatureGuideOfferSheet(context));
          await tester.pump();
          // The sheet rises on the app's own clock. A frame in the middle of
          // it, then the end.
          await tester.pump(const Duration(milliseconds: 120));
          if (frames.contains('mid')) {
            await _save(tester, key, nameOf('mid'), errors);
          }
          await tester.pump(const Duration(milliseconds: 800));
          // Both buttons are on screen, however tall the words are.
          for (final label in ['Show me around', 'Not now']) {
            final box = tester.getRect(find.text(label));
            expect(
              box.bottom,
              lessThanOrEqualTo(phone.size.height),
              reason: '"$label" is off the bottom of ${nameOf('')}',
            );
            expect(box.top, greaterThanOrEqualTo(0));
          }
        }
        if (frames.contains('')) await _save(tester, key, nameOf(''), errors);
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').first}');
        }
        // Take Home down so the watch on the first message stops its timer.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          errors,
          isEmpty,
          reason: 'overflow or build error in ${nameOf('')}',
        );
      } finally {
        // A failed check must hand the handler back, or the run hangs.
        FlutterError.onError = oldHandler;
      }
    });
  }

  for (final scene in _scenes) {
    for (final phone in _phones) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in _scales) {
          final isBig = scale == 1.0 || scale == 2.0;
          capture(
            scene,
            phone: phone,
            mode: mode,
            scale: scale,
            timeline: {
              if (scene.opensSheet) 'mid',
              if (!scene.opensSheet && isBig) ...['first', 'plus16', 'plus120'],
              if (scene.endsOnSetup && !scene.isListHeld && isBig) ...[
                'plus150',
                'plus210',
              ],
            },
          );
        }
        capture(
          scene,
          phone: phone,
          mode: mode,
          scale: 1,
          isReduced: true,
          timeline: {if (!scene.opensSheet) 'first'},
        );
        capture(
          scene,
          phone: phone,
          mode: mode,
          scale: 2,
          isReduced: true,
          timeline: {if (!scene.opensSheet) 'first'},
        );
      }
    }
  }
}
