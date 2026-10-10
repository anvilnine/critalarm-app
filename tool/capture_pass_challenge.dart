// Captures the Wake-up challenge page, the shelf of tiles, off the device, on
// the mock server and the developer plan switches, through the real router and
// the real ambient shell.
//
//   fvm flutter test tool/capture_pass_challenge.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=plans,sizes (default: all):
//   plans    the page in every plan state: free (locked, with the wide
//            button), pro (held, the button gone), hosted (holds nothing for
//            challenges, so it looks like free), notread (the plan still
//            being read: no tag, no lock, no button), own (a server of the
//            user's own with nothing held), ownpro, confirming, unreadable.
//            390 by 844, light and dark; confirming and unreadable light only
//   chosen   Off and each of the five challenges chosen (Pro held), and a
//            kind saved before a lapse (the page says Off while locked)
//   sizes    free at 375 by 667, 320 by 640, 600 by 844, 1024 by 768 and
//            844 by 390, and at text scale 1.3 and 2.0 (the one-column
//            shelf) where the matrix has them
//   reduce   the resting frame under reduce motion
//   taps     the taps on a locked option: the tile (the try page, nothing
//            saved), the pick control (the paywall, nothing saved), the wide
//            button (the paywall), the tag (nothing); and on an open one:
//            the pick control saves, No challenge saves null, a tile opens
//            the try. It prints one `FLOW` line for each and fails when the
//            outcome is not the one the rule gives
//   topic    the page opened for one topic (`/challenge?topic=<name>`): no
//            challenge, one chosen (while the phone's default is another),
//            a kind saved before a lapse, locked, plan not read, a server of
//            the user's own, a long name, the sizes and text scales, reduce
//            motion, the grow from a card (the tool gives the route a
//            `PassOrigin`) and the taps, which must write only that topic
//            (they print a FLOW line and fail on a wrong write)
//   grow     the page reached from the root: the card grows into the page,
//            at progress 0, 0.25, 0.5, 0.75 and 1, open and back, light and
//            dark; a page opened with no card (a deep link); the reduce
//            motion fade
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a206)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the grow playing.
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
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/presentation/challenge_try.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_scope.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge/challenge_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';
import 'capture_pass_kit.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a206');
const _partsArg = String.fromEnvironment('PARTS');

/// The page name in every file.
const _page = 'challenge';

const _pagePath = '/settings/personalize/challenge';

/// A server of the user's own with nothing held. The kit's own-server state
/// holds Pro; the spec's state is the plain one, where challenges still need
/// Pro.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// A server of the user's own with Pro held.
const _ownServerPro = PassPlanState(
  'ownpro',
  preset: AccessPreset.pro,
  isOwnServer: true,
);

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.saved,
    this.topic,
    this.topicChoice,
  });

  final PassPlanState plan;

  /// The challenge saved for new topics, or null for none.
  final ChallengeKind? saved;

  /// The topic the page is opened for, or null for the whole phone.
  final String? topic;

  /// The challenge saved for [topic], or null for none.
  final ChallengeKind? topicChoice;
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

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _boot(WidgetTester tester, _Setup setup) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
    ..._planPrefs(setup.plan),
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  getIt<MockServer>().seedCalm();
  final saved = setup.saved;
  if (saved != null) {
    await getIt<ChallengeChoices>().setDefaultForNewTopics(saved);
  }
  final topic = setup.topic;
  final topicChoice = setup.topicChoice;
  if (topic != null && topicChoice != null) {
    await getIt<ChallengeChoices>().setChoice(topic, topicChoice);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 400);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 200);
  await tester.pump(const Duration(milliseconds: 600));
}

/// A running shot: the key of what is saved and the router that moves it.
class _Run {
  _Run(this.key, this.router);

  final GlobalKey key;
  final GoRouter router;
}

