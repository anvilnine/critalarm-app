// Captures the Wipe paywall run backwards, for a Hosted plan that is ending.
// Off the device, with the mock API and made-up plans, no server.
//
//   fvm flutter test tool/capture_leaving_wipe.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route (`/plans/wipe?...&headline=leaving&ends=...`) and
// writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced|_t<seconds>|_<state>|_<stop>].png.
// The path of every file is printed. A file is named:
//   _reduced   the settled frame, motion off, no ticker
//   _t<s>      motion on, that second of the layout's clock (_t0.00 is the
//              first frame the route draws)
//   _<state>   a buy state (checking, failed), motion off
//   _<stop>    the divider dragged to a stop (left, right, middle) after rest
//
// Scenes:
//   wipe_leaving_first_frame        t 0.1: all colour, Crit sad
//   wipe_leaving_sweep_mid          t 0.85: the grey part way across
//   wipe_leaving_all_grey           t 1.4: the grey over the whole stage
//   wipe_leaving_pull_back          t 1.8: the grey pulling back
//   wipe_leaving_rest               t 3.0: rested on Crit, motion on
//   wipe_leaving_at_rest            opened again for the same end date: the
//                                   route draws at rest from the first frame
//   wipe_leaving_rest_reduced_motion the settled frame, reduce motion
//   wipe_leaving_topics_lead        under a week of history held: the
//                                   critical topics picture
//   wipe_leaving_own_rows           the person's own rows, in time
//   wipe_leaving_scale2             the settled frame at text scale 2.0
//   wipe_leaving_grip_drag          the divider dragged to each stop
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=MATRIX=<part>  reduced, motion, drag or states. Default: all.
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen (unless the state hides the button), when anything
// scrolls at the default text size, when the headline or the button is not
// the leaving one, when the list carries a check mark, or when any text says
// history is deleted, gone or lost.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');
const _matrix = String.fromEnvironment('MATRIX');

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _tall = _Phone('390x844', Size(390, 844), 47, 34);
const _short = _Phone('375x667', Size(375, 667), 20, 0);
const _narrow = _Phone('320x568', Size(320, 568), 20, 0);
const List<_Phone> _phones = [_tall, _short, _narrow];

/// The rows a person with older alarms on the phone has: a few inside the
/// Free window and a few past it.
const _ownRows = HistoryOwn(
  inside: [
    HistoryOwnRow('prod-db', 1),
    HistoryOwnRow('nas', 4),
  ],
  beyond: [
    HistoryOwnRow('nas', 9),
    HistoryOwnRow('prod-db', 30),
    HistoryOwnRow('nas', 55),
    HistoryOwnRow('prod-db', 80),
  ],
);

/// A person whose numbers are thin (so the leaving paywall is a Wipe) and
/// who holds a few weeks of history.
const _thin = LeavingFacts(
  rang: 4,
  answered: 2,
  nights: 0,
  criticalTopics: 4,
  historyDaysHeld: 40,
);

/// The same, with under a week of history on the phone.
const _young = LeavingFacts(
  rang: 2,
  answered: 2,
  nights: 0,
  criticalTopics: 3,
  historyDaysHeld: 3,
);

/// The plan ends on 20 October, so the grey side reads 21 Oct.
final _endsOn = DateTime(2026, 10, 20);

class _Frame {
  const _Frame(this.name, this.seconds);

  /// The scene name this frame saves under.
  final String name;
  final double seconds;
}

class _Scene {
  const _Scene(
    this.name, {
    this.facts = _thin,
    this.lead = PaywallBenefitId.history,
    this.own,
    this.atRest = false,
    this.frames = const [],
    this.scales = const [1.0, 2.0],
  });

  final String name;
  final LeavingFacts facts;
  final PaywallBenefitId lead;
  final HistoryOwn? own;

  /// The route says the opening was shown for this end date already.
  final bool atRest;

  /// The frames captured with motion on.
  final List<_Frame> frames;

  /// The text sizes the settled frame is captured at.
  final List<double> scales;

