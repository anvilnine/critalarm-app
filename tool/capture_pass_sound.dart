// Captures the Sound page of Personalize, the sound picker in the pass look,
// off the device, on the mock server and the developer plan switches, through
// the real router and the real ambient shell.
//
//   fvm flutter test tool/capture_pass_sound.dart \
//     --dart-define=SKIP_PAYWALL=true
//
// The define lets the developer plan switches hold a plan.
//
// Every file is named by the pass kit (`capture_pass_kit.dart`):
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
// The frame is `top` (as the page opens) or `end` (scrolled to the end of the
// sheet), or a moment of a preview, a tap or the grow.
//
// Parts, picked with --dart-define=PARTS=plans,sizes (default: all):
//   plans    the page in every plan state: free, pro, hosted, notread (the plan
//            still being read), own (a server of the user's own, nothing
//            held), confirming, unreadable. 390 by 844, light and dark; the
//            last two light only. One own sound is saved and rings, so the
//            lock shows where it matters.
//   sizes    free at 375 by 667, 320 by 640, 600 by 844, 1024 by 768 and
//            844 by 390, and at text scale 1.3 and 2.0 where the matrix has
//            them
//   states   resting and playing (the playhead at the start, half way and at
//            the end), a locked own sound row, Pick a file and Record locked
//            and open, a phone that cannot import sounds, a sound with no
//            waveform, a 30 character own sound name, per-topic mode
//   packs    the pack section in each state: not downloaded, downloading,
//            downloaded, failed, unavailable
//   taps     a locked own sound: the play button (a try) and the tap on the
//            row, on Pick a file and on Record (each opens the paywall)
//   reduce   the resting frame and a preview under reduce motion
//   grow     the page reached from the root at progress 0, 0.25, 0.5, 0.75
//            and 1 of the grow, and a page opened with no card
//
// Optional:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures/a205)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//
// A capture fails when anything overflows. It is a still of each moment: it
// does not show the playhead moving or the grow playing.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/sound/sound_sheet.dart';
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

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures/a205');
const _partsArg = String.fromEnvironment('PARTS');

/// The page name in every file.
const _page = 'sound';

/// A server of the user's own with nothing held: Look, Sound, Challenge and
/// Widgets still need Pro there, so own sounds stay locked.
const _ownServer = PassPlanState(
  'own',
  preset: AccessPreset.free,
  isOwnServer: true,
);

/// What a shot starts with, besides the plan.
class _Setup {
  const _Setup({
    this.plan = PassPlanState.free,
    this.ownSoundName = 'My recording',
    this.canImport = true,
    this.hasPeaks = true,
    this.pack,
  });

  final PassPlanState plan;

  /// The saved own sound, or null for none.
  final String? ownSoundName;

  /// Whether the phone can bring in a sound: Pick a file and Record show.
  final bool canImport;

  /// Whether the sound host answers a read of peaks.
  final bool hasPeaks;

  /// The wire word of the sound pack's state, or null for a platform with no
  /// packs.
  final String? pack;
}

AlarmSound _ownSoundNamed(String name) => AlarmSound(
  id: 'user_capture',
  name: name,
  source: AlarmSoundSource.user,
  path: '/sounds/user_capture.caf',
  duration: const Duration(seconds: 4),
  peaks: [for (var i = 0; i < 48; i++) 0.25 + 0.7 * ((i * 7) % 11) / 10],
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
  final name = setup.ownSoundName;
  if (name != null) {
    final sounds = getIt<AlarmSoundRepository>();
    await sounds.addUserSound(_ownSoundNamed(name));
    await sounds.setDefaultSoundId('user_capture');
  }
}

