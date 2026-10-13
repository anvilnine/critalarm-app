// Captures the Receipt for a plan that is ending, off the device, with the
// mock API and made-up numbers, no server.
//
//   fvm flutter test tool/capture_leaving_receipt.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route (`/plans/receipt?headline=leaving&ends=...`) and
// writes a PNG named <scene>_<phone>_<theme>_<scale>x[_reduced|_t<seconds>|
// _<state>].png. The path of every file is printed. A file is named:
//   _reduced        the settled frame, motion off, no ticker
//   _t<seconds>     motion on, that second of the layout's clock, stepped a
//                   frame at a time so an overflow on the way fails it
//   _<state>        a buy state (checking, failed), motion off
//
// Scenes, each with the numbers that make it (rang, answered, nights,
// critical topics on, days of history held):
//   receipt_leaving_first_frame        4 rows, the first frame the route draws
//   receipt_leaving_print_mid          4 rows, part way through the print
//   receipt_leaving_stamp              4 rows, the stamp landing
//   receipt_leaving_sad_rest           4 rows, the last sad frame
//   receipt_leaving_calm_rest          4 rows, after the entrance
//   receipt_leaving_at_rest            the sad opening was shown already:
//                                      motion ON, and still it draws at rest
//   receipt_leaving_two_rows           2 rows, a phone holding 30 days
//   receipt_leaving_four_rows_scale2   4 rows at text scale 2.0 (stacked)
//   receipt_leaving_one_critical       1 critical topic: the after line
//   receipt_leaving_no_critical        no critical topic: the after line
//   receipt_leaving_thirty_days        4 rows, a phone holding 30 days
//   receipt_shipped_unchanged          no leaving fields: the shipped slip
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=MATRIX=<part>  reduced, motion or states (default: all)
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen (unless the state hides the button), when anything
// scrolls at the default text size on the tall phone, and when the face or
// the stamp lies over a number or a word.
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
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_mascot.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/leaving/leaving_receipt_composition.dart';
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
const _narrow = _Phone('320x640', Size(320, 640), 24, 0);
const List<_Phone> _phones = [_tall, _short, _narrow];

/// The day the made-up plan ends.
final DateTime _ends = DateTime(2026, 11, 14);

/// Four rows, and a phone that holds the whole window.
const _four = LeavingFacts(
  rang: 142,
  answered: 139,
  nights: 9,
  criticalTopics: 4,
  historyDaysHeld: 95,
);

class _Scene {
  const _Scene(
    this.name,
    this.facts, {
    this.times = const [],
    this.hasReduced = true,
    this.atRest = false,
    this.isShipped = false,
    this.scales = const [1.0, 2.0],
    this.hasStates = false,
  });

  final String name;
  final LeavingFacts facts;

  /// The seconds of the clock captured with motion on.
  final List<double> times;

  /// Also captured settled, motion off.
  final bool hasReduced;

  /// The sad opening was shown for the end date already.
  final bool atRest;

  /// No leaving fields: the shipped slip, to see it did not change.
  final bool isShipped;
  final List<double> scales;

  /// Also captured while the purchase is checked and after it failed.
  final bool hasStates;

  LeavingSlip get slip => leavingSlipFor(facts);

  String get location => isShipped
      ? paywallLayoutLocation(
          PaywallLayoutId.receipt,
          PaywallProduct.hosted,
          source: PaywallSource.settingsPlan,
        )
      : paywallLayoutLocation(
          PaywallLayoutId.receipt,
          PaywallProduct.hosted,
          source: PaywallSource.planSheetEnding,
          headline: PaywallHeadlineVariant.leaving,
          leaving: PaywallLeaving(endsOn: _ends, atRest: atRest, facts: facts),
        );
}

