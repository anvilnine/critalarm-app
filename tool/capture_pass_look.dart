// Captures the Look page, the deck of phones, off the device, on the mock
// server and the developer plan switches, through the real router and the
// real ambient shell.
//
//   fvm flutter test tool/capture_pass_look.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
// and the page is `look`.
//
// Parts, picked with --dart-define=PARTS=plans,sizes (default: all):
//   plans      the page in every plan state, with a locked look in the middle
//              so the bottom action is the try bar: free, pro, hosted, notread
//              (the plan still being read), own (a server of the user's own,
//              nothing held); confirming and unreadable at 390 by 844 light
//   sizes      free at 375 by 667, 320 by 640, 1024 by 768 and 844 by 390, and
//              at text scale 1.3 and 2.0 where the matrix has them
//   positions  the deck at each of its six positions, free, light and dark
//   opens      the page opening on the look in use, each of the six looks
//   fade       the page between two looks at 0.25, 0.5 and 0.75 of the way,
//              Standard to Minimal, and Terminal to Red alert to Crit panic
//   yours      Yours with no photo (open and locked), with a photo held, with
//              a lapsed plan and the photo kept, and with the plan not read
//   taps       the locked look tried and then kept (the paywall), the plan not
//              read, the look in use, the open look kept, a neighbour tapped
//              and the full-screen preview
//   sheets     the pencil and the cross on Yours, the sheets behind them
//   crop       the crop screen
//   reduce     the resting frame under reduce motion
//   rock       the centred phone at the top of its rock
//   grow       the page reached from the root, at progress 0, 0.25, 0.5, 0.75
//              and 1, open and back, and the page opening on a dark look
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a204)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the deck moving, the fade playing or the rock.
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
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_photo_crop_screen.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumbs.dart';
import 'package:critalarm/features/settings/presentation/personalize/try_bar.dart';
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

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a204');
const _partsArg = String.fromEnvironment('PARTS');

const _page = 'look';

/// A server of the user's own with nothing held: Look, Sound, Challenge and
/// Widgets still need Pro there.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// The deck's positions, in order.
const _looks = [
  'standard',
  'minimal',
  'terminal',
  'red_alert',
  'crit_panic',
  'own',
];

/// How the phone holds the person's own photo.
enum _Photo {
  /// No photo is saved.
  none,

  /// A photo is saved and the look can be drawn: Pro is held.
  held,

  /// A photo is saved and the plan has lapsed, so the look cannot be drawn.
  saved,
}

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.look,
    this.photo = _Photo.none,
  });

  final PassPlanState plan;

  /// The saved look id, or null for the standard one.
  final String? look;
  final _Photo photo;
}

Map<String, Object> _planPrefs(PassPlanState plan) {
  final preset = plan.preset;
  return {
    if (preset != null)
      for (final entry in preset.holdings.entries)
        DevAccessSwitches.holdingKey(entry.key): entry.value.name,
    if (preset != null && preset.holdsPlanRead)
      DevAccessSwitches.holdsPlanReadKey: true,
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
  if (setup.photo != _Photo.none) {
    await importCaptureOwnLook(
      CapturePhoto.bright,
      screen: phone * 2,
      isHeld: setup.photo == _Photo.held,
    );
  }
  final look = setup.look;
  if (look != null) await getIt<AlarmStyleChoices>().setDefault(look);
}

/// Lets the phone ask the app icon and the sound host what they would.
void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async => call.method == 'current' ? 'default' : true,
        )
        ..setMockMethodCallHandler(
          const MethodChannel(SoundHost.channelName),
          (call) async => switch (call.method) {
            'readPeaks' => <double>[],
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

  /// Where the router is now.
  String get path =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

Future<_Run> _open(
  WidgetTester tester, {
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  bool reduceMotion = false,
  bool holdClock = true,
  String location = '/settings/personalize/look',
}) async {
  _mockChannels();
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
            // A held clock draws the resting frame of the rock, so two shots
            // of one state are the same picture.
            child: PaywallStill(
              isStill: holdClock,
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
  // The saved photo's small copy is decoded by the engine, off the test clock.
  await _real(tester);
  await tester.pump(const Duration(milliseconds: 100));
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
    ? {
        'plans',
        'sizes',
        'positions',
        'opens',
        'fade',
        'yours',
        'taps',
        'sheets',
        'crop',
        'reduce',
        'rock',
        'grow',
      }
    : _partsArg.split(',').toSet();

/// Registers one capture of the page.
///
/// [at] is the position of the deck to show: a whole number moves the deck by
/// its dot, a fraction puts it that far between two looks.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  String frame = 'rest',
  bool reduceMotion = false,
  double? at,
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
      if (at != null) await _moveTo(tester, at);
      if (act != null) await act(tester, run);
      await _save(tester, run, name, errors);
    });
  });
}