/// Lets the phone answer the sound host and the pack store as a real one
/// would.
void _mockChannels(_Setup setup) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async => call.method == 'current' ? 'default' : true,
        )
        ..setMockMethodCallHandler(
          const MethodChannel(SoundHost.channelName),
          (call) async => switch (call.method) {
            'readPeaks' =>
              setup.hasPeaks
                  ? _peaksFor('${(call.arguments as Map)['path']}')
                  : <double>[],
            'capabilities' => <String, Object?>{
              'can_import_sounds': setup.canImport,
            },
            'startPreview' || 'stopPreview' => true,
            _ => null,
          },
        )
        ..setMockMethodCallHandler(
          const MethodChannel(SoundPackHost.channelName),
          (call) async {
            final wire = setup.pack;
            if (wire == null) throw MissingPluginException();
            final args = (call.arguments as Map<Object?, Object?>?) ?? {};
            final ids = (args['ids'] as List<Object?>? ?? const [])
                .cast<String>();
            return switch (call.method) {
              'packState' || 'download' => <String, Object?>{
                'state': wire,
                if (wire == 'downloading') 'progress': 0.4,
              },
              'installedPackSounds' || 'installPack' =>
                wire == 'downloaded'
                    ? [
                        for (final id in ids)
                          {'id': id, 'path': '/sounds/$id.ogg'},
                      ]
                    : <Object?>[],
              _ => null,
            };
          },
        );
  addTearDown(() {
    for (final channel in const [
      AppIconHost.channelName,
      SoundHost.channelName,
      SoundPackHost.channelName,
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });
}

/// A different wave for every sound, so two rows are never the same picture.
List<double> _peaksFor(String path) {
  final seed = path.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 9973);
  final pace = 0.2 + (seed % 7) * 0.07;
  return [
    for (var i = 0; i < 48; i++)
      0.18 +
          0.78 *
              math.sin(i * pace + seed).abs() *
              (0.6 + 0.4 * math.cos(i * 0.31)).abs(),
  ];
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
  String location = '/sounds',
  bool settleAfter = true,
}) async {
  _mockChannels(setup);
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
            // The root's two moving thumbnails hold their resting frame.
            child: PaywallStill(
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
  if (settleAfter) {
    unawaited(router.push(location));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1));
  }
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
    ? {'plans', 'sizes', 'states', 'packs', 'taps', 'reduce', 'grow'}
    : _partsArg.split(',').toSet();

/// The sheet's scroll position.
ScrollPosition _position(WidgetTester tester) =>
    Scrollable.of(tester.element(find.byType(SoundSheet))).position;