/// Opens the app on the root and pushes [location] on top of it, or opens
/// the root itself when [location] is the root.
Future<_Run> _open(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
  String? location,
  bool push = true,
  Object? extra,
}) async {
  await tester.runAsync(() => _boot(tester, setup));
  const dpr = 2.0;
  tester.view.physicalSize = device.size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: device.safeTop * dpr,
    bottom: device.safeBottom * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
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
            disableAnimations: reduceMotion,
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
  router.go('/');
  await _settle(tester);
  if (push) {
    final topic = setup.topic;
    unawaited(
      router.push(
        location ??
            (topic == null
                ? _pagePath
                : passLocationFor('/challenge', TopicScope(topic))),
        extra: extra,
      ),
    );
    await _settle(tester);
  }
  await tester.pump(const Duration(seconds: 1));
  return _Run(key, router);
}

Future<void> _save(
  WidgetTester tester,
  _Run run,
  String name,
  List<String> errors,
) => tester.runAsync(() async {
  final boundary =
      run.key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
});

/// Runs [body] with every framework error collected, and fails the capture
/// when there is one.
Future<void> _guarded(
  String name,
  Future<void> Function(List<String> errors) body,
) async {
  final errors = <String>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    // Reduce motion gives an AnimatedSize a zero duration, which marks
    // itself dirty while it lays out when its child changes size. A debug
    // build only.
    if (text.contains('RenderAnimatedSize was mutated in its own')) {
      print('  NOTE: $text');
      return;
    }
    errors.add(details.toString());
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

Set<String> get _parts => _partsArg.isEmpty
    ? {'plans', 'chosen', 'sizes', 'reduce', 'taps', 'topic', 'grow'}
    : _partsArg.split(',').toSet();

/// Registers one capture of the page as it opens.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  String frame = 'rest',
  bool reduceMotion = false,
  String? location,
  Future<void> Function(WidgetTester tester, _Run run)? act,
}) {
  if (!_parts.contains(part)) return;
  final name = passFileName(
    page: _page,
    device: device,
    mode: mode,
    scale: scale,
    frame: frame,
    state: state,
  );
  if (!passWanted(name)) return;
  testWidgets('capture $name', (tester) async {
    await _guarded(name, (errors) async {
      final run = await _open(
        tester,
        setup: setup,
        device: device,
        mode: mode,
        scale: scale,
        reduceMotion: reduceMotion,
        location: location,
      );
      if (act != null) await act(tester, run);
      await _save(tester, run, name, errors);
    });
  });
}

Finder _tile(ChallengeKind? kind) =>
    find.byKey(ValueKey('challenge-tile-${kind?.id ?? 'off'}'));

Finder _pick(ChallengeKind? kind) => find.descendant(
  of: _tile(kind),
  matching: find.byType(ChallengePickControl),
);

/// Scrolls the page to its end.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -900));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Where the front-most route is. A pushed page is the last match of the
/// configuration, and the configuration's own `uri` is the one under it.
String _locationOf(_Run run) {
  final matches = run.router.routerDelegate.currentConfiguration.matches;
  return matches.last.matchedLocation;
}

