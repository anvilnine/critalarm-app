// Captures the paywall places and the leaving layouts after the fixes from
// looking at them: the calm face, the Proof headline on its own beat, the
// Sheet headline for a long name, the leaving layouts' small print, the date
// tag on the leaving Wipe card, the Wipe holding on its lead picture, and
// the history band clear of the tag. Off the device, with the mock API and
// made-up plans, no server.
//
//   fvm flutter test tool/capture_review_fixes.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=<folder>
//
// It opens the real route and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced|_t<seconds>].png and prints the
// path of every file, with what the frame said (headline, tag). A file is
// named:
//   _reduced   the settled frame, motion off, no ticker
//   _t<s>      motion on, that second of the layout's clock
//
// Scenes:
//   receipt_leaving     the leaving Receipt: the calm face, no small print
//   wipe_leaving        the leaving Wipe: date tag on the card, no small
//                       print, and the same picture at 3, 9 and 14 seconds
//   proof_lead_history  the Proof layout under "See older alarms": the
//                       headline on each beat
//   proof_old_only      the person's rows are all past the Free window: the
//                       band clear of the tag
//   sheet_long_name     a 40 character topic name: the headline has no name
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows, when the close cross or the buy
// button is off screen, when anything scrolls at the default text size, when
// a text says history is deleted, gone or lost, when a leaving layout shows
// the small print about critical topics, or when a scene's own rule breaks.
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
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_plan_picker.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_tag.dart';
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

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _tall = _Phone('390x844', Size(390, 844), 47, 34);
const _narrow = _Phone('320x568', Size(320, 568), 20, 0);

/// A few rows inside the Free window and a few past it.
const _ownRows = HistoryOwn(
  inside: [HistoryOwnRow('prod-db', 1), HistoryOwnRow('nas', 4)],
  beyond: [
    HistoryOwnRow('nas', 9),
    HistoryOwnRow('prod-db', 30),
    HistoryOwnRow('nas', 55),
    HistoryOwnRow('prod-db', 80),
  ],
);

/// Nothing inside the Free window: every row is past it.
const _oldRows = HistoryOwn(
  inside: [],
  beyond: [
    HistoryOwnRow('nas-backup', 9),
    HistoryOwnRow('prod-db', 21),
    HistoryOwnRow('home-ha', 44),
    HistoryOwnRow('prod-db', 81),
  ],
);

/// Thin numbers, so the leaving paywall is a Wipe.
const _thin = LeavingFacts(
  rang: 4,
  answered: 2,
  nights: 0,
  criticalTopics: 4,
  historyDaysHeld: 40,
);

/// Four rows, so the leaving paywall is a Receipt.
const _four = LeavingFacts(
  rang: 142,
  answered: 139,
  nights: 9,
  criticalTopics: 4,
  historyDaysHeld: 95,
);

/// Thin numbers with [n] critical topics.
LeavingFacts _thinWith(int n) => LeavingFacts(
  rang: 4,
  answered: 2,
  nights: 0,
  criticalTopics: n,
  historyDaysHeld: 40,
);

final DateTime _ends = DateTime(2026, 10, 20);

/// The sentence the leaving layouts used to print under the button.
const _removedNote = 'keep ringing either way';

const _longName = 'nightly-database-backup-eu-west-region-1';

class _Scene {
  const _Scene(
    this.name,
    this.location, {
    this.times = const [],
  });

  final String name;
  final String Function() location;

  /// The seconds captured with motion on.
  final List<double> times;
}

String _leaving(PaywallLayoutId layout, LeavingFacts facts) =>
    paywallLayoutLocation(
      layout,
      PaywallProduct.hosted,
      source: PaywallSource.planSheetEnding,
      lead: PaywallBenefitId.history,
      headline: PaywallHeadlineVariant.leaving,
      own: _ownRows,
      leaving: PaywallLeaving(endsOn: _ends, facts: facts),
    );

