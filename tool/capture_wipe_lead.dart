// Captures the Wipe paywall opened on a history lead, with the words for a
// plan that has ended. Off the device, with the mock API and made-up plans, no
// server.
//
//   fvm flutter test tool/capture_wipe_lead.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route (`/plans/wipe?lead=...&headline=...`) and writes a
// PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced|_t<seconds>|_<state>].png.
// The path of every file is printed. A file is named:
//   _reduced   the settled frame, motion off, no ticker
//   _t<s>      motion on, that second of the layout's clock (_t0.00 is the
//              first frame the route draws)
//   _<state>   a buy state (checking, failed), motion off
//
// Scenes:
//   wipe_ended_history_rest       an ended plan, the person's own rows on the
//                                 phone. Free side first, headline reads
//                                 "Get Hosted back".
//   wipe_ended_history_first_frame the same, the frames the route draws first
//   wipe_no_lead_rest             a Wipe with no lead and no headline: what
//                                 ships today
//   wipe_history_lead_pro_ignored a Pro Wipe with a history lead in its
//                                 location: Pro does not list history, so the
//                                 lead is dropped
//   wipe_ended_own_rows           the same rows, the history picture in time
//   wipe_ended_no_older_rows      an ended plan and nothing older than the
//                                 Free window on the phone: the made-up
//                                 picture
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=MATRIX=<part>  reduced, motion or states. Default: all.
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen (unless the state hides the button), when anything
// scrolls at the default text size, when the headline is not the one the
// scene expects, or when any text says history is deleted, gone or lost.
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

class _Scene {
  const _Scene(
    this.name,
    this.product,
    this.source, {
    this.lead,
    this.headline = PaywallHeadlineVariant.none,
    this.own,
    this.motionSeconds = const [],
  });

  final String name;
  final PaywallProduct product;
  final PaywallSource source;
  final PaywallBenefitId? lead;
  final PaywallHeadlineVariant headline;
  final HistoryOwn? own;

  /// The seconds of the layout's clock captured with motion on. Empty: the
  /// scene has no motion captures.
  final List<double> motionSeconds;

  bool get isEnded => headline == PaywallHeadlineVariant.ended;

  /// The headline this scene must show.
  String get expectedHeadline => isEnded
      ? LocaleKeys.paywall_wipe_ended_headline.tr(
          namedArgs: {'name': LocaleKeys.paywall_kit_name_hosted.tr()},
        )
      : product == PaywallProduct.hosted
      ? LocaleKeys.paywall_wipe_headline_hosted.tr()
      : LocaleKeys.paywall_wipe_headline_pro.tr();

  String get location => paywallLayoutLocation(
    PaywallLayoutId.wipe,
    product,
    source: source,
    lead: lead,
    headline: headline,
    own: own,
  );
}

/// The seconds the first-frame scene and the picture-in-time scene capture.
/// The first ones are the route's first frames, then the entrance and the
/// divider's sweep part way, then the settled stage and the history
/// picture's own turns.
const _firstFrames = [0.0, 0.05, 0.3, 0.7, 1.1];
const _pictureFrames = [1.6, 2.6, 3.6, 5.0, 7.0, 9.0];