const _scenes = <_Scene>[
  _Scene(
    'receipt_leaving_first_frame',
    _four,
    times: [0],
    hasReduced: false,
  ),
  _Scene(
    'receipt_leaving_print_mid',
    _four,
    times: [0.9],
    hasReduced: false,
  ),
  _Scene('receipt_leaving_stamp', _four, times: [1.6], hasReduced: false),
  _Scene('receipt_leaving_sad_rest', _four, times: [2.1], hasReduced: false),
  _Scene(
    'receipt_leaving_calm_rest',
    _four,
    times: [3.5],
    hasStates: true,
  ),
  _Scene(
    'receipt_leaving_at_rest',
    _four,
    times: [0, 0.9],
    hasReduced: false,
    atRest: true,
  ),
  _Scene(
    'receipt_leaving_two_rows',
    LeavingFacts(
      rang: 12,
      answered: 4,
      nights: 3,
      criticalTopics: 1,
      historyDaysHeld: 30,
    ),
    times: [0.9, 3.5],
    hasStates: true,
  ),
  _Scene(
    'receipt_leaving_four_rows_scale2',
    _four,
    times: [0.9, 3.5],
    scales: [2.0],
  ),
  _Scene(
    'receipt_leaving_one_critical',
    LeavingFacts(
      rang: 12,
      answered: 4,
      nights: 3,
      criticalTopics: 1,
      historyDaysHeld: 30,
    ),
  ),
  _Scene(
    'receipt_leaving_no_critical',
    LeavingFacts(
      rang: 12,
      answered: 4,
      nights: 3,
      criticalTopics: 0,
      historyDaysHeld: 30,
    ),
  ),
  _Scene(
    'receipt_leaving_thirty_days',
    LeavingFacts(
      rang: 142,
      answered: 139,
      nights: 9,
      criticalTopics: 4,
      historyDaysHeld: 30,
    ),
  ),
  _Scene(
    'receipt_shipped_unchanged',
    _four,
    isShipped: true,
    hasStates: true,
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

/// What is wrong with the words and the controls on the frame on screen.
/// [settled] is true once the entrance is over, when the face and the stamp
/// stand where they stay.
List<String> _problems(
  WidgetTester tester,
  _Scene scene, {
  required _Phone phone,
  required double scale,
  required bool hidesButton,
  required bool settled,
}) {
  final problems = <String>[];
  final box = Offset.zero & phone.size;
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
  if (scale == 1.0 && phone != _short && phone != _narrow) {
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
  if (scene.isShipped) return problems;

  // The face and the stamp lie over no number and no word.
  final stampText = LocaleKeys.paywall_leaving_receipt_stamp.tr(
    namedArgs: {'date': DateFormat('d MMM').format(_ends).toUpperCase()},
  );
  final rects = <String, Rect>{};
  void add(String name, Finder finder) {
    if (finder.evaluate().isNotEmpty) {
      rects[name] = tester.getRect(finder.first);
    }
  }

  for (final row in scene.slip.rows) {
    add('row ${row.row.name}', find.text(leavingRowLabel(row.row)));
    add('value ${row.row.name}', find.text('${row.value}'));
  }
  add('headline', find.text(LocaleKeys.paywall_leaving_receipt_headline.tr()));
  add(
    'after label',
    find.textContaining(
      LocaleKeys.paywall_leaving_receipt_after_label
          .tr(namedArgs: {'date': 'x'})
          .split(' ')
          .first
          .toUpperCase(),
    ),
  );
  final stamp = find.text(stampText);
  final mascot = find.byType(HeroMascot);
  if (settled) {
    add('stamp', stamp);
    if (mascot.evaluate().isNotEmpty) {
      // The face's square, a little inside its edge: the outline is round.
      rects['face'] = tester.getRect(mascot.first).deflate(6);
    }
  }
  final names = rects.keys.toList();
  for (var a = 0; a < names.length; a++) {
    for (var b = a + 1; b < names.length; b++) {
      final over = rects[names[a]]!.intersect(rects[names[b]]!);
      if (over.width > 1 && over.height > 1) {
        problems.add('${names[a]} lies over ${names[b]}.');
      }
    }
  }
  if (rects['stamp'] case final s?) {
    if (s.left < 0 || s.right > phone.size.width) {
      problems.add('The stamp is cut by the screen edge.');
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
      Future<void> Function(String tail, {required bool settled}) save,
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

        Future<void> save(String tail, {required bool settled}) async {
          final found = _problems(
            tester,
            scene,
            phone: phone,
            scale: scale,
            hidesButton: state != null,
            settled: settled,
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

  // The settled frame: every scene that has one, both themes, both text
  // sizes, the two phones and the 320 wide one, motion off.
  if (matrixHas('reduced')) {
    for (final scene in _scenes.where((s) => s.hasReduced)) {
      for (final phone in _phones) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in scene.scales) {
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
                await save('_reduced', settled: true);
              },
            );
          }
        }
      }
    }
  }

  // Motion: the clock stepped a frame at a time to each second asked for.
  if (matrixHas('motion')) {
    for (final scene in _scenes.where((s) => s.times.isNotEmpty)) {
      for (final phone in _phones) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in scene.scales) {
            capture(
              scene,
              phone: phone,
              mode: mode,
              scale: scale,
              base: '_t',
              isStill: false,
              run: (tester, save) async {
                var now = 0.0;
                for (final second in scene.times) {
                  if (second > now) await _step(tester, second - now);
                  now = second;
                  await save(
                    '_t${second.toStringAsFixed(2)}',
                    settled: scene.atRest || second >= 2.2,
                  );
                }
              },
            );
          }
        }
      }
    }
  }

  // The buy block while the purchase is checked and after a failure. Motion
  // off, light, every phone, both text sizes.
  if (matrixHas('states')) {
    for (final scene in _scenes.where((s) => s.hasStates)) {
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
                await save('_$state', settled: true);
              },
            );
          }
        }
      }
    }
  }
}