/// The leaving layout with the critical topics as its lead picture.
String _leavingOnTopics(PaywallLayoutId layout, LeavingFacts facts) =>
    paywallLayoutLocation(
      layout,
      PaywallProduct.hosted,
      source: PaywallSource.planSheetEnding,
      lead: PaywallBenefitId.topics,
      headline: PaywallHeadlineVariant.leaving,
      leaving: PaywallLeaving(endsOn: _ends, facts: facts),
    );

String _proof(HistoryOwn? own) => paywallLayoutLocation(
  PaywallLayoutId.proof,
  PaywallProduct.hosted,
  source: PaywallSource.history,
  lead: PaywallBenefitId.history,
  own: own,
);

/// The Sheet from the critical limit: 2 of 2 used, the topic billing-api.
String _sheetCritical() =>
    Uri.parse(
          paywallLayoutLocation(
            PaywallLayoutId.sheet,
            PaywallProduct.hosted,
            source: PaywallSource.createTopicCard,
            lead: PaywallBenefitId.topics,
          ),
        )
        .replace(
          queryParameters: {
            ...Uri.parse(
              paywallLayoutLocation(
                PaywallLayoutId.sheet,
                PaywallProduct.hosted,
                source: PaywallSource.createTopicCard,
                lead: PaywallBenefitId.topics,
              ),
            ).queryParameters,
            'used': '2',
            'limit': '2',
            'topic': 'billing-api',
          },
        )
        .toString();

final _scenes = <_Scene>[
  _Scene(
    'sheet_no_lead',
    () => paywallLayoutLocation(
      PaywallLayoutId.sheet,
      PaywallProduct.hosted,
      source: PaywallSource.settingsPlan,
    ),
  ),
  const _Scene('sheet_critical_lifted', _sheetCritical, times: [3.9]),
  _Scene(
    'sheet_history',
    () => paywallLayoutLocation(
      PaywallLayoutId.sheet,
      PaywallProduct.hosted,
      source: PaywallSource.history,
      lead: PaywallBenefitId.history,
    ),
    times: const [3.9],
  ),
  _Scene(
    'receipt_leaving',
    () => _leaving(PaywallLayoutId.receipt, _four),
    times: [3.5],
  ),
  _Scene(
    'wipe_leaving',
    () => _leaving(PaywallLayoutId.wipe, _thin),
    times: [1.0, 3, 9, 14],
  ),
  for (final n in const [1, 2, 3, 7])
    _Scene(
      'wipe_leaving_topics$n',
      () => _leavingOnTopics(PaywallLayoutId.wipe, _thinWith(n)),
      times: [1.4, 3],
    ),
  _Scene(
    'proof_lead_history',
    () => _proof(_ownRows),
    times: [2.5, 5.5, 8.5, 11.5, 14.5],
  ),
  _Scene('proof_sample_rows', () => _proof(null), times: [2.0, 3.0, 8.5]),
  _Scene(
    'proof_old_only',
    () => _proof(_oldRows),
    times: [2.0, 3.0, 4.0],
  ),
  _Scene(
    'sheet_long_name',
    () =>
        Uri.parse(
              paywallLayoutLocation(
                PaywallLayoutId.sheet,
                PaywallProduct.hosted,
                source: PaywallSource.createTopicCard,
                lead: PaywallBenefitId.topics,
              ),
            )
            .replace(
              queryParameters: {
                ...Uri.parse(
                  paywallLayoutLocation(
                    PaywallLayoutId.sheet,
                    PaywallProduct.hosted,
                    source: PaywallSource.createTopicCard,
                    lead: PaywallBenefitId.topics,
                  ),
                ).queryParameters,
                'used': '2',
                'limit': '2',
                'topic': _longName,
              },
            )
            .toString(),
    times: [3.0],
  ),
];

const _frame = Duration(milliseconds: 16);

/// Runs the clock [seconds] on, a frame at a time.
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
  required String said,
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}  [$said]');
});

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

/// Words no frame may carry.
const _forbidden = ['deleted', 'gone', 'lost', 'erased', 'removed'];

