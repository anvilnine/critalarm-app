// Captures the paywall pieces that open on one benefit, off the device, with
// a made-up store and no server.
//
//   fvm flutter test tool/capture_paywall_lead.dart
//
// It writes PNGs named <scene>_<phone>_<theme>_<scale>x[_reduced].png and
// prints the path of every one. A scene that moves has one file for each
// frame asked for, with the second in its name, such as
// reel-hosted-topics-push-mid_390_light_1.0x.png.
//
// Scenes:
//   reel-*         the reel on Hosted with no lead, with the topics lead (a
//                  topic name, a headline and a line), with the weekly check
//                  lead twice (the homelab and the jobs line), and on Pro
//                  with the widgets lead. Settled in every combination, and
//                  moving in four of them: the entrance, the push to the
//                  second scene and the push back round to the first
//   layout-*       each of the nine layouts on Hosted, which now lists five
//                  benefits, settled at 320 wide and text scale 2.0
//   thanks-*       each of the six versions of the step after a purchase at
//                  rest on Hosted, and the confetti one with a button label
//   intro-hint     the false alarm intro over the reel with its hint line,
//                  from the first frame to after the hand over
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows, when the close cross is off
// screen, or when the buy block's button is.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _normal = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 640), 24, 0);

/// The short phone the paywall checks use: a layout must not scroll on it
/// at the default text size.
const _short = _Phone('375', Size(375, 667), 20, 0);

/// The made-up topic name the topics lead carries, and one that does not
/// fit the picture's first row.
const _topic = 'payments-db';
const _longTopic = 'payments-service-eu-west-primary';

const _servers = PaywallLead(
  benefit: PaywallBenefitId.topics,
  headlineKey: LocaleKeys.paywall_lead_servers_headline,
  lineKey: LocaleKeys.paywall_lead_servers_line,
  topicName: _topic,
);
const _serversLong = PaywallLead(
  benefit: PaywallBenefitId.topics,
  headlineKey: LocaleKeys.paywall_lead_servers_headline,
  lineKey: LocaleKeys.paywall_lead_servers_line,
  topicName: _longTopic,
);
const _homelab = PaywallLead(
  benefit: PaywallBenefitId.reliabilityChecks,
  headlineKey: LocaleKeys.paywall_lead_reaches_headline,
  lineKey: LocaleKeys.weekly_check_what_line,
);
const _jobs = PaywallLead(
  benefit: PaywallBenefitId.reliabilityChecks,
  headlineKey: LocaleKeys.paywall_lead_reaches_headline,
  lineKey: LocaleKeys.paywall_lead_jobs_line,
);
const _home = PaywallLead(
  benefit: PaywallBenefitId.widgets,
  headlineKey: LocaleKeys.paywall_lead_home_headline,
  lineKey: LocaleKeys.paywall_kit_benefits_widgets_line,
);

/// Cues make no sound in a capture.
class _SilentCues extends PaywallCues {
  const _SilentCues();

  @override
  void play(PaywallCue cue) {}
}

/// One layout, with the pieces a scene asks for, on a made-up buy model.
Widget _paywall({
  required PaywallProduct product,
  PaywallLayoutId layout = PaywallLayoutId.reel,
  PaywallLead? lead,
  PaywallIntroId intro = PaywallIntroId.none,
  String? hint,
  PaywallThanksId thanks = PaywallThanksId.none,
  String? buttonLabel,
  PaywallBuyStatus? startAs,
}) => BlocProvider<PaywallBuyCubit>(
  create: (_) {
    final cubit = DemoPaywallBuyCubit(product, startAs: startAs);
    cubit.load().ignore();
    return cubit;
  },
  child: PaywallRouteInfo(
    layout: layout,
    source: PaywallSource.onboardingOffer,
    lead: lead,
    child: PaywallThanksHost(
      thanks: thanks,
      product: product,
      buttonLabel: buttonLabel,
      onDone: () {},
      child: PaywallIntroHost(
        intro: intro,
        product: product,
        hint: hint,
        child: Builder(builder: paywallLayoutBuilders[layout]!),
      ),
    ),
  ),
);

/// The seconds a scene is captured at, with a short name for each.
typedef _Frames = List<(String, double)>;

/// One scene: what it draws, and the frames of it to save. No frames means
/// the settled frame alone.
class _Scene {
  const _Scene(this.name, this.build, {this.frames = const []});

  final String name;
  final Widget Function() build;
  final _Frames frames;
}

