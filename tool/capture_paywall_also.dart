// Captures the Sheet and Proof paywalls with a lead, where the other benefits
// sit under an "Also included" label. Off the device, with the mock API and
// made-up plans, no server.
//
//   fvm flutter test tool/capture_paywall_also.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route (`/plans/<layout>?lead=...`) and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced|_<part>].png. The path of every
// file is printed. A file is named:
//   _reduced        the settled frame, motion off, no ticker
//   _t<seconds>     motion on, that second of the layout's clock
//   _tap<n>_t<s>    a tap on benefit line n (counting from the lead as 0),
//                   then that second after the tap
//   _<state>        a buy state (loading, checking, failed), motion off
//
// Scenes:
//   sheet_widgets_hosted_lead   Hosted Sheet asked to lead with widgets. Hosted
//                               does not list widgets, so the lead is dropped
//                               and it must look like sheet_no_lead.
//   sheet_topics_lead           Hosted Sheet, the critical limit
//   sheet_pro_widgets_lead      Pro Sheet leading with widgets
//   sheet_history_lead          Hosted Sheet leading with history
//   proof_history_lead          Hosted Proof leading with history
//   proof_weekly_check_lead     Hosted Proof leading with the weekly check
//   sheet_no_lead               the Sheet pinned from the Settings plan row
//   proof_no_lead               Proof with no lead
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=BENEFITS=all   list every benefit, built or not (default
//                                built, as a store build lists them)
//   --dart-define=MATRIX=<part>  reduced (the settled frames), motion (the
//                                frames in time and the taps) or states.
//                                Default: all three.
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen (unless the state hides the button), when anything
// scrolls at the default text size, or when the label or a benefit line lies
// over another.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
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
const _benefits = String.fromEnvironment('BENEFITS', defaultValue: 'built');
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

class _Scene {
  const _Scene(
    this.name,
    this.layout,
    this.product,
    this.source, {
    this.lead,
    this.hasStates = false,
  });

  final String name;
  final PaywallLayoutId layout;
  final PaywallProduct product;
  final PaywallSource source;
  final PaywallBenefitId? lead;

  /// Also captured while the price loads, while the purchase is confirmed
  /// and after a failure.
  final bool hasStates;

  bool get isSheet => layout == PaywallLayoutId.sheet;

  /// What the route lists for this scene, lead first.
  PaywallOffer get offer => PaywallOffer.from(
    product: product,
    // A define decides it, so the default is not redundant.
    // ignore: avoid_redundant_argument_values
    showsUnbuilt: _benefits == paywallAllBenefits,
    lead: lead == null ? null : PaywallLead(benefit: lead!),
  );

  /// The loop the layout plays for [offer], as the layout builds it.
  HeroLoop get loop {
    final previews = [for (final b in offer.benefits) b.previewId];
    return isSheet
        ? HeroLoop(
            previews,
            prelude: SheetMotion.preludeFor(followsIntro: false),
          )
        : proofLoopFor(previews);
  }

  /// True when the paywall draws the "Also included" label.
  bool get showsAlso => heroShowsAlsoIncluded(
    hasLead: offer.lead != null,
    benefitCount: offer.benefits.length,
  );

  String get location => Uri.parse(
    paywallLayoutLocation(layout, product, source: source, lead: lead),
  ).toString();
}

const _scenes = <_Scene>[
  _Scene(
    'sheet_widgets_hosted_lead',
    PaywallLayoutId.sheet,
    PaywallProduct.hosted,
    PaywallSource.homeWidgets,
    lead: PaywallBenefitId.widgets,
  ),
  _Scene(
    'sheet_topics_lead',
    PaywallLayoutId.sheet,
    PaywallProduct.hosted,
    PaywallSource.createTopicCard,
    lead: PaywallBenefitId.topics,
    hasStates: true,
  ),
  _Scene(
    'sheet_pro_widgets_lead',
    PaywallLayoutId.sheet,
    PaywallProduct.pro,
    PaywallSource.homeWidgets,
    lead: PaywallBenefitId.widgets,
  ),
  _Scene(
    'sheet_history_lead',
    PaywallLayoutId.sheet,
    PaywallProduct.hosted,
    PaywallSource.historyOlder,
    lead: PaywallBenefitId.history,
  ),
  _Scene(
    'proof_history_lead',
    PaywallLayoutId.proof,
    PaywallProduct.hosted,
    PaywallSource.historyOlder,
    lead: PaywallBenefitId.history,
    hasStates: true,
  ),
  _Scene(
    'proof_weekly_check_lead',
    PaywallLayoutId.proof,
    PaywallProduct.hosted,
    PaywallSource.reliability,
    lead: PaywallBenefitId.reliabilityChecks,
  ),
  _Scene(
    'sheet_no_lead',
    PaywallLayoutId.sheet,
    PaywallProduct.hosted,
    PaywallSource.settingsPlan,
    hasStates: true,
  ),
  _Scene(
    'proof_no_lead',
    PaywallLayoutId.proof,
    PaywallProduct.hosted,
    PaywallSource.settingsPlan,
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

  // The label and the lines are one column: none lies over another.
  final label = find.text(LocaleKeys.paywall_also_label.tr().toUpperCase());
  final hasLabel = label.evaluate().isNotEmpty;
  if (scene.showsAlso && !hasLabel) {
    problems.add('The "Also included" label is missing.');
  }
  if (!scene.showsAlso && hasLabel) {
    problems.add('The "Also included" label shows with no lead.');
  }
  final rects = <String, Rect>{
    if (hasLabel) 'label': tester.getRect(label.first),
  };
  for (final (i, benefit) in scene.offer.benefits.indexed) {
    final text = find.text(heroLineFor(benefit));
    if (text.evaluate().isNotEmpty) {
      rects['line $i'] = tester.getRect(text.first);
    }
  }
  final names = rects.keys.toList();
  for (var a = 0; a < names.length; a++) {
    for (var b = a + 1; b < names.length; b++) {
      final over = rects[names[a]]!.intersect(rects[names[b]]!);
      if (over.width > 0 && over.height > 0) {
        problems.add('${names[a]} lies over ${names[b]}.');
      }
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
              'benefits': _benefits,
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

  // Motion: the first frame the route draws, the entrance part way, the end
  // of it, the lead's turn, a change of turn part way, and a tap on a line.
  // The tall phone at the default size, and the 320 wide one at 2.0.
  if (matrixHas('motion')) {
    for (final scene in _scenes) {
      for (final (phone, mode, scale) in [
        (_tall, ThemeMode.light, 1.0),
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
            final loop = scene.loop;
            final end = loop.entranceEnd;
            final change = scene.loop.scenes.length > 1
                ? end + loop.scenes[1].start
                : end + 4;
            var now = 0.0;
            Future<void> at(double second) async {
              if (second > now) await _step(tester, second - now);
              now = second;
              await save('_t${second.toStringAsFixed(2)}');
            }

            // The first frame the route draws, then two frames on.
            await save('_t0.00');
            await at(0.05);
            // Part way through the entrance, and its end.
            await at(end * 0.55);
            await at(end + 0.1);
            // Part way through the change from the lead to the next benefit.
            await at(change - 0.1);
            await at(change + 0.2);
            await at(change + 0.7);
          },
        );
        if (scene.offer.benefits.length > 1) {
          capture(
            scene,
            phone: phone,
            mode: mode,
            scale: scale,
            base: '_tap',
            isStill: false,
            run: (tester, save) async {
              final end = scene.loop.entranceEnd;
              await _step(tester, end + 0.3);
              final benefits = scene.offer.benefits;
              // The second benefit's line, and the last one's.
              for (final index in {1, benefits.length - 1}) {
                final line = find.text(heroLineFor(benefits[index]));
                await tester.tap(line.first);
                await tester.pump();
                await _step(tester, 0.25);
                await save('_tap${index}_t0.25');
                await _step(tester, 0.75);
                await save('_tap${index}_t1.00');
              }
            },
          );
        }
      }
    }
  }

  // The buy block while the price loads, while the purchase is confirmed and
  // after a failure. Motion off, light, every phone, both text sizes.
  if (matrixHas('states')) {
    for (final scene in _scenes.where((s) => s.hasStates)) {
      for (final state in ['loading', 'checking', 'failed']) {
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