  String get location => paywallLayoutLocation(
    PaywallLayoutId.wipe,
    PaywallProduct.hosted,
    source: PaywallSource.planSheetEnding,
    lead: lead,
    headline: PaywallHeadlineVariant.leaving,
    own: own,
    leaving: PaywallLeaving(endsOn: _endsOn, atRest: atRest, facts: facts),
  );

  /// The headline every frame of this scene must show.
  String get expectedHeadline => LocaleKeys.paywall_leaving_wipe_headline.tr(
    namedArgs: {
      'date': DateFormat('d MMM').format(DateTime(2026, 10, 21)),
      'name': LocaleKeys.paywall_kit_name_hosted.tr(),
    },
  );
}

const _arrival = [
  _Frame('wipe_leaving_first_frame', 0.1),
  _Frame('wipe_leaving_sweep_mid', 0.85),
  _Frame('wipe_leaving_all_grey', 1.4),
  _Frame('wipe_leaving_pull_back', 1.8),
  _Frame('wipe_leaving_rest', 3),
];

const _scenes = <_Scene>[
  // The arrival frames, and the first one the route draws.
  _Scene(
    'wipe_leaving_arrival',
    own: _ownRows,
    frames: _arrival,
    scales: [],
  ),
  _Scene(
    'wipe_leaving_route_opens',
    own: _ownRows,
    frames: [_Frame('wipe_leaving_route_opens', 0)],
    scales: [],
  ),
  _Scene('wipe_leaving_at_rest', own: _ownRows, atRest: true),
  _Scene(
    'wipe_leaving_rest_reduced_motion',
    own: _ownRows,
    scales: [1.0],
  ),
  _Scene('wipe_leaving_scale2', own: _ownRows, scales: [2.0]),
  _Scene(
    'wipe_leaving_topics_lead',
    facts: _young,
    lead: PaywallBenefitId.topics,
    frames: [
      _Frame('wipe_leaving_topics_lead_first', 0.1),
      _Frame('wipe_leaving_topics_lead_grey', 1.4),
      _Frame('wipe_leaving_topics_lead', 3),
    ],
  ),
  _Scene(
    'wipe_leaving_own_rows',
    own: _ownRows,
    frames: [
      _Frame('wipe_leaving_own_rows_t3', 3),
      _Frame('wipe_leaving_own_rows_t5', 5),
      _Frame('wipe_leaving_own_rows_t9', 9),
    ],
  ),
  // The made-up rows: the phone holds a few weeks, none past the window.
  _Scene('wipe_leaving_made_up_rows', scales: [1.0]),
];

const _frame = Duration(milliseconds: 16);

/// Runs the clock [seconds] on, a frame at a time. One long pump would draw
/// an implicit animation that starts on the last frame at its first value.
Future<void> _step(WidgetTester tester, double seconds) async {
  final end = Duration(microseconds: (seconds * 1e6).round());
  var at = Duration.zero;
  while (at < end) {
    final step = end - at < _frame ? end - at : _frame;
    await tester.pump(step);
    at += step;
  }
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name, {
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
});

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

/// Words no frame of this paywall may carry: the phone keeps its old rows
/// and hides them.
const _forbidden = ['deleted', 'gone', 'lost', 'erased', 'removed'];