/// Puts the deck at [page]. A whole page is reached the way a person would,
/// by its dot, and comes to rest. A fraction is a jump to that place between
/// two looks, held there.
Future<void> _moveTo(WidgetTester tester, double page) async {
  if (page == page.roundToDouble()) {
    final dot = find.byKey(ValueKey('look-dot-${page.round()}'));
    expect(dot, findsOneWidget);
    // At large text the dots can sit below the fold. Scroll to them, tap,
    // and put the page back at the top for the picture.
    await tester.ensureVisible(dot);
    await tester.pump();
    await tester.tap(dot);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    final outer = tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byType(PageView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    outer.position.jumpTo(0);
    await tester.pump();
    return;
  }
  final scrollable = tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(Scrollable),
        ),
      )
      .first;
  final position = scrollable.position;
  final fraction = (position as PageMetrics).viewportFraction;
  position.jumpTo(page * position.viewportDimension * fraction);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Taps the card of the Look pass on the root.
Future<void> _tapLookCard(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('pass-look'));
  expect(card, findsOneWidget, reason: 'no Look card');
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

/// Opens the Look page from its card, and calls [onFrame] with the share of
/// the way through the transition: 0, 0.25, 0.5, 0.75 and 1.
Future<void> _grow(
  WidgetTester tester,
  _Run run,
  Future<void> Function(String frame) onFrame, {
  bool back = false,
}) async {
  const fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
  await _tapLookCard(tester);
  await tester.pump();
  await tester.pump();
  var elapsed = 0;
  for (final fraction in fractions) {
    final target = (600 * fraction).round();
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
  elapsed = 0;
  for (final fraction in fractions) {
    final target = (520 * fraction).round();
    if (target > elapsed) {
      await tester.pump(Duration(milliseconds: target - elapsed));
      elapsed = target;
    }
    await onFrame(
      'back-t${(fraction * 100).round().toString().padLeft(3, '0')}',
    );
  }
}

/// The photo the crop screen is shown, decoded once.
late ui.Image _cropPicture;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
    _cropPicture = await capturePhotoImage(CapturePhoto.busy);
  });

  tearDownAll(() async {
    _cropPicture.dispose();
    await dropCaptureOwnLookStore();
  });

  // A locked look in the middle, so the bottom action is the try bar.
  const free = _Setup();
  const minimal = 1.0;

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
        at: minimal,
        frame: 'minimal',
      );
    }
  }

  // The sizes and text scales, on the free phone, with Minimal in the middle.
  for (final device in passDevices) {
    for (final scale in passScalesFor(device)) {
      for (final mode in passThemes) {
        if (device == passPhone && scale == 1) continue;
        _shot(
          part: 'sizes',
          state: 'free',
          setup: free,
          device: device,
          mode: mode,
          scale: scale,
          at: minimal,
          frame: 'minimal',
        );
      }
    }
  }
  // The look in use in the middle, at the sizes that matter most.
  for (final device in [passPhone, passNarrowPhone]) {
    for (final scale in const [1.0, 2.0]) {
      for (final mode in passThemes) {
        _shot(
          part: 'sizes',
          state: 'free',
          setup: free,
          device: device,
          mode: mode,
          scale: scale,
          frame: 'standard',
        );
      }
    }
  }

  // The deck at each of its six positions.
  for (var i = 0; i < _looks.length; i++) {
    for (final mode in passThemes) {
      _shot(
        part: 'positions',
        state: 'free',
        setup: free,
        device: passPhone,
        mode: mode,
        at: i.toDouble(),
        frame: 'pos${i}_${_looks[i]}',
      );
    }
  }
  // Pro held: no badge, no try bar, "Use this look".
  for (final mode in passThemes) {
    _shot(
      part: 'positions',
      state: 'pro',
      setup: const _Setup(plan: PassPlanState.pro),
      device: passPhone,
      mode: mode,
      at: 3,
      frame: 'pos3_red_alert',
    );
  }

  // The page opening on the look in use.
  for (final look in _looks) {
    for (final mode in passThemes) {
      _shot(
        part: 'opens',
        state: 'pro',
        setup: _Setup(
          plan: PassPlanState.pro,
          look: look == 'standard' ? null : look,
          photo: look == 'own' ? _Photo.held : _Photo.none,
        ),
        device: passPhone,
        mode: mode,
        frame: 'opens-$look',
      );
    }
  }

  // Between two looks.
  const pairs = <String, List<double>>{
    'standard-minimal': [0.25, 0.5, 0.75],
    'terminal-red_alert': [2.25, 2.5, 2.75],
    'red_alert-crit_panic': [3.25, 3.5, 3.75],
  };
  for (final MapEntry(key: pair, value: pages) in pairs.entries) {
    for (final page in pages) {
      for (final mode in passThemes) {
        _shot(
          part: 'fade',
          state: 'free',
          setup: free,
          device: passPhone,
          mode: mode,
          at: page,
          frame: 'fade-$pair-p${(page * 100).round()}',
        );
      }
    }
  }
  // The fade under reduce motion holds the ground until the deck settles.
  for (final mode in passThemes) {
    _shot(
      part: 'fade',
      state: 'free',
      setup: free,
      device: passPhone,
      mode: mode,
      at: 0.5,
      frame: 'fade-reduce-p50',
      reduceMotion: true,
    );
  }

  // Yours.
  const yoursStates = <String, _Setup>{
    // No photo, nothing held: the add button is open.
    'none-pro': _Setup(plan: PassPlanState.pro),
    // No photo, nothing held: the add button has the badge.
    'none-free': _Setup(),
    // The plan still being read: no badge, a tap waits.
    'none-notread': _Setup(plan: PassPlanState.notRead),
    // A photo held: a look like the others, with a pencil.
    'held-pro': _Setup(plan: PassPlanState.pro, photo: _Photo.held),
    // A photo kept and the plan lapsed: a locked look with a cross.
    'saved-free': _Setup(photo: _Photo.saved),
  };
  for (final MapEntry(key: state, value: setup) in yoursStates.entries) {
    for (final mode in passThemes) {
      _shot(
        part: 'yours',
        state: state,
        setup: setup,
        device: passPhone,
        mode: mode,
        at: 5,
        frame: 'yours',
      );
    }
    _shot(
      part: 'yours',
      state: state,
      setup: setup,
      device: passPhone,
      mode: ThemeMode.light,
      scale: 2,
      at: 5,
      frame: 'yours',
    );
  }
  // Yours held and in use.
  for (final mode in passThemes) {
    _shot(
      part: 'yours',
      state: 'held-inuse',
      setup: const _Setup(
        plan: PassPlanState.pro,
        look: 'own',
        photo: _Photo.held,
      ),
      device: passPhone,
      mode: mode,
      frame: 'yours',
    );
  }

  // The taps.
  _shot(
    part: 'taps',
    state: 'free',
    setup: free,
    device: passPhone,
    mode: ThemeMode.light,
    at: minimal,
    frame: 'try-then-keep-paywall',
    act: (tester, run) async {
      // Swiping to the locked look opened nothing.
      expect(run.path, '/settings/personalize/look');
      final keep = find.descendant(
        of: find.byType(PersonalizeTryBar),
        matching: find.byType(AppButton),
      );
      // The bar holds an invisible copy of itself to keep its height, so the
      // button that takes the tap is the last one.
      expect(keep, findsWidgets);
      await tester.tap(keep.last);
      await _settle(tester);
      // The act of using it reached the paywall.
      expect(run.path, isNot('/settings/personalize/look'));
    },
  );
  _shot(
    part: 'taps',
    state: 'free',
    setup: free,
    device: passPhone,
    mode: ThemeMode.light,
    at: minimal,
    frame: 'tap-neighbour',
    act: (tester, run) async {
      // A tap on a neighbour moves the deck and sells nothing.
      final dot = find.byKey(const ValueKey('look-dot-3'));
      await tester.tap(dot);
      await tester.pump(const Duration(milliseconds: 700));
      expect(run.path, '/settings/personalize/look');
      final before = getIt<AlarmStyleChoices>().assignments.defaultStyleId;
      expect(before, isNot('red_alert'), reason: 'a swipe saved a look');
    },
  );
  _shot(
    part: 'taps',
    state: 'notread',
    setup: const _Setup(plan: PassPlanState.notRead),
    device: passPhone,
    mode: ThemeMode.light,
    at: minimal,
    frame: 'tap-use-waits',
    act: (tester, run) async {
      await tester.tap(find.byKey(const ValueKey('look-use')));
      await tester.pump();
      await _real(tester);
      await tester.pump(const Duration(milliseconds: 800));
      // The tap waits for the plan: no paywall, nothing saved.
      expect(run.path, '/settings/personalize/look');
      expect(
        getIt<AlarmStyleChoices>().assignments.defaultStyleId,
        isNot('minimal'),
      );
    },
  );
  _shot(
    part: 'taps',
    state: 'free',
    setup: free,
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'tap-in-use',
    act: (tester, run) async {
      await tester.tap(find.byKey(const ValueKey('look-in-use')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(run.path, '/settings/personalize/look');
    },
  );
  _shot(
    part: 'taps',
    state: 'pro',
    setup: const _Setup(plan: PassPlanState.pro),
    device: passPhone,
    mode: ThemeMode.light,
    at: minimal,
    frame: 'tap-use-saved',
    act: (tester, run) async {
      await tester.tap(find.byKey(const ValueKey('look-use')));
      await tester.pump();
      // The lock rule waits for the plan to be read, off the test clock.
      await _real(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        getIt<AlarmStyleChoices>().assignments.defaultStyleId,
        'minimal',
      );
    },
  );
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(),
    device: passPhone,
    mode: ThemeMode.light,
    at: 5,
    frame: 'tap-add-photo-paywall',
    act: (tester, run) async {
      await tester.tap(find.byKey(const ValueKey('look-add-photo')));
      await _settle(tester);
      expect(run.path, isNot('/settings/personalize/look'));
    },
  );
  _shot(
    part: 'taps',
    state: 'pro',
    setup: const _Setup(plan: PassPlanState.pro),
    device: passPhone,
    mode: ThemeMode.light,
    at: 2,
    frame: 'tap-centre-preview',
    act: (tester, run) async {
      // The centred phone is where the deck put it: tap its middle.
      final view = tester.getSize(find.byType(PageView));
      final top = tester.getTopLeft(find.byType(PageView));
      await tester.tapAt(top + Offset(view.width / 2, view.height / 2));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  // The sheets behind the pencil and the cross.
  for (final mode in passThemes) {
    _shot(
      part: 'sheets',
      state: 'held-pro',
      setup: const _Setup(plan: PassPlanState.pro, photo: _Photo.held),
      device: passPhone,
      mode: mode,
      at: 5,
      frame: 'sheet-pencil',
      act: (tester, run) async {
        final corner = find.byKey(const ValueKey('look-own-edit'));
        expect(corner, findsOneWidget);
        await tester.tap(corner);
        await tester.pump();
        await _real(tester);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      },
    );
    _shot(
      part: 'sheets',
      state: 'saved-free',
      setup: const _Setup(photo: _Photo.saved),
      device: passPhone,
      mode: mode,
      at: 5,
      frame: 'sheet-cross',
      act: (tester, run) async {
        final corner = find.byKey(const ValueKey('look-own-remove'));
        expect(corner, findsOneWidget);
        await tester.tap(corner);
        await tester.pump();
        await _real(tester);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      },
    );
  }

  // The crop screen, on a busy photo.
  for (final mode in _parts.contains('crop') ? passThemes : <ThemeMode>[]) {
    for (final scale in const [1.0, 1.3]) {
      registerPassShot(
        name: passFileName(
          page: _page,
          device: passPhone,
          mode: mode,
          scale: scale,
          frame: 'crop',
          state: 'free',
        ),
        device: passPhone,
        mode: mode,
        scale: scale,
        build: (context) => OwnPhotoCropScreen(
          picture: _cropPicture,
          onUse: (crop) async => null,
        ),
      );
    }
  }

  // Reduce motion: the resting frame.
  for (final mode in passThemes) {
    for (final (at, frame) in [(0.0, 'standard'), (1.0, 'minimal')]) {
      _shot(
        part: 'reduce',
        state: 'free',
        setup: free,
        device: passPhone,
        mode: mode,
        at: at,
        frame: 'reduce-$frame',
        reduceMotion: true,
      );
    }
  }

  // The centred phone at the top of its rock.
  for (final mode in passThemes) {
    final name = passFileName(
      page: _page,
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'clock-rock-plus',
      state: 'pro',
    );
    if (!_parts.contains('rock') || !passWanted(name)) continue;
    testWidgets('capture $name', (tester) async {
      await _guarded(name, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(plan: PassPlanState.pro),
          device: passPhone,
          mode: mode,
          scale: 1,
          holdClock: false,
        );
        final clock = tester.state<PaywallClockState<PassThumbClock>>(
          find.byType(PassThumbClock),
        );
        // A quarter of the way through a swing is the top of the rock.
        final into = clock.t % lookRockPeriod;
        final ahead =
            (lookRockPeriod / 4 - into + lookRockPeriod) % lookRockPeriod;
        await tester.pump(Duration(milliseconds: (ahead * 1000).round()));
        await _save(tester, run, name, errors);
      });
    });
  }

  // The grow from the root, open and back.
  for (final mode in passThemes) {
    for (final (setup, state) in const [
      (_Setup(), 'free'),
      (_Setup(plan: PassPlanState.pro, look: 'terminal'), 'terminal'),
    ]) {
      final base = passFileName(
        page: 'grow-look',
        device: passPhone,
        mode: mode,
        scale: 1,
        frame: 'x',
        state: state,
      );
      if (!_parts.contains('grow') || !passWanted(base)) continue;
      testWidgets('capture grow $state ${mode.name}', (tester) async {
        await _guarded(base, (errors) async {
          final run = await _open(
            tester,
            setup: setup,
            device: passPhone,
            mode: mode,
            scale: 1,
            location: '/settings/personalize',
          );
          await _grow(tester, run, back: state == 'free', (frame) async {
            final name = passFileName(
              page: 'grow-look',
              device: passPhone,
              mode: mode,
              scale: 1,
              frame: frame,
              state: state,
            );
            await _save(tester, run, name, errors);
          });
        });
      });
    }
  }
  _shot(
    part: 'grow',
    state: 'free',
    setup: free,
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'deeplink',
  );

  // Scroll: the header at rest, half way through its collapse and collapsed,
  // on both phones and both text scales. A tall phone does not scroll the
  // page, so its three shots match.
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