/// The frames of the reel worth looking at, read off its own loop: the
/// entrance, the push to the second scene, and the push back round to the
/// first. Each has its first frame and one part way through.
_Frames _reelFrames(PaywallProduct product, PaywallLead? lead) {
  final offer = PaywallOffer.from(product: product, lead: lead);
  final loop = HeroLoop(
    [for (final b in offer.benefits) b.previewId],
    holdSeconds: reelHoldSeconds,
  );
  // Where the turn changes: the first frame of each push.
  final pushes = <double>[];
  var turn = loop.frameAt(0).turn;
  for (var t = 0.0; t < loop.period + loop.entranceEnd + 2; t += 0.008) {
    final next = loop.frameAt(t).turn;
    if (next != turn) pushes.add(t);
    turn = next;
  }
  final second = pushes.first;
  final round = pushes.firstWhere((t) => loop.frameAt(t).activeIndex == 0);
  return [
    ('entrance-first', 0.016),
    ('entrance-mid', 0.35),
    ('push-first', second + 0.016),
    ('push-mid', second + 0.15),
    ('round-first', round + 0.016),
    ('round-mid', round + 0.15),
  ];
}

final _scenes = <_Scene>[
  _Scene(
    'reel-hosted-nolead',
    () => _paywall(product: PaywallProduct.hosted),
    frames: _reelFrames(PaywallProduct.hosted, null),
  ),
  _Scene(
    'reel-hosted-topics',
    () => _paywall(product: PaywallProduct.hosted, lead: _servers),
    frames: _reelFrames(PaywallProduct.hosted, _servers),
  ),
  _Scene(
    'reel-hosted-weekly',
    () => _paywall(product: PaywallProduct.hosted, lead: _homelab),
    frames: _reelFrames(PaywallProduct.hosted, _homelab),
  ),
  _Scene(
    'reel-hosted-jobs',
    () => _paywall(product: PaywallProduct.hosted, lead: _jobs),
    frames: _reelFrames(PaywallProduct.hosted, _jobs),
  ),
  _Scene(
    'reel-pro-widgets',
    () => _paywall(product: PaywallProduct.pro, lead: _home),
    frames: _reelFrames(PaywallProduct.pro, _home),
  ),
  _Scene(
    'reel-hosted-topics-long',
    () => _paywall(product: PaywallProduct.hosted, lead: _serversLong),
  ),
  // A Hosted lead on a Pro paywall is ignored: the reel is as it is with
  // no lead.
  _Scene(
    'reel-pro-nolead-ignored-lead',
    () => _paywall(product: PaywallProduct.pro, lead: _servers),
  ),
  for (final layout in PaywallLayoutId.values)
    if (paywallLayoutBuilders.containsKey(layout))
      _Scene(
        'layout-${layout.key}-hosted',
        () => _paywall(product: PaywallProduct.hosted, layout: layout),
      ),
  for (final thanks in PaywallThanksId.values)
    if (thanks != PaywallThanksId.none)
      _Scene(
        'thanks-${thanks.key}-hosted',
        () => _paywall(
          product: PaywallProduct.hosted,
          layout: PaywallLayoutId.hero,
          thanks: thanks,
          startAs: PaywallBuyStatus.done,
        ),
      ),
  _Scene(
    'thanks-confetti-label-hosted',
    () => _paywall(
      product: PaywallProduct.hosted,
      thanks: PaywallThanksId.confetti,
      buttonLabel: 'Hook up your tool', // l10n-ok: a made-up label
      startAs: PaywallBuyStatus.done,
    ),
  ),
  _Scene(
    'thanks-confetti-label-pro',
    () => _paywall(
      product: PaywallProduct.pro,
      lead: _home,
      thanks: PaywallThanksId.confetti,
      buttonLabel: 'Hook up your tool', // l10n-ok: a made-up label
      startAs: PaywallBuyStatus.done,
    ),
  ),
  _Scene(
    'intro-hint',
    () => _paywall(
      product: PaywallProduct.hosted,
      lead: _servers,
      intro: PaywallIntroId.falseAlarm,
      hint: LocaleKeys.paywall_lead_skip_hint.tr(),
    ),
    frames: const [
      ('1-first', 0.016),
      ('2-ringing', 0.5),
      ('3-admit', 1.0),
      ('4-fading', 1.4),
      ('5-handover', 1.52),
      ('6-after', 1.9),
    ],
  ),
];

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

/// One frame of the stepped clock.
const _frame = Duration(milliseconds: 16);

/// Runs the clock from [from] to [to] a frame at a time, so an implicit
/// animation is drawn on every frame and an overflow on the way is seen.
Future<void> _stepTo(WidgetTester tester, double from, double to) async {
  var at = Duration(microseconds: (from * 1e6).round());
  final end = Duration(microseconds: (to * 1e6).round());
  while (at < end) {
    final step = end - at < _frame ? end - at : _frame;
    await tester.pump(step);
    at += step;
  }
}