/// The Proof headlines this build can show, and the one the frame has.
String _headlineOn(WidgetTester tester) {
  final all = {
    LocaleKeys.paywall_history_own_headline.tr(),
    LocaleKeys.paywall_proof_headline_hosted.tr(),
    LocaleKeys.paywall_own_count_headline_generic.tr(),
    LocaleKeys.paywall_sheet_headline_topics.tr(),
    LocaleKeys.paywall_sheet_headline_history.tr(),
  };
  return all.where((text) => find.text(text).evaluate().isNotEmpty).join(' | ');
}

/// What is wrong with the frame on screen, and what it says.
({List<String> problems, String said}) _inspect(
  WidgetTester tester,
  _Scene scene, {
  required Size screen,
  required double scale,
  required double? seconds,
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
  if (!onScreen(find.byType(AppButton))) {
    problems.add('The button is not on screen.');
  }
  // The leaving Receipt scrolls its slip as the last thing to give, when the
  // three lines under it and the buy block leave no more room: only at 320
  // wide and 568 tall.
  final mayScroll =
      scene.name == 'receipt_leaving' && screen.width < 340 && scale == 1.0;
  if (scale == 1.0 && !mayScroll) {
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
  for (final word in _forbidden) {
    if (find
        .textContaining(RegExp(word, caseSensitive: false))
        .evaluate()
        .isNotEmpty) {
      problems.add('A text says "$word".');
    }
  }
  final tags = find.byType(ProofLabelTag).evaluate().length;
  final said = StringBuffer(
    scene.name.startsWith('proof') || scene.name.startsWith('sheet')
        ? 'headline: ${_headlineOn(tester)}'
        : scene.name,
  );

  if (scene.name == 'receipt_leaving') {
    // The three lines about what Free gives are whole and above the buy
    // block, however little room there is.
    final after = {
      'history': find.text(
        LocaleKeys.paywall_leaving_receipt_after_history.tr(
          namedArgs: HostedBenefit.args,
        ),
      ),
      'critical': find.textContaining('stay critical'),
      'pushes': find.text(
        LocaleKeys.paywall_leaving_receipt_after_pushes.tr(
          namedArgs: HostedBenefit.args,
        ),
      ),
    };
    final buyTop = tester.getTopLeft(find.byType(PaywallPlanPicker).first).dy;
    for (final MapEntry(key: name, value: text) in after.entries) {
      if (text.evaluate().isEmpty) {
        problems.add('The $name after line is missing.');
        continue;
      }
      final rect = tester.getRect(text.first);
      if (rect.bottom > buyTop + 0.5) {
        problems.add('The $name after line runs behind the buy block.');
      }
    }
    final labelFinder = find.textContaining('AFTER ');
    if (labelFinder.evaluate().isEmpty) {
      problems.add('The after label is missing.');
    }
  }

  switch (scene.name) {
    case 'receipt_leaving' || 'wipe_leaving':
      if (find.textContaining(_removedNote).evaluate().isNotEmpty) {
        problems.add('The small print about critical topics is back.');
      }
    case 'proof_lead_history':
      final found = _headlineOn(tester);
      if (found.isEmpty || found.contains('|')) {
        problems.add('Not one headline: "$found".');
      }
      if (seconds != null) {
        final lead = LocaleKeys.paywall_history_own_headline.tr();
        // The entrance and the history beat are over by 4.5 seconds: later
        // frames are other benefits' beats.
        if (seconds <= 2.5 && found != lead) {
          problems.add('The lead beat does not carry "$lead".');
        }
        if (seconds >= 5.5 && found == lead) {
          problems.add('"$lead" stays up on another beat.');
        }
      }
    case 'proof_sample_rows':
      final found = _headlineOn(tester);
      final lead = LocaleKeys.paywall_sheet_headline_history.tr();
      if (seconds != null && seconds <= 3.0 && found != lead) {
        problems.add('The history beat does not say "$lead": "$found".');
      }
      if (seconds != null && seconds >= 8.5 && found == lead) {
        problems.add('"$lead" stays up on another beat.');
      }
      if (find
          .text(LocaleKeys.paywall_history_own_headline.tr())
          .evaluate()
          .isNotEmpty) {
        problems.add('Sample rows say "See older alarms".');
      }
    case 'sheet_long_name':
      if (find.textContaining('…').evaluate().isNotEmpty &&
          find.textContaining('Make nightly').evaluate().isNotEmpty) {
        problems.add('The headline cuts the name.');
      }
      if (find.textContaining('Make nightly').evaluate().isNotEmpty) {
        problems.add('The headline names a name over 16 characters.');
      }
  }
  if (scene.name.startsWith('wipe_leaving_topics')) {
    final n = int.parse(scene.name.substring('wipe_leaving_topics'.length));
    final pictures = tester
        .widgetList<TopicsPreview>(find.byType(TopicsPreview))
        .toList();
    said.write(
      ': ${pictures.length} topics pictures, counts '
      '${[for (final p in pictures) p.leavingCritical]}',
    );
    // Once the grey has covered the stage, every picture on it is the one
    // that holds the person's count.
    if (seconds == null || seconds >= 1.4) {
      for (final p in pictures) {
        if (p.leavingCritical != n) {
          problems.add('A topics picture does not hold the count $n.');
        }
      }
    }
  }
  if (scene.name == 'wipe_leaving') {
    said.write(', date tags on the card: $tags');
    // The card's tag is only for the struck frame.
    if (seconds != null && seconds < 1.3 && tags != 0) {
      problems.add('The card has a tag before its rows are struck.');
    }
    // A stage with no room for the card has no tag to put on it.
    final hasCard = find.byType(HistoryPreview).evaluate().isNotEmpty;
    if ((seconds == null || seconds >= 3) && tags != (hasCard ? 1 : 0)) {
      problems.add('The struck card has $tags date tags.');
    }
  }
  return (problems: problems, said: said.toString());
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await configureDependencies();
    await loadAppFonts();
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    required double scale,
    required bool isStill,
  }) {
    final probe =
        '${scene.name}_${phone.name}_${mode.name}_${scale}x'
        '${isStill ? '_reduced' : '_t'}';
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

      final boundaryKey = GlobalKey();
      final problems = <String>[];
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(
          BlocProvider<ThemeCubit>.value(
            value: getIt<ThemeCubit>(),
            child: MaterialApp.router(
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              routerConfig: buildRouter(initialLocation: scene.location()),
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

        Future<void> save(String tail, double? seconds) async {
          final seen = _inspect(
            tester,
            scene,
            screen: phone.size,
            scale: scale,
            seconds: seconds,
          );
          problems.addAll([for (final p in seen.problems) '$tail: $p']);
          await _save(
            tester,
            boundaryKey,
            '${scene.name}_${phone.name}_${mode.name}_${scale}x$tail',
            said: seen.said,
            isGood: seen.problems.isEmpty && errors.isEmpty,
          );
        }

        if (isStill) {
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          await save('_reduced', null);
        } else {
          var now = 0.0;
          for (final seconds in scene.times) {
            if (seconds > now) await _step(tester, seconds - now);
            now = seconds;
            await save('_t${seconds.toStringAsFixed(2)}', seconds);
          }
        }
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

  for (final scene in _scenes) {
    for (final phone in [_tall, _narrow]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in const [1.0, 2.0]) {
          capture(scene, phone: phone, mode: mode, scale: scale, isStill: true);
        }
      }
    }
    // Motion: the tall phone in both themes, and the narrow one.
    for (final (phone, mode, scale) in [
      (_tall, ThemeMode.light, 1.0),
      (_tall, ThemeMode.dark, 1.0),
      (_narrow, ThemeMode.light, 1.0),
      (_narrow, ThemeMode.dark, 2.0),
    ]) {
      capture(scene, phone: phone, mode: mode, scale: scale, isStill: false);
    }
  }
}