/// Scrolls the page to the end of the sheet.
Future<void> _toEnd(WidgetTester tester, _Run run) async {
  _position(tester).jumpTo(_position(tester).maxScrollExtent);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Scrolls the page until [text] sits near the top.
Future<void> _reveal(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: 'no "$text" on the page');
  await Scrollable.ensureVisible(
    tester.element(finder.first),
    alignment: 0.25,
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Taps the play button of the first row that has one, and lets the preview
/// run for [fraction] of the sound's length.
Future<void> _play(
  WidgetTester tester, {
  required double fraction,
  Finder? button,
  Duration length = const Duration(seconds: 16),
}) async {
  await tester.tap((button ?? find.byType(AppPreviewButton)).first);
  await tester.pump();
  await _real(tester, 100);
  await tester.pump();
  if (fraction > 0) {
    await tester.pump(
      Duration(milliseconds: (length.inMilliseconds * fraction).round()),
    );
  }
}

/// Registers one capture of the page as it opens.
void _shot({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  String frame = 'top',
  bool reduceMotion = false,
  String location = '/sounds',
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

/// A page at its top, then at its end.
void _topAndEnd({
  required String part,
  required String state,
  required _Setup setup,
  required PassDevice device,
  required ThemeMode mode,
  double scale = 1,
  bool reduceMotion = false,
  bool withEnd = true,
}) {
  _shot(
    part: part,
    state: state,
    setup: setup,
    device: device,
    mode: mode,
    scale: scale,
    reduceMotion: reduceMotion,
  );
  if (!withEnd) return;
  _shot(
    part: part,
    state: state,
    setup: setup,
    device: device,
    mode: mode,
    scale: scale,
    frame: 'end',
    reduceMotion: reduceMotion,
    act: _toEnd,
  );
}

/// Taps the card of [pass] on the band that shows.
Future<void> _tapCard(WidgetTester tester, PassId pass) async {
  final card = find.byKey(ValueKey('pass-${pass.name}'));
  expect(card, findsOneWidget, reason: 'no card for ${pass.name}');
  await tester.tapAt(tester.getTopLeft(card) + const Offset(120, 40));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  const longName = 'Boiler room fire alarm test 01';
  final length = BundledSounds.durations[BundledSounds.fallbackId]!;

  // The plan states.
  for (final plan in PassPlanState.all) {
    final p = plan.name == 'own' ? _ownServer : plan;
    final isMain = const {'free', 'pro', 'hosted', 'notread', 'own'}.contains(
      p.name,
    );
    for (final mode in isMain ? passThemes : [ThemeMode.light]) {
      _topAndEnd(
        part: 'plans',
        state: p.name,
        setup: _Setup(plan: p, pack: 'not_downloaded'),
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
        _topAndEnd(
          part: 'sizes',
          state: 'free',
          setup: const _Setup(pack: 'not_downloaded'),
          device: device,
          mode: mode,
          scale: scale,
          withEnd: mode == ThemeMode.light,
        );
      }
    }
  }

  // The states of the wave and the rows.
  for (final mode in passThemes) {
    // Playing: the playhead at the start, half way and at the end.
    for (final (fraction, frame) in const [
      (0.0, 'playing-t000'),
      (0.5, 'playing-t050'),
      (0.98, 'playing-t100'),
    ]) {
      _shot(
        part: 'states',
        state: 'free',
        setup: const _Setup(pack: 'not_downloaded'),
        device: passPhone,
        mode: mode,
        frame: frame,
        act: (tester, run) => _play(tester, fraction: fraction, length: length),
      );
    }
    // The locked own sound's own wave, playing: a try.
    _shot(
      part: 'states',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
      frame: 'playing-own',
      act: (tester, run) async {
        await _toEnd(tester, run);
        await _play(
          tester,
          fraction: 0.5,
          length: const Duration(seconds: 4),
          button: find
              .descendant(
                of: find.byType(SoundRow),
                matching: find.byType(AppPreviewButton),
              )
              .last,
        );
      },
    );
    // Pro held: the same own sound is open and rings.
    _topAndEnd(
      part: 'states',
      state: 'pro-own',
      setup: const _Setup(plan: PassPlanState.pro, pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
    );
    // No wave to draw: the host cannot read peaks.
    _shot(
      part: 'states',
      state: 'nopeaks',
      setup: const _Setup(hasPeaks: false, pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
    );
    // A phone that cannot bring in a sound: no Your sounds section.
    _shot(
      part: 'states',
      state: 'noimport',
      setup: const _Setup(
        plan: PassPlanState.pro,
        ownSoundName: null,
        canImport: false,
        pack: 'not_downloaded',
      ),
      device: passPhone,
      mode: mode,
      frame: 'end',
      act: _toEnd,
    );
    // Nothing saved yet: Your sounds holds only the two ways in.
    _shot(
      part: 'states',
      state: 'noown',
      setup: const _Setup(ownSoundName: null, pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
      frame: 'end',
      act: _toEnd,
    );
    // Per-topic mode: the label names the topic, no card to grow from.
    _shot(
      part: 'states',
      state: 'topic',
      setup: const _Setup(
        plan: PassPlanState.pro,
        ownSoundName: null,
        pack: 'not_downloaded',
      ),
      device: passPhone,
      mode: mode,
      location: '/sounds?topic=prod-db',
    );
  }
  // A 30 character own sound name rings: the header, the wave and the row.
  for (final scale in const [1.0, 2.0]) {
    for (final mode in passThemes) {
      _topAndEnd(
        part: 'states',
        state: 'longname-pro',
        setup: const _Setup(
          plan: PassPlanState.pro,
          ownSoundName: longName,
          pack: 'not_downloaded',
        ),
        device: passPhone,
        mode: mode,
        scale: scale,
      );
    }
  }
  // The same name, Pro lapsed: the stand-in rings and the row is locked.
  _topAndEnd(
    part: 'states',
    state: 'longname-free',
    setup: const _Setup(ownSoundName: longName, pack: 'not_downloaded'),
    device: passPhone,
    mode: ThemeMode.light,
  );
  _shot(
    part: 'states',
    state: 'longname-free',
    setup: const _Setup(ownSoundName: longName, pack: 'not_downloaded'),
    device: passNarrowPhone,
    mode: ThemeMode.light,
    scale: 2,
    frame: 'end',
    act: _toEnd,
  );

  // The pack section in each state.
  for (final pack in const [
    'not_downloaded',
    'downloading',
    'downloaded',
    'failed',
    'unavailable',
  ]) {
    for (final mode in passThemes) {
      _shot(
        part: 'packs',
        state: 'pack-$pack',
        setup: _Setup(plan: PassPlanState.pro, pack: pack),
        device: passPhone,
        mode: mode,
        frame: 'packs',
        act: (tester, run) => _reveal(tester, 'Sound packs'),
      );
    }
  }

  // A tap on something locked.
  for (final mode in passThemes) {
    _shot(
      part: 'taps',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
      frame: 'tap-row',
      act: (tester, run) async {
        await _toEnd(tester, run);
        await tester.tap(find.text('My recording').last);
        await _settle(tester);
        expect(
          run.router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/pro',
          reason: 'keeping a locked own sound opens the paywall',
        );
      },
    );
  }
  for (final way in const ['Pick a file', 'Record']) {
    _shot(
      part: 'taps',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: passPhone,
      mode: ThemeMode.light,
      frame: 'tap-${way.toLowerCase().replaceAll(' ', '-')}',
      act: (tester, run) async {
        await _toEnd(tester, run);
        await tester.tap(find.text(way).last);
        await _settle(tester);
        expect(
          run.router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/pro',
          reason: '$way opens the paywall while own sounds are locked',
        );
      },
    );
  }
  // The row is still not marked after the paywall closes, and nothing saved.
  _shot(
    part: 'taps',
    state: 'free',
    setup: const _Setup(pack: 'not_downloaded'),
    device: passPhone,
    mode: ThemeMode.light,
    frame: 'tap-row-back',
    act: (tester, run) async {
      await _toEnd(tester, run);
      await tester.tap(find.text('My recording').last);
      await _settle(tester);
      run.router.pop();
      await _settle(tester);
    },
  );

  // Reduce motion: the resting frame, and a preview that does not move.
  for (final mode in passThemes) {
    _shot(
      part: 'reduce',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
      frame: 'reduce',
      reduceMotion: true,
    );
    _shot(
      part: 'reduce',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: passPhone,
      mode: mode,
      frame: 'reduce-playing',
      reduceMotion: true,
      act: (tester, run) => _play(tester, fraction: 0.5, length: length),
    );
  }

  // The grow from the root, at the five moments of the transition.
  for (final mode in passThemes) {
    final base = passFileName(
      page: 'grow',
      device: passPhone,
      mode: mode,
      scale: 1,
      frame: 'x',
      state: 'free',
    );
    if (!_parts.contains('grow') || !passWanted(base)) continue;
    testWidgets('capture grow ${mode.name}', (tester) async {
      await _guarded(base, (errors) async {
        final run = await _open(
          tester,
          setup: const _Setup(pack: 'not_downloaded'),
          device: passPhone,
          mode: mode,
          scale: 1,
          location: '/settings/personalize',
        );
        await _tapCard(tester, PassId.sound);
        await tester.pump();
        await tester.pump();
        var elapsed = 0;
        for (final fraction in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final target = (600 * fraction).round();
          if (target > elapsed) {
            await tester.pump(Duration(milliseconds: target - elapsed));
            elapsed = target;
          }
          final percent = (fraction * 100).round().toString().padLeft(3, '0');
          await _save(
            tester,
            run,
            passFileName(
              page: 'grow',
              device: passPhone,
              mode: mode,
              scale: 1,
              frame: 'open-t$percent',
              state: 'free',
            ),
            errors,
          );
        }
        // The page once the list has landed.
        await _real(tester);
        await tester.pump(const Duration(milliseconds: 600));
        await _save(
          tester,
          run,
          passFileName(
            page: 'grow',
            device: passPhone,
            mode: mode,
            scale: 1,
            frame: 'open-settled',
            state: 'free',
          ),
          errors,
        );

        // The way back into the card, a quarter, half and three quarters of
        // the way, from the page at rest and then from the page collapsed.
        for (final scrolled in const [false, true]) {
          if (scrolled) {
            _position(tester).jumpTo(
              math.min(600, _position(tester).maxScrollExtent),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          run.router.pop();
          await tester.pump();
          await tester.pump();
          var back = 0;
          for (final fraction in const [0.25, 0.5, 0.75]) {
            final target = (520 * fraction).round();
            await tester.pump(Duration(milliseconds: target - back));
            back = target;
            final percent = (fraction * 100).round().toString().padLeft(3, '0');
            await _save(
              tester,
              run,
              passFileName(
                page: 'grow',
                device: passPhone,
                mode: mode,
                scale: 1,
                frame: '${scrolled ? 'back-scrolled' : 'back'}-t$percent',
                state: 'free',
              ),
              errors,
            );
          }
          await tester.pump(const Duration(seconds: 1));
          if (!scrolled) {
            // Open it again for the second round.
            await _tapCard(tester, PassId.sound);
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            await _real(tester);
            await tester.pump(const Duration(seconds: 1));
          }
        }
      });
    });
  }

  // Scroll: the header at rest, half way through its collapse and collapsed,
  // on both phones and both text scales.
  forEachPassScroll((device, mode, scale, at) {
    _shot(
      part: 'scroll',
      state: 'free',
      setup: const _Setup(pack: 'not_downloaded'),
      device: device,
      mode: mode,
      scale: scale,
      frame: at.frame,
      act: (tester, run) =>
          scrollPassPage(tester, at, device: device, scale: scale),
    );
  });
}