/// What is wrong with the words and the controls on the frame on screen.
List<String> _problems(
  WidgetTester tester,
  _Scene scene, {
  required Size screen,
  required double scale,
  required bool hidesButton,
}) {
  final problems = <String>[];
  final box = Offset.zero & screen;
  bool onScreen(Finder finder) =>
      finder.evaluate().isNotEmpty &&
      box.contains(tester.getRect(finder.first).topLeft) &&
      box.contains(tester.getRect(finder.first).bottomRight);

  if (!onScreen(find.byType(AppDismissCross))) {
    problems.add('The close cross is not on screen.');
  }
  if (!hidesButton && !onScreen(find.byType(AppButton))) {
    problems.add('The button is not on screen.');
  }
  if (scale == 1.0) {
    for (final s in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    )) {
      if (s.position.maxScrollExtent > 0.5) {
        problems.add(
          'Something scrolls at the default text size, by '
          '${s.position.maxScrollExtent.toStringAsFixed(1)} points.',
        );
      }
    }
  }

  // The headline is the leaving one, and no other.
  if (find.text(scene.expectedHeadline).evaluate().isEmpty) {
    problems.add('The headline "${scene.expectedHeadline}" is missing.');
  }
  for (final other in {
    LocaleKeys.paywall_wipe_headline_hosted.tr(),
    LocaleKeys.paywall_wipe_headline_pro.tr(),
    LocaleKeys.paywall_wipe_ended_headline.tr(
      namedArgs: {'name': LocaleKeys.paywall_kit_name_hosted.tr()},
    ),
  }) {
    if (find.text(other).evaluate().isNotEmpty) {
      problems.add('The headline "$other" shows on the leaving paywall.');
    }
  }
  // The button is the leaving one.
  final keep = LocaleKeys.paywall_leaving_button.tr(
    namedArgs: {'name': LocaleKeys.paywall_kit_name_hosted.tr()},
  );
  if (!hidesButton && find.text(keep).evaluate().isEmpty) {
    problems.add('The button does not read "$keep".');
  }
  // The sides are named by date, and the list has no check mark.
  final free = LocaleKeys.paywall_wipe_tag_free.tr();
  if (find.text(free).evaluate().isNotEmpty) {
    problems.add('"$free" shows on the leaving Wipe.');
  }
  if (find.byIcon(Icons.check).evaluate().isNotEmpty) {
    problems.add('A check mark shows on the leaving Wipe.');
  }
  for (final word in _forbidden) {
    final found = find.textContaining(RegExp(word, caseSensitive: false));
    if (found.evaluate().isNotEmpty) {
      problems.add('A text says "$word".');
    }
  }
  return problems;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // `test/flutter_test_config.dart` only runs for files under test/, so
    // this tool loads the strings itself or every label renders as its key.
    await loadTestTranslations();
    await configureDependencies();
    await loadAppFonts();
  });

  /// Opens [scene]'s route and runs [run] on it, then saves what [run]
  /// asked to save. [run] gets a `save` that names a file by its scene and
  /// its tail.
  void capture(
    _Scene scene, {
    required String name,
    required _Phone phone,
    required ThemeMode mode,
    required double scale,
    required String base,
    required bool isStill,
    required Future<void> Function(
      WidgetTester tester,
      Future<void> Function(String name, String tail) save,
    )
    run,
    String? state,
  }) {
    final probe = '${name}_${phone.name}_${mode.name}_${scale}x$base';
    if (!_wanted(probe)) return;
    testWidgets('capture $probe', (tester) async {
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

      final location = Uri.parse(scene.location)
          .replace(
            queryParameters: {
              ...Uri.parse(scene.location).queryParameters,
              'state': ?state,
            },
          )
          .toString();
      final boundaryKey = GlobalKey();
      final problems = <String>[];

      // A test paints every shadow as a solid shape unless told otherwise.
      // A capture is looked at, so it draws them as a phone does.
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(
          BlocProvider<ThemeCubit>.value(
            value: getIt<ThemeCubit>(),
            child: MaterialApp.router(
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              routerConfig: buildRouter(initialLocation: location),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: isStill,
                ),
                child: RepaintBoundary(key: boundaryKey, child: child),
              ),
            ),
          ),
        );
        await tester.pump();

        Future<void> save(String fileScene, String tail) async {
          final found = _problems(
            tester,
            scene,
            screen: phone.size,
            scale: scale,
            hidesButton: state != null,
          );
          problems.addAll([for (final p in found) '$tail: $p']);
          await _save(
            tester,
            boundaryKey,
            '${fileScene}_${phone.name}_${mode.name}_${scale}x$tail',
            isGood: found.isEmpty && errors.isEmpty,
          );
        }

        await run(tester, save);
        // A cue's haptic is a short pattern on a timer. Take the tree down
        // and let it end, or the test fails at teardown on a pending timer.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(errors, isEmpty, reason: errors.join('\n'));
        expect(problems, isEmpty, reason: problems.join('\n'));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  bool matrixHas(String part) => _matrix.isEmpty || _matrix == part;

  // The settled frame: every scene that has one, both themes, the text sizes
  // it names, the two phones and the 320 wide one, motion off. The scene
  // that opens at rest has motion on in the media query: the route itself
  // holds still.
  if (matrixHas('reduced')) {
    for (final scene in _scenes.where((s) => s.scales.isNotEmpty)) {
      for (final phone in _phones) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in scene.scales) {
            capture(
              scene,
              name: scene.name,
              phone: phone,
              mode: mode,
              scale: scale,
              base: scene.atRest ? '' : '_reduced',
              isStill: !scene.atRest,
              run: (tester, save) async {
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(milliseconds: 300));
                await save(scene.name, scene.atRest ? '' : '_reduced');
              },
            );
          }
        }
      }
    }
  }

  // Motion: the seconds a scene names, the tall phone at the default size in
  // both themes, the short one, and the 320 wide one at 2.0. The first frame
  // the route draws is where a stale value or an unplaced layout shows.
  if (matrixHas('motion')) {
    for (final scene in _scenes.where((s) => s.frames.isNotEmpty)) {
      for (final (phone, mode, scale) in [
        (_tall, ThemeMode.light, 1.0),
        (_tall, ThemeMode.dark, 1.0),
        (_short, ThemeMode.light, 1.0),
        (_narrow, ThemeMode.dark, 1.0),
        (_narrow, ThemeMode.light, 2.0),
      ]) {
        capture(
          scene,
          name: scene.name,
          phone: phone,
          mode: mode,
          scale: scale,
          base: '_t',
          isStill: false,
          run: (tester, save) async {
            var now = 0.0;
            for (final frame in scene.frames) {
              if (frame.seconds > now) await _step(tester, frame.seconds - now);
              now = frame.seconds;
              await save(
                frame.name,
                '_t${frame.seconds.toStringAsFixed(2)}',
              );
            }
          },
        );
      }
    }
  }

  // The grip: rest, then a finger takes the divider to the left stop, to
  // the right stop and back toward the middle, a frame after each.
  if (matrixHas('drag')) {
    final scene = _scenes.firstWhere((s) => s.name == 'wipe_leaving_arrival');
    for (final (phone, mode, scale) in [
      (_tall, ThemeMode.light, 1.0),
      (_tall, ThemeMode.dark, 1.0),
      (_short, ThemeMode.light, 1.0),
      // At 320 wide and text scale 2.0 the stage has no room for a face
      // and no grip, so there is nothing to drag.
      (_narrow, ThemeMode.light, 1.0),
    ]) {
      capture(
        scene,
        name: 'wipe_leaving_grip_drag',
        phone: phone,
        mode: mode,
        scale: scale,
        base: '_drag',
        isStill: false,
        run: (tester, save) async {
          await _step(tester, 3);
          final grip = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == const Size.square(36),
          );
          Future<void> dragBy(double dx) async {
            final from = tester.getCenter(grip.first);
            final finger = await tester.startGesture(from);
            const steps = 12;
            for (var i = 1; i <= steps; i++) {
              await finger.moveTo(from + Offset(dx * i / steps, 0));
              await tester.pump(_frame);
            }
            await tester.pump(_frame);
            await finger.up();
            await tester.pump(_frame);
          }

          await dragBy(-phone.size.width);
          await save('wipe_leaving_grip_drag', '_stopLeft');
          await dragBy(phone.size.width * 2);
          await save('wipe_leaving_grip_drag', '_stopRight');
          await dragBy(-phone.size.width * 0.6);
          await save('wipe_leaving_grip_drag', '_middle');
          await _step(tester, 0.3);
        },
      );
    }
  }

  // The buy block while the price loads and after a failed purchase. Motion
  // off, light, every phone, both text sizes.
  if (matrixHas('states')) {
    final scene = _scenes.firstWhere(
      (s) => s.name == 'wipe_leaving_rest_reduced_motion',
    );
    for (final state in ['checking', 'failed']) {
      for (final phone in _phones) {
        for (final scale in [1.0, 2.0]) {
          capture(
            scene,
            name: 'wipe_leaving_$state',
            phone: phone,
            mode: ThemeMode.light,
            scale: scale,
            base: '_$state',
            isStill: true,
            state: state,
            run: (tester, save) async {
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 300));
              await save('wipe_leaving_$state', '_$state');
            },
          );
        }
      }
    }
  }
}
