// Captures the Personalize root, the stack of passes, off the device, on the
// mock server and the developer plan switches, through the real router and
// the real ambient shell.
//
//   fvm flutter test tool/capture_pass_root.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
//
// Parts, picked with --dart-define=PARTS=plans,sizes (default: all):
//   plans    the root in every plan state: free, pro, hosted, notread (the
//            plan still being read), own (a server of the user's own, nothing
//            held), confirming, unreadable. 390 by 844, light and dark; the
//            last two light only.
//   sizes    free at 375 by 667, 320 by 640, 600 by 844, 1024 by 768 and
//            844 by 390, and at text scale 1.3 and 2.0 (flat mode) where the
//            matrix has them
//   values   what a card can say: a saved challenge (pro), the same saved
//            challenge while locked (Off), the longest challenge name, a long
//            own-sound name, the stand-in for an own sound after a lapse, a
//            sound with no peaks, the crowned icon
//   challenge  the Wake-up challenge card with no challenge, locked, and each
//            of the five kinds chosen, light and dark, at text scale 1.0
//            and 2.0
//   web      three passes, for a platform with no widgets and no icon change
//   looks    the Look pass in each of the six looks, light and dark
//   reduce   the resting frame under reduce motion
//   motion   the two moving thumbnails at a chosen second of their clock
//   grow     the transition from the card to the page and back, at progress
//            0, 0.25, 0.5, 0.75 and 1, for each of the five pages, light and
//            dark, each page once open, a page opened with no card (a deep
//            link), and the reduce motion fade at the same steps
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a203)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the grow or the thumbnails playing.
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
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumb_motion.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumbs.dart';
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
import 'own_look_photos.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a203');
const _partsArg = String.fromEnvironment('PARTS');

/// The page name in every file.
const _page = 'root';

/// A server of the user's own with nothing held. The kit's own-server state
/// holds Pro; the spec's state is the plain one: App icon is open, and Look,
/// Sound, Challenge and Widgets still need Pro.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.isWeb = false,
    this.look,
    this.hasOwnPhoto = false,
    this.challenge,
    this.ownSound,
    this.hasPeaks = true,
    this.icon = AppIcon.standard,
  });

  final PassPlanState plan;

  /// A platform with no home screen widgets and no icon change.
  final bool isWeb;

  /// The saved look id, or null for the standard one.
  final String? look;
  final bool hasOwnPhoto;
  final ChallengeKind? challenge;

  /// An own sound saved as the default.
  final AlarmSound? ownSound;

  /// Whether the sound host answers a read of peaks.
  final bool hasPeaks;

  final AppIcon icon;
}

AlarmSound _ownSoundNamed(String name) => AlarmSound(
  id: 'user_capture',
  name: name,
  source: AlarmSoundSource.user,
  path: '/sounds/user_capture.caf',
  duration: const Duration(seconds: 4),
  peaks: [
    for (var i = 0; i < 48; i++) 0.25 + 0.7 * ((i * 7) % 11) / 10,
  ],
);

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

Future<void> _boot(WidgetTester tester, _Setup setup, Size phone) async {
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
  await useCaptureOwnLookStore();
  if (setup.isWeb) {
    getIt
      ..unregister<PlatformCapabilities>()
      ..registerSingleton<PlatformCapabilities>(
        const PlatformCapabilities(isWeb: true, platform: TargetPlatform.macOS),
      );
  }
  if (setup.hasOwnPhoto) {
    await importCaptureOwnLook(CapturePhoto.bright, screen: phone * 2);
  }
  final look = setup.look;
  if (look != null) await getIt<AlarmStyleChoices>().setDefault(look);
  final challenge = setup.challenge;
  if (challenge != null) {
    await getIt<ChallengeChoices>().setDefaultForNewTopics(challenge);
  }
  final sound = setup.ownSound;
  if (sound != null) {
    final sounds = getIt<AlarmSoundRepository>();
    await sounds.addUserSound(sound);
    await sounds.setDefaultSoundId(sound.id);
  }
}

/// Lets the phone ask the app icon and the sound host what they would.
void _mockChannels(_Setup setup) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async {
            if (setup.isWeb) throw MissingPluginException();
            return call.method == 'current' ? setup.icon.platformName : true;
          },
        )
        ..setMockMethodCallHandler(
          const MethodChannel(SoundHost.channelName),
          (call) async => switch (call.method) {
            'readPeaks' =>
              setup.hasPeaks
                  ? <double>[
                      for (var i = 0; i < 48; i++)
                        0.2 + 0.75 * ((i * 5) % 9) / 8,
                    ]
                  : <double>[],
            'capabilities' => <String, Object?>{'can_import_sounds': false},
            _ => null,
          },
        );
  addTearDown(() {
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel(AppIconHost.channelName),
        null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel(SoundHost.channelName),
        null,
      );
  });
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