Future<void> _save(
  GlobalKey boundaryKey,
  String name,
  WidgetTester tester,
) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('SAVED ${file.path}');
});

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
    if (!getIt.isRegistered<PaywallCues>()) {
      getIt.registerSingleton<PaywallCues>(const _SilentCues());
    }
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    double scale = 1,
    bool isReduced = false,
    bool isMoving = false,
  }) {
    final frames = isMoving ? scene.frames : const <(String, double)>[];
    final base = '${phone.name}_${mode.name}_${scale.toStringAsFixed(1)}x';
    final suffix = isReduced ? '_reduced' : '';
    final names = [
      if (frames.isEmpty) '${scene.name}_$base$suffix',
      for (final (label, _) in frames) '${scene.name}-${label}_$base$suffix',
    ];
    if (!names.any(_wanted)) return;

    testWidgets('capture ${names.first}', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      debugDisableShadows = false;
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
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: isReduced,
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(key: boundaryKey, child: child),
            ),
            home: Scaffold(body: scene.build()),
          ),
        );

        final problems = <String>[];
        void check() {
          final screen = Offset.zero & phone.size;
          bool onScreen(Finder finder) =>
              finder.evaluate().isNotEmpty &&
              screen.contains(tester.getRect(finder.first).topLeft) &&
              screen.contains(tester.getRect(finder.first).bottomRight);
          final isThanks = scene.name.startsWith('thanks-');
          if (!isThanks && !onScreen(find.byType(AppDismissCross))) {
            problems.add('The close cross is not on screen.');
          }
          // At the default text size nothing scrolls. At a larger one a
          // layout may.
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
        }

        if (frames.isEmpty) {
          // The settled frame: under reduced motion nothing runs. Without
          // it, give the entrance and the pop in a few seconds to rest.
          await tester.pump();
          if (!isReduced) await _stepTo(tester, 0, 6);
          await tester.pump(const Duration(milliseconds: 400));
          check();
          await _save(boundaryKey, names.first, tester);
        } else {
          // The first frame is the one after the first pump, which is 16
          // milliseconds in.
          await tester.pump();
          var at = 0.0;
          for (final (i, (_, second)) in frames.indexed) {
            if (second > at) await _stepTo(tester, at, second);
            at = second > at ? second : at;
            check();
            await _save(boundaryKey, names[i], tester);
          }
        }
        expect(
          [...errors, ...problems],
          isEmpty,
          reason: [...errors, ...problems].join('\n'),
        );
      } finally {
        // Let the haptic timers the close cue starts run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  _Scene scene(String name) => _scenes.firstWhere((s) => s.name == name);

  bool isReel(_Scene s) =>
      s.name.startsWith('reel-') &&
      !s.name.endsWith('-long') &&
      !s.name.endsWith('ignored-lead');

  for (final s in _scenes) {
    // The reel: every phone, theme and text size, settled.
    if (isReel(s)) {
      for (final phone in [_normal, _narrow]) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            capture(s, phone: phone, mode: mode, scale: scale, isReduced: true);
          }
        }
      }
      // And moving, where the layout moves: the narrowest and the usual.
      for (final (phone, mode, scale) in [
        (_normal, ThemeMode.light, 1.0),
        (_narrow, ThemeMode.light, 2.0),
        (_normal, ThemeMode.dark, 1.0),
        (_narrow, ThemeMode.dark, 2.0),
      ]) {
        capture(s, phone: phone, mode: mode, scale: scale, isMoving: true);
      }
    }
  }

  // A long topic name and a lead the product does not list.
  for (final name in [
    'reel-hosted-topics-long',
    'reel-pro-nolead-ignored-lead',
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      capture(
        scene(name),
        phone: _narrow,
        mode: mode,
        scale: 2,
        isReduced: true,
      );
      capture(scene(name), phone: _normal, mode: mode, isReduced: true);
    }
  }

  // The nine layouts on Hosted: 320 wide, text scale 2.0, light and dark.
  // And at the default size on the two phones the paywall is checked on,
  // where nothing may scroll.
  for (final s in _scenes.where((s) => s.name.startsWith('layout-'))) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      capture(s, phone: _narrow, mode: mode, scale: 2, isReduced: true);
    }
    capture(s, phone: _normal, mode: ThemeMode.light, isReduced: true);
    capture(s, phone: _short, mode: ThemeMode.light, isReduced: true);
  }

  // The six versions of the step after a purchase, at rest.
  for (final s in _scenes.where((s) => s.name.startsWith('thanks-'))) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      capture(s, phone: _narrow, mode: mode, scale: 2, isReduced: true);
      capture(s, phone: _normal, mode: mode, isReduced: true);
    }
  }

  // The intro hint, moving. Under reduced motion no intro plays, so no hint.
  final hint = scene('intro-hint');
  for (final (phone, mode, scale) in [
    (_normal, ThemeMode.light, 1.0),
    (_normal, ThemeMode.dark, 1.0),
    (_narrow, ThemeMode.light, 2.0),
    (_narrow, ThemeMode.dark, 1.0),
  ]) {
    capture(hint, phone: phone, mode: mode, scale: scale, isMoving: true);
  }
  capture(hint, phone: _normal, mode: ThemeMode.light, isReduced: true);
}
