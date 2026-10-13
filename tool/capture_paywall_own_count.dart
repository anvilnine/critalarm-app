// Captures the Sheet when it opens from the critical topic limit and carries
// the person's own count and the topic they were making. Off the device, with
// the mock API and made-up plans, no server.
//
//   fvm flutter test tool/capture_paywall_own_count.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route (`/plans/sheet?lead=topics&used=..`) and writes a
// PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced|_t<seconds>|_<state>].png.
// The path of every file is printed, with the headline and the tag the frame
// drew. A file is named:
//   _reduced        the settled frame, motion off, no ticker
//   _t<seconds>     motion on, that second of the route's clock. For a scene
//                   with a loop second (`_loop<u>`) the file names the second
//                   of the topics picture's own loop, not of the clock.
//   _<state>        a buy state (loading, checking, failed), motion off
//
// Scenes:
//   sheet_topics_own_count_rest      2 of 2 used, the topic billing-api
//   sheet_topics_own_count_refused   the same, 1.9 s into the picture's loop:
//                                    the switch has been refused, the count
//                                    is still the one that shows
//   sheet_topics_own_count_lifted    the same, 3.2 s in: the switch is on
//   sheet_topics_one_of_two          1 of 2 used
//   sheet_topics_no_name             the count and no topic name
//   sheet_topics_long_name           a name over 16 characters, cut in the
//                                    middle in the headline
//   sheet_topics_very_long_name      a 64 character name
//   sheet_topics_junk_facts          junk in the location: no tag, no name
//   sheet_topics_with_false_alarm_intro_handover
//                                    the false alarm intro, then the Sheet
//                                    with the facts, around the hand over
//   sheet_topics_name_<n>            names of 3, 12, 16, 17 and 40 characters
//   sheet_topics_name_emoji          a name with an emoji: the location
//                                    cannot hold it, so it is left out
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//   --dart-define=MATRIX=<part>  reduced (the settled frames), motion (the
//                                frames in time) or states. Default: all.
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen (unless the state hides the button), when anything
// scrolls at the default text size, when the tag lies over the close cross,
// when the tag shows with no count or is missing with one, when neither
// headline of the topics lead is on screen, or when the label or a benefit
// line lies over another.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_tag.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_headline_rules.dart';
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
    this.facts, {
    this.loopSecond,
    this.hasIntro = false,
    this.hasStates = false,
    this.isExtra = false,
  });

  final String name;

  /// What goes in the location, as written. Junk goes in as junk.
  final Map<String, String> facts;

  /// A moment of the topics picture's own loop. The scene is then captured
  /// at that moment only, with motion on.
  final double? loopSecond;

  /// The false alarm intro plays first.
  final bool hasIntro;

  /// Also captured while the price loads, while the purchase is confirmed
  /// and after a failure.
  final bool hasStates;

  /// A name-length scene: the tall and the 320 wide phone, light only.
  final bool isExtra;

  /// What the paywall reads from [facts].
  PaywallLeadFacts get read => PaywallLeadFacts.fromQuery(facts);

  /// True when the paywall should draw the tag: both numbers came through.
  bool get hasTag => read.used != null && read.limit != null;

  PaywallOffer get offer => PaywallOffer.from(
    product: PaywallProduct.hosted,
    lead: const PaywallLead(benefit: PaywallBenefitId.topics),
  );

  /// The loop the Sheet plays, as the layout builds it.
  HeroLoop loop({required bool followsIntro}) => HeroLoop(
    [for (final b in offer.benefits) b.previewId],
    prelude: SheetMotion.preludeFor(followsIntro: followsIntro),
  );

  /// The clock second at which the topics picture is [u] seconds into its
  /// own loop. The picture starts its part `lead` seconds before the
  /// entrance ends, and its loop begins at the reset.
  double clockFor(double u, {required bool followsIntro}) {
    final loop = this.loop(followsIntro: followsIntro);
    final lead = loop.scenes.first.script.lead;
    return loop.entranceEnd - lead + u - TopicsPreviewTimes.reset;
  }

  /// The headlines the topics lead may show: the named one when the name
  /// reached the paywall, and the plain one.
  List<String> get headlines {
    final name = read.topicName;
    return [
      if (name != null)
        LocaleKeys.paywall_own_count_headline_named.tr(
          namedArgs: {'name': middleEllipsis(name)},
        ),
      LocaleKeys.paywall_own_count_headline_generic.tr(),
    ];
  }

  String get location {
    final base = paywallLayoutLocation(
      PaywallLayoutId.sheet,
      PaywallProduct.hosted,
      source: PaywallSource.createTopicCard,
      lead: PaywallBenefitId.topics,
      intro: hasIntro ? PaywallIntroId.falseAlarm : PaywallIntroId.none,
    );
    final uri = Uri.parse(base);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...facts})
        .toString();
  }
}