const _scenes = <_Scene>[
  _Scene(
    'wipe_ended_history_rest',
    PaywallProduct.hosted,
    PaywallSource.planSheetEnded,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.ended,
    own: _ownRows,
  ),
  _Scene(
    'wipe_ended_history_first_frame',
    PaywallProduct.hosted,
    PaywallSource.planSheetEnded,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.ended,
    own: _ownRows,
    motionSeconds: _firstFrames,
  ),
  _Scene(
    'wipe_no_lead_rest',
    PaywallProduct.hosted,
    PaywallSource.settingsPlan,
  ),
  _Scene(
    'wipe_history_lead_pro_ignored',
    PaywallProduct.pro,
    PaywallSource.history,
    lead: PaywallBenefitId.history,
  ),
  _Scene(
    'wipe_ended_own_rows',
    PaywallProduct.hosted,
    PaywallSource.planSheetEnded,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.ended,
    own: _ownRows,
    motionSeconds: _pictureFrames,
  ),
  _Scene(
    'wipe_ended_no_older_rows',
    PaywallProduct.hosted,
    PaywallSource.planSheetEnded,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.ended,
    motionSeconds: [0.0, 1.6, 3.6, 7.0],
  ),
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

  // The headline is the one this scene expects, and no other.
  if (find.text(scene.expectedHeadline).evaluate().isEmpty) {
    problems.add('The headline "${scene.expectedHeadline}" is missing.');
  }
  final others = {
    LocaleKeys.paywall_wipe_headline_hosted.tr(),
    LocaleKeys.paywall_wipe_headline_pro.tr(),
    LocaleKeys.paywall_wipe_ended_headline.tr(
      namedArgs: {'name': LocaleKeys.paywall_kit_name_hosted.tr()},
    ),
  }..remove(scene.expectedHeadline);
  for (final other in others) {
    if (find.text(other).evaluate().isNotEmpty) {
      problems.add('The headline "$other" shows on the wrong paywall.');
    }
  }
  if (scene.isEnded && find.textContaining('!').evaluate().isNotEmpty) {
    problems.add('An exclamation mark shows on the ended paywall.');
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
  /// asked to save. [run] gets a `save` that names a file by its tail.
  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    required double scale,
    required String base,
    required bool isStill,
    required Future<void> Function(
      WidgetTester tester,
      Future<void> Function(String tail) save,
    )
    run,
    String? state,
  }) {
    final head = '${scene.name}_${phone.name}_${mode.name}_${scale}x';
    final probe = '$head$base';
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

        Future<void> save(String tail) async {
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
            '$head$tail',
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

  // The settled frame: every scene, both themes, both text sizes, the two
  // phones and the 320 wide one, motion off.
  if (matrixHas('reduced')) {
    for (final scene in _scenes) {
      for (final phone in _phones) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in [1.0, 2.0]) {
            capture(
              scene,
              phone: phone,
              mode: mode,
              scale: scale,
              base: '_reduced',
              isStill: true,
              run: (tester, save) async {
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(milliseconds: 300));
                await save('_reduced');
              },
            );
          }
        }
      }
    }
  }

  // Motion: the seconds a scene names, the tall phone at the default size
  // and the 320 wide one at 2.0, light and dark on the tall one. The first
  // frame the route draws is where a stale value or an unplaced layout
  // shows.
  if (matrixHas('motion')) {
    for (final scene in _scenes.where((s) => s.motionSeconds.isNotEmpty)) {
      for (final (phone, mode, scale) in [
        (_tall, ThemeMode.light, 1.0),
        (_tall, ThemeMode.dark, 1.0),
        (_narrow, ThemeMode.light, 2.0),
      ]) {
        capture(
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
          base: '_t',
          isStill: false,
          run: (tester, save) async {
            var now = 0.0;
            for (final second in scene.motionSeconds) {
              if (second > now) await _step(tester, second - now);
              now = second;
              await save('_t${second.toStringAsFixed(2)}');
            }
          },
        );
      }
    }
  }

  // The buy block while the price loads and after a failed purchase, for the
  // layout this change touches: the ended Wipe. Motion off, light, every
  // phone, both text sizes.
  if (matrixHas('states')) {
    for (final scene in _scenes.where(
      (s) =>
          s.name == 'wipe_ended_history_rest' || s.name == 'wipe_no_lead_rest',
    )) {
      for (final state in ['checking', 'failed']) {
        for (final phone in _phones) {
          for (final scale in [1.0, 2.0]) {
            capture(
              scene,
              phone: phone,
              mode: ThemeMode.light,
              scale: scale,
              base: '_$state',
              isStill: true,
              state: state,
              run: (tester, save) async {
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(milliseconds: 300));
                await save('_$state');
              },
            );
          }
        }
      }
    }
  }
}