/// Taps the card of the challenge pass on the root.
Future<void> _tapChallengeCard(WidgetTester tester) async {
  final card = find.byKey(ValueKey('pass-${PassId.challenge.name}'));
  expect(card, findsOneWidget, reason: 'no card for the challenge pass');
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

/// Opens the page from its card on the root and calls [onFrame] with the
/// share of the way through the transition: 0, 0.25, 0.5, 0.75 and 1.
Future<void> _grow(
  WidgetTester tester,
  _Run run,
  Future<void> Function(String frame) onFrame, {
  bool back = false,
  bool reduceMotion = false,
}) async {
  const fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
  await _tapChallengeCard(tester);
  await tester.pump();
  await tester.pump();
  final openMs = reduceMotion ? 150 : 600;
  var elapsed = 0;
  for (final fraction in fractions) {
    final target = (openMs * fraction).round();
    if (target > elapsed) {
      await tester.pump(Duration(milliseconds: target - elapsed));
      elapsed = target;
    }
    await onFrame(
      'open-t${(fraction * 100).round().toString().padLeft(3, '0')}',
    );
  }
  if (!back) return;
  await tester.pump(const Duration(seconds: 1));
  run.router.pop();
  await tester.pump();
  await tester.pump();
  final backMs = reduceMotion ? 150 : 520;
  elapsed = 0;
  for (final fraction in fractions) {
    final target = (backMs * fraction).round();
    if (target > elapsed) {
      await tester.pump(Duration(milliseconds: target - elapsed));
      elapsed = target;
    }
    await onFrame(
      'back-t${(fraction * 100).round().toString().padLeft(3, '0')}',
    );
  }
}

/// A tap flow: opens the page and runs [body], which saves a picture with
/// the `shot` it is given.
void _flow(
  String name,
  _Setup setup,
  Future<void> Function(
    WidgetTester tester,
    _Run run,
    Future<void> Function(String frame) shot,
  )
  body, {
  ThemeMode mode = ThemeMode.light,
  String part = 'taps',
}) {
  if (!_parts.contains(part)) return;
  if (!passWanted('${_page}_flow-$name')) return;
  testWidgets('flow $name', (tester) async {
    await _guarded('flow-$name', (errors) async {
      final run = await _open(
        tester,
        setup: setup,
        device: passPhone,
        mode: mode,
        scale: 1,
      );
      Future<void> shot(String frame) => _save(
        tester,
        run,
        passFileName(
          page: _page,
          device: passPhone,
          mode: mode,
          scale: 1,
          frame: frame,
          state: setup.topic == null
              ? setup.plan.name
              : 'topic-${setup.plan.name}',
        ),
        errors,
      );
      await body(tester, run, shot);
    });
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  // The plan states.
  for (final plan in PassPlanState.all) {
    final p = plan.name == 'own' ? _ownServer : plan;
    final isMain = const {'free', 'pro', 'hosted', 'notread', 'own'}.contains(
      p.name,
    );
    for (final mode in isMain ? passThemes : [ThemeMode.light]) {
      _shot(
        part: 'plans',
        state: p.name,
        setup: _Setup(plan: p),
        device: passPhone,
        mode: mode,
      );
    }
  }
  for (final mode in passThemes) {
    _shot(
      part: 'plans',
      state: 'ownpro',
      setup: const _Setup(plan: _ownServerPro),
      device: passPhone,
      mode: mode,
    );
  }
  // Free, scrolled to the end: the wide button under the last row.
  for (final mode in passThemes) {
    _shot(
      part: 'plans',
      state: 'free',
      setup: const _Setup(),
      device: passPhone,
      mode: mode,
      frame: 'end',
      act: (tester, run) => _scrollToEnd(tester),
    );
  }

  // What the page can say: Off and each challenge chosen, with Pro held, and
  // a kind saved before a lapse.
  final chosenSetups = <String, _Setup>{
    'off': const _Setup(plan: PassPlanState.pro),
    for (final kind in ChallengeKind.values)
      'chosen-${kind.id}': _Setup(plan: PassPlanState.pro, saved: kind),
    'lapsed': const _Setup(saved: ChallengeKind.shake),
  };
  for (final MapEntry(key: state, value: setup) in chosenSetups.entries) {
    _shot(
      part: 'chosen',
      state: state,
      setup: setup,
      device: passPhone,
      mode: ThemeMode.light,
    );
  }
  for (final kind in const [
    ChallengeKind.typeAlertTitle,
    ChallengeKind.shake,
  ]) {
    _shot(
      part: 'chosen',
      state: 'chosen-${kind.id}',
      setup: _Setup(plan: PassPlanState.pro, saved: kind),
      device: passPhone,
      mode: ThemeMode.dark,
    );
  }

  // The sizes and text scales, on the free phone.
  for (final device in [...passDevices, passMedium]) {
    for (final scale in passScalesFor(device)) {
      for (final mode in passThemes) {
        if (device == passPhone && scale == 1) continue;
        _shot(
          part: 'sizes',
          state: 'free',
          setup: const _Setup(),
          device: device,
          mode: mode,
          scale: scale,
        );
      }
    }
  }
  // Pro held with a long name chosen, at the largest text size.
  _shot(
    part: 'sizes',
    state: 'chosen-type_alert_title',
    setup: const _Setup(
      plan: PassPlanState.pro,
      saved: ChallengeKind.typeAlertTitle,
    ),
    device: passPhone,
    mode: ThemeMode.light,
    scale: 2,
  );
  _shot(
    part: 'sizes',
    state: 'chosen-type_alert_title',
    setup: const _Setup(
      plan: PassPlanState.pro,
      saved: ChallengeKind.typeAlertTitle,
    ),
    device: passNarrowPhone,
    mode: ThemeMode.dark,
    scale: 2,
  );
  // The end of the one-column shelf at 2.0.
  _shot(
    part: 'sizes',
    state: 'free',
    setup: const _Setup(),
    device: passPhone,
    mode: ThemeMode.light,
    scale: 2,
    frame: 'end',
    act: (tester, run) => _scrollToEnd(tester),
  );

  // Reduce motion: the resting frame.
  for (final mode in passThemes) {
    _shot(
      part: 'reduce',
      state: 'free',
      setup: const _Setup(),
      device: passPhone,
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
  }

  // The taps on a locked option, and on an open one.
  _flow('locked-tile', const _Setup(), (tester, run, shot) async {
    await tester.tap(_tile(ChallengeKind.opsMath));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChallengeTryPage), findsOneWidget);
    expect(_locationOf(run), _pagePath, reason: 'a tile sold something');
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await shot('tap-tile-try');
    print('FLOW locked: the tile opened the try page, no paywall, no save');
  });
  _flow('locked-tile-scratch', const _Setup(), (tester, run, shot) async {
    await tester.tap(_tile(ChallengeKind.scratchCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChallengeTryPage), findsOneWidget);
    await shot('tap-tile-try-scratch');
  });
  _flow(
    'locked-tile-dark',
    const _Setup(),
    (tester, run, shot) async {
      await tester.tap(_tile(ChallengeKind.shake));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChallengeTryPage), findsOneWidget);
      await shot('tap-tile-try-shake');
    },
    mode: ThemeMode.dark,
  );
  _flow('locked-pick', const _Setup(), (tester, run, shot) async {
    await tester.tap(_pick(ChallengeKind.opsMath));
    await tester.pump();
    await _real(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      _locationOf(run),
      isNot(_pagePath),
      reason: 'the pick control on a locked option opens no paywall',
    );
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await shot('tap-pick-paywall');
    print(
      'FLOW locked: the pick control opened the paywall, ${_locationOf(run)}',
    );
  });
  _flow('locked-wide', const _Setup(), (tester, run, shot) async {
    await _scrollToEnd(tester);
    await tester.tap(find.text('See Pro'));
    await tester.pump();
    await _real(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(_locationOf(run), isNot(_pagePath));
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await shot('tap-wide-paywall');
    print(
      'FLOW locked: the wide button opened the paywall, ${_locationOf(run)}',
    );
  });
  _flow('locked-tag', const _Setup(), (tester, run, shot) async {
    // The tag sits after the label in the header. A tap there, and on the
    // header and the foot lines, sells nothing.
    final label = find.textContaining('WAKE-UP CHALLENGE');
    expect(label, findsWidgets);
    await tester.tapAt(tester.getCenter(label.first));
    await tester.tapAt(tester.getTopRight(label.first) + const Offset(24, 8));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_locationOf(run), _pagePath, reason: 'the tag sold something');
    expect(find.byType(ChallengeTryPage), findsNothing);
    print('FLOW locked: a tap on the tag and the header opened nothing');
  });
  _flow('locked-off', const _Setup(saved: ChallengeKind.shake), (
    tester,
    run,
    shot,
  ) async {
    // No challenge needs no plan: it saves null and sells nothing.
    await tester.tap(_pick(null));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_locationOf(run), _pagePath);
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    print('FLOW locked: No challenge saved null with no plan');
  });
  _flow('notread-pick', const _Setup(plan: PassPlanState.notRead), (
    tester,
    run,
    shot,
  ) async {
    // The plan is never read in this state: the tap waits and does nothing.
    await tester.tap(_pick(ChallengeKind.opsMath));
    await tester.pump(const Duration(seconds: 2));
    expect(_locationOf(run), _pagePath);
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await tester.tap(_tile(ChallengeKind.opsMath));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(ChallengeTryPage),
      findsOneWidget,
      reason: 'the tile opens the try before the plan is read',
    );
    await shot('tap-tile-try');
    print('FLOW plan not read: the pick control waited, the tile still tried');
  });
  _flow('open-pick', const _Setup(plan: PassPlanState.pro), (
    tester,
    run,
    shot,
  ) async {
    await tester.tap(_pick(ChallengeKind.shake));
    await tester.pump(const Duration(milliseconds: 500));
    expect(getIt<ChallengeChoices>().defaultForNewTopics, ChallengeKind.shake);
    expect(_locationOf(run), _pagePath);
    await shot('tap-pick-saved');
    print('FLOW Pro held: the pick control saved the default for new topics');
  });
  _flow(
    'open-off',
    const _Setup(plan: PassPlanState.pro, saved: ChallengeKind.shake),
    (
      tester,
      run,
      shot,
    ) async {
      await tester.tap(_tile(null));
      await tester.pump(const Duration(milliseconds: 500));
      expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
      await shot('tap-off-saved');
      print('FLOW Pro held: No challenge saved null');
    },
  );
  _flow('open-tile', const _Setup(plan: PassPlanState.pro), (
    tester,
    run,
    shot,
  ) async {
    await tester.tap(_tile(ChallengeKind.typeTopicName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChallengeTryPage), findsOneWidget);
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await shot('tap-tile-try');
    print('FLOW Pro held: the tile opened the try and saved nothing');
  });

  // The page opened for one topic.
  const topic = 'Uptime Kuma';
  const longTopic =
      'Production database nightly backup verification and restore drill';
  const topicPath = '/challenge';
  const topicNone = _Setup(plan: PassPlanState.pro, topic: topic);
  const topicChosen = _Setup(
    plan: PassPlanState.pro,
    // The phone's default is another kind: the page shows the topic's own.
    saved: ChallengeKind.opsMath,
    topic: topic,
    topicChoice: ChallengeKind.shake,
  );
  const topicLapsed = _Setup(
    topic: topic,
    topicChoice: ChallengeKind.shake,
  );
  const topicFree = _Setup(topic: topic);
  const topicStates = <String, _Setup>{
    'none': topicNone,
    'chosen': topicChosen,
    'lapsed': topicLapsed,
    'free': topicFree,
    'longname': _Setup(
      plan: PassPlanState.pro,
      topic: longTopic,
      topicChoice: ChallengeKind.typeAlertTitle,
    ),
  };
  for (final MapEntry(key: state, value: setup) in topicStates.entries) {
    for (final mode in passThemes) {
      _shot(
        part: 'topic',
        state: 'topic-$state',
        setup: setup,
        device: passPhone,
        mode: mode,
      );
    }
  }
  _shot(
    part: 'topic',
    state: 'topic-notread',
    setup: const _Setup(plan: PassPlanState.notRead, topic: topic),
    device: passPhone,
    mode: ThemeMode.light,
  );
  _shot(
    part: 'topic',
    state: 'topic-ownserver',
    setup: const _Setup(plan: _ownServer, topic: topic),
    device: passPhone,
    mode: ThemeMode.light,
  );
  // The sizes and text scales.
  for (final device in [passPhone, passNarrowPhone]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final mode in passThemes) {
        if (device == passPhone && scale == 1) continue;
        _shot(
          part: 'topic',
          state: 'topic-chosen',
          setup: topicChosen,
          device: device,
          mode: mode,
          scale: scale,
        );
      }
    }
  }
  for (final (device, scale) in [(passNarrowPhone, 1.0), (passPhone, 2.0)]) {
    _shot(
      part: 'topic',
      state: 'topic-longname',
      setup: topicStates['longname']!,
      device: device,
      mode: ThemeMode.light,
      scale: scale,
    );
  }
  _shot(
    part: 'topic',
    state: 'topic-free',
    setup: topicFree,
    device: passPhone,
    mode: ThemeMode.light,
    scale: 2,
    frame: 'end',
    act: (tester, run) => _scrollToEnd(tester),
  );
  for (final mode in passThemes) {
    _shot(
      part: 'topic',
      state: 'topic-chosen',
      setup: topicChosen,
      device: passPhone,
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
  }
  // The taps: each writes the topic and nothing else.
  _flow('topic-pick', topicNone, (tester, run, shot) async {
    await tester.tap(_pick(ChallengeKind.opsMath));
    await tester.pump(const Duration(milliseconds: 500));
    final choices = getIt<ChallengeChoices>();
    expect(choices.choiceFor(topic), ChallengeKind.opsMath);
    expect(choices.defaultForNewTopics, isNull, reason: 'the default moved');
    expect(_locationOf(run), topicPath);
    await shot('topic-tap-pick-saved');
    print('FLOW topic, Pro held: the pick control saved only the topic');
  }, part: 'topic');
  _flow('topic-off', topicChosen, (tester, run, shot) async {
    await tester.tap(_pick(null));
    await tester.pump(const Duration(milliseconds: 500));
    final choices = getIt<ChallengeChoices>();
    expect(choices.choiceFor(topic), isNull);
    expect(
      choices.defaultForNewTopics,
      ChallengeKind.opsMath,
      reason: 'No challenge for a topic changed the default',
    );
    await shot('topic-tap-off-saved');
    print('FLOW topic: No challenge saved null for the topic only');
  }, part: 'topic');
  _flow('topic-locked-off', topicLapsed, (tester, run, shot) async {
    // No challenge needs no plan, and sells nothing.
    await tester.tap(_pick(null));
    await tester.pump(const Duration(milliseconds: 500));
    expect(getIt<ChallengeChoices>().choiceFor(topic), isNull);
    expect(_locationOf(run), topicPath);
    print('FLOW topic, locked: No challenge saved null with no plan');
  }, part: 'topic');
  _flow('topic-locked-pick', topicFree, (tester, run, shot) async {
    await tester.tap(_pick(ChallengeKind.opsMath));
    await tester.pump();
    await _real(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(_locationOf(run), isNot(topicPath));
    expect(getIt<ChallengeChoices>().choiceFor(topic), isNull);
    expect(getIt<ChallengeChoices>().defaultForNewTopics, isNull);
    await shot('topic-tap-pick-paywall');
    print(
      'FLOW topic, locked: the pick control opened the paywall, nothing saved',
    );
  }, part: 'topic');
  _flow('topic-locked-tile', topicFree, (tester, run, shot) async {
    await tester.tap(_tile(ChallengeKind.opsMath));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChallengeTryPage), findsOneWidget);
    expect(getIt<ChallengeChoices>().choiceFor(topic), isNull);
    await shot('topic-tap-tile-try');
    print('FLOW topic, locked: the tile opened the try page, nothing saved');
  }, part: 'topic');
  // The grow from a card: the route is given a `PassOrigin`, as the card of
  // the Wake-up challenge pass on the topic page will give it.
  for (final mode in passThemes) {
    final base = passFileName(
      page: 'grow-challenge',
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'x',
      state: 'topic',
    );
    if (!_parts.contains('topic') || !passWanted(base)) continue;
    testWidgets('capture grow topic ${mode.name}', (tester) async {
      await _guarded(base, (errors) async {
        final run = await _open(
          tester,
          setup: topicChosen,
          device: passPhone,
          mode: mode,
          scale: 1,
          push: false,
        );
        final colors = mode == ThemeMode.dark
            ? AppColors.dark
            : AppColors.light;
        final origin = PassOrigin(
          pass: PassId.challenge,
          rect: const Rect.fromLTWH(12, 330, 366, 190),
          tone: passToneFor(PassId.challenge, colors),
          label: 'Wake-up challenge',
          value: 'Shake',
          display: PassDisplay(passPhone.size, safeTop: passPhone.safeTop),
        );
        const fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
        Future<void> frames(String way, int ms) async {
          var elapsed = 0;
          for (final fraction in fractions) {
            final target = (ms * fraction).round();
            if (target > elapsed) {
              await tester.pump(Duration(milliseconds: target - elapsed));
              elapsed = target;
            }
            final percent = (fraction * 100).round().toString().padLeft(3, '0');
            await _save(
              tester,
              run,
              passFileName(
                page: 'grow-challenge',
                device: passPhone,
                mode: mode,
                scale: 1,
                frame: '$way-t$percent',
                state: 'topic',
              ),
              errors,
            );
          }
        }

        unawaited(
          run.router.push(
            passLocationFor(topicPath, const TopicScope(topic)),
            extra: origin,
          ),
        );
        await tester.pump();
        await tester.pump();
        await frames('open', 600);
        if (mode == ThemeMode.light) {
          await tester.pump(const Duration(seconds: 1));
          run.router.pop();
          await tester.pump();
          await tester.pump();
          await frames('back', 520);
        }
      });
    });
  }
  // The route with no topic is the page Personalize opens.
  _shot(
    part: 'topic',
    state: 'phone',
    setup: const _Setup(plan: PassPlanState.pro, saved: ChallengeKind.opsMath),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'no-topic-query',
    location: topicPath,
  );

  // The page reached from the root: the grow, open and back.
  for (final mode in passThemes) {
    final base = passFileName(
      page: _page,
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'x',
      state: 'grow',
    );
    if (!_parts.contains('grow') || !passWanted(base)) continue;
    testWidgets('capture grow ${mode.name}', (tester) async {
      await _guarded(base, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: mode,
          scale: 1,
          location: '/settings/personalize',
        );
        await _grow(tester, run, back: true, (frame) async {
          await _save(
            tester,
            run,
            passFileName(
              page: _page,
              device: passPhone,
              mode: mode,
              scale: 1,
              frame: frame,
              state: 'grow',
            ),
            errors,
          );
        });
      });
    });
  }
  // A page with no card (a deep link).
  for (final mode in passThemes) {
    final name = passFileName(
      page: _page,
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'deeplink',
      state: 'free',
    );
    if (!_parts.contains('grow') || !passWanted(name)) continue;
    testWidgets('capture $name', (tester) async {
      await _guarded(name, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: mode,
          scale: 1,
          location: '/',
        );
        run.router.go(_pagePath);
        await _settle(tester);
        await _save(tester, run, name, errors);
      });
    });
  }
  // Reduce motion: the finished page fades over the root.
  final reduceBase = passFileName(
    page: _page,
    device: passPhone,
    mode: ThemeMode.light,
    scale: 1,
    frame: 'x',
    state: 'growreduce',
  );
  if (_parts.contains('grow') && passWanted(reduceBase)) {
    testWidgets('capture grow reduce', (tester) async {
      await _guarded(reduceBase, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(),
          device: passPhone,
          mode: ThemeMode.light,
          scale: 1,
          reduceMotion: true,
          location: '/settings/personalize',
        );
        await _grow(tester, run, reduceMotion: true, (frame) async {
          if (!const ['open-t000', 'open-t050', 'open-t100'].contains(frame)) {
            return;
          }
          await _save(
            tester,
            run,
            passFileName(
              page: _page,
              device: passPhone,
              mode: ThemeMode.light,
              scale: 1,
              frame: frame,
              state: 'growreduce',
            ),
            errors,
          );
        });
      });
    });
  }

  // Scroll: the header at rest, half way through its collapse and collapsed,
  // on both phones and both text scales.
  forEachPassScroll((device, mode, scale, at) {
    _shot(
      part: 'scroll',
      state: 'free',
      setup: const _Setup(),
      device: device,
      mode: mode,
      scale: scale,
      frame: at.frame,
      act: (tester, run) =>
          scrollPassPage(tester, at, device: device, scale: scale),
    );
  });
}