Future<_Run> _open(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
  bool holdThumbs = true,
  String location = '/settings/personalize',
}) async {
  _mockChannels(setup);
  await tester.runAsync(() => _boot(tester, setup, device.size));
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
            // A held clock draws the resting frame of the two moving
            // thumbnails, so two shots of one state are the same picture.
            child: PaywallStill(
              isStill: holdThumbs,
              child: AppAmbientShell(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  router.go('/');
  await _settle(tester);
  unawaited(router.push(location));
  await _settle(tester);
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
/// when there is one. The handler is put back before the test body ends, as
/// the test binding asks.
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
    ? {
        'plans',
        'sizes',
        'values',
        'challenge',
        'web',
        'looks',
        'reduce',
        'motion',
        'grow',
      }
    : _partsArg.split(',').toSet();

/// Registers one capture of the root as it opens.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  String frame = 'rest',
  bool reduceMotion = false,
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
      );
      if (act != null) await act(tester, run);
      await _save(tester, run, name, errors);
    });
  });
}

/// Scrolls the flat list of cards, at large text, until the Wake-up challenge
/// card is whole on the screen.
Future<void> _scrollToChallenge(WidgetTester tester, _Run run) async {
  final card = find.byKey(const ValueKey('pass-challenge'));
  await tester.ensureVisible(card);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Taps the card of [pass] on the band that shows.
Future<void> _tapCard(WidgetTester tester, PassId pass) async {
  final card = find.byKey(ValueKey('pass-${pass.name}'));
  expect(card, findsOneWidget, reason: 'no card for ${pass.name}');
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

/// Opens [pass], and calls [onFrame] with the share of the way through the
/// transition: 0, 0.25, 0.5, 0.75 and 1. The clock steps in exact fractions
/// of the route's 600 ms.
Future<void> _grow(
  WidgetTester tester,
  _Run run,
  PassId pass,
  Future<void> Function(String frame) onFrame, {
  bool back = false,
  bool reduceMotion = false,
}) async {
  const fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
  await _tapCard(tester, pass);
  // The route is built and its clock is at zero.
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
  // Let the page settle, then take it back.
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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  tearDownAll(dropCaptureOwnLookStore);

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

  // What a card can say.
  final longName = _ownSoundNamed(
    'Server room fire alarm, recorded at the data centre',
  );
  final values = <String, _Setup>{
    'challenge-ops': const _Setup(
      plan: PassPlanState.pro,
      challenge: ChallengeKind.opsMath,
    ),
    // A kind saved before a lapse: the card says Off while it is locked.
    'challenge-locked': const _Setup(challenge: ChallengeKind.shake),
    'challenge-long': const _Setup(
      plan: PassPlanState.pro,
      challenge: ChallengeKind.typeAlertTitle,
    ),
    'sound-long': _Setup(plan: PassPlanState.pro, ownSound: longName),
    // An own sound saved as the default, Pro lapsed: the card names the
    // sound that rings instead.
    'sound-lapsed': _Setup(ownSound: longName),
    'sound-nopeaks': const _Setup(plan: PassPlanState.pro, hasPeaks: false),
    'icon-crowned': const _Setup(
      plan: PassPlanState.hosted,
      icon: AppIcon.crowned,
    ),
    'all-long': _Setup(
      plan: PassPlanState.pro,
      challenge: ChallengeKind.typeAlertTitle,
      ownSound: longName,
      icon: AppIcon.shadesCrown,
    ),
  };
  for (final MapEntry(key: state, value: setup) in values.entries) {
    for (final mode in passThemes) {
      _shot(
        part: 'values',
        state: state,
        setup: setup,
        device: passPhone,
        mode: mode,
      );
    }
    for (final scale in const [1.3, 2.0]) {
      _shot(
        part: 'values',
        state: state,
        setup: setup,
        device: passPhone,
        mode: ThemeMode.light,
        scale: scale,
      );
    }
  }
  // The Wake-up challenge card: none chosen, locked, and each kind.
  final challengeStates = <String, _Setup>{
    'challenge-none': const _Setup(plan: PassPlanState.pro),
    'challenge-locked': const _Setup(challenge: ChallengeKind.shake),
    for (final kind in ChallengeKind.values)
      'challenge-${kind.name}': _Setup(
        plan: PassPlanState.pro,
        challenge: kind,
      ),
  };
  for (final MapEntry(key: state, value: setup) in challengeStates.entries) {
    for (final mode in passThemes) {
      for (final scale in const [1.0, 2.0]) {
        _shot(
          part: 'challenge',
          state: state,
          setup: setup,
          device: passPhone,
          mode: mode,
          scale: scale,
          act: scale < 2 ? null : _scrollToChallenge,
        );
      }
    }
  }
  // Three passes: a platform with no widgets and no icon change.
  for (final mode in passThemes) {
    _shot(
      part: 'web',
      state: 'web',
      setup: const _Setup(isWeb: true),
      device: passPhone,
      mode: mode,
    );
  }
  _shot(
    part: 'web',
    state: 'web',
    setup: const _Setup(isWeb: true),
    device: passPhone,
    mode: ThemeMode.light,
    scale: 1.3,
  );
  _shot(
    part: 'web',
    state: 'web',
    setup: const _Setup(isWeb: true),
    device: passTablet,
    mode: ThemeMode.light,
  );

  // The Look pass in each look.
  for (final look in const [
    'standard',
    'minimal',
    'terminal',
    'red_alert',
    'crit_panic',
    'own',
  ]) {
    for (final mode in passThemes) {
      _shot(
        part: 'looks',
        state: 'look-$look',
        setup: _Setup(
          plan: PassPlanState.pro,
          look: look == 'standard' ? null : look,
          hasOwnPhoto: look == 'own',
        ),
        device: passPhone,
        mode: mode,
      );
    }
  }

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

  // The two moving thumbnails at a second of their clock.
  for (final mode in passThemes) {
    for (final second in const [0.3, 0.9]) {
      final name = passFileName(
        page: _page,
        device: passPhone,
        mode: mode,
        scale: 1,
        frame: 'clock-${second == 0.3 ? 'rock-plus' : 'rock-minus'}',
        state: 'pro',
      );
      if (!_parts.contains('motion') || !passWanted(name)) continue;
      testWidgets('capture $name', (tester) async {
        await _guarded(name, (errors) async {
          final run = await _open(
            tester,
            setup: const _Setup(plan: PassPlanState.pro),
            device: passPhone,
            mode: mode,
            scale: 1,
            holdThumbs: false,
          );
          // Run the clock to the second asked for.
          final clock = tester.state<PaywallClockState<PassThumbClock>>(
            find.byType(PassThumbClock),
          );
          // The clock has run while the screen settled. Wait for the next
          // moment the rock is at the angle this shot is named for: a
          // quarter of the way through a swing (+4 degrees) or three
          // quarters (-4 degrees).
          final into = clock.t % passThumbRockPeriod;
          final ahead =
              (second - into + passThumbRockPeriod) % passThumbRockPeriod;
          await tester.pump(Duration(milliseconds: (ahead * 1000).round()));
          await _save(tester, run, name, errors);
        });
      });
    }
  }

  // The grow, open and back, from the real route.
  for (final mode in passThemes) {
    for (final pass in PassId.values) {
      final base = passFileName(
        page: 'grow-${pass.name}',
        device: passPhone,
        mode: mode,
        scale: 1,
        frame: 'x',
        state: 'free',
      );
      if (!_parts.contains('grow') || !passWanted(base)) continue;
      testWidgets('capture grow ${pass.name} ${mode.name}', (tester) async {
        await _guarded(base, (errors) async {
          final run = await _open(
            tester,
            setup: const _Setup(),
            device: passPhone,
            mode: mode,
            scale: 1,
          );
          await _grow(tester, run, pass, back: true, (frame) async {
            final name = passFileName(
              page: 'grow-${pass.name}',
              device: passPhone,
              mode: mode,
              scale: 1,
              frame: frame,
              state: 'free',
            );
            await _save(tester, run, name, errors);
          });
        });
      });
    }

    // The other pages, once open, and a page with no card.
    for (final pass in const [
      PassId.challenge,
      PassId.widgets,
      PassId.appIcon,
    ]) {
      _shot(
        part: 'grow',
        state: 'free',
        setup: const _Setup(),
        device: passPhone,
        mode: mode,
        frame: 'page-${pass.name}',
        act: (tester, run) async {
          await _tapCard(tester, pass);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        },
      );
    }
  }
  for (final mode in passThemes) {
    _shot(
      part: 'grow',
      state: 'free',
      setup: const _Setup(),
      device: passPhone,
      mode: mode,
      frame: 'deeplink-look',
      act: (tester, run) async {
        run.router.go('/settings/personalize/look');
        await _settle(tester);
      },
    );
  }

  // Reduce motion: the finished page fades over the root.
  final reduceBase = passFileName(
    page: 'grow-look',
    device: passPhone,
    mode: ThemeMode.light,
    scale: 1,
    frame: 'reduce',
    state: 'free',
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
        );
        await _grow(tester, run, PassId.look, reduceMotion: true, (
          frame,
        ) async {
          const wanted = [
            'open-t000',
            'open-t025',
            'open-t050',
            'open-t075',
            'open-t100',
            'back-t025',
            'back-t050',
            'back-t075',
          ];
          if (!wanted.contains(frame)) return;
          await _save(
            tester,
            run,
            passFileName(
              page: 'grow-look',
              device: passPhone,
              mode: ThemeMode.light,
              scale: 1,
              frame: 'reduce-$frame',
              state: 'free',
            ),
            errors,
          );
        });
      });
    });
  }
}