const _rest = {'used': '2', 'limit': '2', 'topic': 'billing-api'};

const _scenes = <_Scene>[
  _Scene('sheet_topics_own_count_rest', _rest, hasStates: true),
  _Scene('sheet_topics_own_count_refused', _rest, loopSecond: 1.9),
  _Scene('sheet_topics_own_count_lifted', _rest, loopSecond: 3.2),
  _Scene('sheet_topics_one_of_two', {
    'used': '1',
    'limit': '2',
    'topic': 'billing-api',
  }),
  _Scene('sheet_topics_no_name', {'used': '2', 'limit': '2'}, hasStates: true),
  _Scene('sheet_topics_long_name', {
    'used': '2',
    'limit': '2',
    'topic': 'nightly-database-backup-eu-west',
  }),
  _Scene('sheet_topics_very_long_name', {
    'used': '2',
    'limit': '2',
    'topic': 'production-database-nightly-backup-eu-west-region-one-primary-01',
  }),
  _Scene('sheet_topics_junk_facts', {
    'used': 'x',
    'limit': '-1',
    'topic': 'a b',
  }),
  _Scene(
    'sheet_topics_with_false_alarm_intro_handover',
    _rest,
    hasIntro: true,
  ),
  _Scene('sheet_topics_name_3', {
    'used': '2',
    'limit': '2',
    'topic': 'api',
  }, isExtra: true),
  _Scene('sheet_topics_name_12', {
    'used': '2',
    'limit': '2',
    'topic': 'prod-db-main',
  }, isExtra: true),
  _Scene('sheet_topics_name_16', {
    'used': '2',
    'limit': '2',
    'topic': 'nightly-backup-1',
  }, isExtra: true),
  _Scene('sheet_topics_name_17', {
    'used': '2',
    'limit': '2',
    'topic': 'nightly-backup-12',
  }, isExtra: true),
  _Scene('sheet_topics_name_40', {
    'used': '2',
    'limit': '2',
    'topic': 'nightly-database-backup-eu-west-region-1',
  }, isExtra: true),
  _Scene('sheet_topics_name_emoji', {
    'used': '2',
    'limit': '2',
    'topic': 'bell \u{1F514}',
  }, isExtra: true),
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

  // The tag: there with both numbers and only then, clear of the cross.
  final tag = find.byType(ProofTag);
  final hasTag = tag.evaluate().isNotEmpty;
  // The picture is drawn at the large class or not at all on most phones.
  // A smaller one leaves the tag out.
  final picture = find.byType(TopicsPreview);
  final wantsTag =
      scene.hasTag &&
      picture.evaluate().isNotEmpty &&
      tester.getSize(picture.first).shortestSide >= topicsTagMinEdge;
  if (wantsTag && !hasTag) problems.add('The tag is missing.');
  if (!wantsTag && hasTag) problems.add('The tag shows when it should not.');
  if (hasTag && find.byType(AppDismissCross).evaluate().isNotEmpty) {
    final cross = tester.getRect(find.byType(AppDismissCross).first);
    final over = tester.getRect(tag.first).intersect(cross);
    if (over.width > 0 && over.height > 0) {
      problems.add('The tag lies over the close cross.');
    }
    final gap = cross.left - tester.getRect(tag.first).right;
    if (gap >= 0 && gap < 4) problems.add('The tag touches the close cross.');
  }

  // One of the topics headlines is on screen, and never the tapped card's
  // own words.
  final shown = [
    for (final text in scene.headlines)
      if (find.text(text).evaluate().isNotEmpty) text,
  ];
  if (shown.length != 1) {
    problems.add('Headlines on screen: ${shown.length}, wanted one.');
  }

  // The label and the lines are one column: none lies over another.
  final label = find.text(LocaleKeys.paywall_also_label.tr().toUpperCase());
  final hasLabel = label.evaluate().isNotEmpty;
  if (!hasLabel) problems.add('The "Also included" label is missing.');
  final rects = <String, Rect>{
    if (hasLabel) 'label': tester.getRect(label.first),
  };
  for (final (i, benefit) in scene.offer.benefits.indexed) {
    final text = find.text(heroLineFor(benefit));
    if (text.evaluate().isNotEmpty) {
      rects['line $i'] = tester.getRect(text.first);
    }
  }
  // The lead's own check line is not drawn under a lead: the picture, the
  // tag and the headline say it.
  if (find
      .text(heroLineFor(scene.offer.benefits.first))
      .evaluate()
      .isNotEmpty) {
    problems.add('The lead has a check line of its own.');
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

/// What the frame on screen says, for the log: the headline and the tag.
String _says(WidgetTester tester, _Scene scene) {
  final headline = [
    for (final text in scene.headlines)
      if (find.text(text).evaluate().isNotEmpty) '"$text"',
  ].join(' ');
  final picture = find.byType(TopicsPreview);
  final drawn = picture.evaluate().isEmpty
      ? 'no picture'
      : 'picture ${tester.getSize(picture.first).shortestSide.round()}';
  final tags = find.byType(ProofTag).evaluate().isEmpty ? 'no tag' : 'tag';
  return 'headline $headline, $drawn, $tags';
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
      Future<void> Function(String tail, {bool check}) save,
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
              'benefits': 'built',
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

        Future<void> save(String tail, {bool check = true}) async {
          final found = check
              ? _problems(
                  tester,
                  scene,
                  screen: phone.size,
                  scale: scale,
                  hidesButton: state != null,
                )
              : const <String>[];
          problems.addAll([for (final p in found) '$tail: $p']);
          await _save(
            tester,
            boundaryKey,
            '$head$tail',
            isGood: found.isEmpty && errors.isEmpty,
          );
          if (check) print('     ${_says(tester, scene)}');
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

  List<_Phone> phonesOf(_Scene scene) =>
      scene.isExtra ? [_tall, _narrow] : _phones;
  List<ThemeMode> modesOf(_Scene scene) =>
      scene.isExtra ? [ThemeMode.light] : [ThemeMode.light, ThemeMode.dark];

  // The settled frame: every scene, both themes, both text sizes, the two
  // phones and the 320 wide one, motion off. A scene that is a moment of the
  // loop has no settled frame of its own.
  if (matrixHas('reduced')) {
    for (final scene in _scenes.where((s) => s.loopSecond == null)) {
      for (final phone in phonesOf(scene)) {
        for (final mode in modesOf(scene)) {
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

  if (matrixHas('motion')) {
    // A moment of the loop: the refusal, the switch on. Every phone, both
    // themes, both text sizes.
    for (final scene in _scenes.where((s) => s.loopSecond != null)) {
      for (final phone in _phones) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in [1.0, 2.0]) {
            capture(
              scene,
              phone: phone,
              mode: mode,
              scale: scale,
              base: '_t',
              isStill: false,
              run: (tester, save) async {
                final to = scene.clockFor(
                  scene.loopSecond!,
                  followsIntro: false,
                );
                await _step(tester, to);
                await save('_t${to.toStringAsFixed(2)}');
              },
            );
          }
        }
      }
    }

    // The settled scene in time: the first frame the route draws, the
    // entrance part way, and each change of the loop.
    final rest = _scenes.first;
    for (final (phone, mode, scale) in [
      (_tall, ThemeMode.light, 1.0),
      (_short, ThemeMode.dark, 1.0),
      (_narrow, ThemeMode.light, 2.0),
    ]) {
      capture(
        rest,
        phone: phone,
        mode: mode,
        scale: scale,
        base: '_t',
        isStill: false,
        run: (tester, save) async {
          final loop = rest.loop(followsIntro: false);
          var now = 0.0;
          Future<void> at(double second) async {
            if (second > now) await _step(tester, second - now);
            now = second;
            await save('_t${second.toStringAsFixed(2)}');
          }

          // The first frame the route draws, then two frames on.
          await save('_t0.00');
          await at(0.05);
          await at(loop.entranceEnd * 0.55);
          await at(loop.entranceEnd + 0.1);
          // The picture's loop: reset, off, refusing, refused, turning on,
          // on, in the loop's own seconds.
          for (final u in [0.7, 1.0, 1.5, 2.0, 2.6, 3.0]) {
            await at(rest.clockFor(u, followsIntro: false));
          }
        },
      );
    }

    // The false alarm intro, then the Sheet with the facts. The route's
    // first frame, the intro, the hand over and the Sheet coming in.
    for (final scene in _scenes.where((s) => s.hasIntro)) {
      for (final (phone, mode, scale) in [
        (_tall, ThemeMode.light, 1.0),
        (_narrow, ThemeMode.dark, 2.0),
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
            Future<void> at(double second, {bool check = false}) async {
              if (second > now) await _step(tester, second - now);
              now = second;
              await save('_t${second.toStringAsFixed(2)}', check: check);
            }

            await save('_t0.00', check: false);
            await at(0.05);
            await at(FalseAlarmTimeline.admit);
            await at(FalseAlarmTimeline.reveal);
            await at(FalseAlarmTimeline.handover);
            await at(FalseAlarmTimeline.handover + 0.15);
            await at(FalseAlarmTimeline.end);
            await at(FalseAlarmTimeline.handover + 0.8);
            await at(FalseAlarmTimeline.handover + 1.6, check: true);
            // The loop's refusal, so the tag is seen on the Sheet that came
            // in under the intro.
            await at(
              FalseAlarmTimeline.handover +
                  scene.clockFor(1.9, followsIntro: true),
            );
          },
        );
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
