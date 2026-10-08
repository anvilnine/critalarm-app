// Captures one paywall layout for one product, off the device, with the mock
// API and made-up plans.
//
//   fvm flutter test tool/capture_paywall_layout.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=LAYOUT=hero --dart-define=PRODUCT=hosted
//
// It writes eight PNGs: 390 by 844 and 375 by 667, light and dark, at the
// default text size and at the largest (2.0), with motion still. Each file is
// named <layout>_<product>_<size>_<theme>_<scale>x.png and its path is
// printed, with the height the buy block was laid out at.
//
// LAYOUT is a PaywallLayoutId key and PRODUCT is `hosted` or `pro`. Optional:
//   --dart-define=OUT=<folder>     where the PNGs go (default build/paywall_shots)
//   --dart-define=STATE=<status>   a buy state: notOnSale, failed, checking,
//                                  purchasing, done (default ready)
//   --dart-define=BENEFITS=built   list only the benefits this build has, as a
//                                  store build does (default: every benefit)
//   --dart-define=SOURCE=<wire>    what opened the paywall, as a PaywallSource
//                                  wire name such as history (default direct)
//   --dart-define=T=<seconds>      let motion run and capture that second,
//                                  to look at an entrance half way. The clock
//                                  is stepped a frame at a time, so every
//                                  frame up to that second is laid out and an
//                                  overflow on the way fails the capture.
//   --dart-define=TAP=<x>,<y>      with T: tap that point of the screen at
//                                  second T, in points from its top left
//   --dart-define=DRAG=<x>,<y>,<x>,<y>
//                                  with T: drag from the first point to the
//                                  second at second T, over a fifth of a
//                                  second, and let go
//   --dart-define=HELD=true        with DRAG: capture with the finger still
//                                  down at the end of the drag
//   --dart-define=THEN=<seconds>   with TAP or DRAG: let this much more time
//                                  run before the capture
//   --dart-define=ONLY=<part>,<part>
//                                  capture only the files whose name has one
//                                  of these parts, such as 390x844_light_1.0x
//   --dart-define=ALSO=<s>,<s>     with T: go on to each of these later seconds
//                                  in the same run and capture each as its
//                                  own file, to see a motion as a strip
//   --dart-define=INTRO=<key>      play that intro first, a PaywallIntroId
//                                  key such as false_alarm. T then counts
//                                  from the intro's first frame, and the
//                                  layout's own clock starts at the intro's
//                                  hand over. With no T nothing moves, so no
//                                  intro plays.
//   --dart-define=THANKS=<key>     buy on the made-up buy model and capture
//                                  what plays after, a PaywallThanksId key
//                                  such as confetti. T then counts from the
//                                  confirmed purchase: the layout plays for
//                                  three seconds first. With no T it is the
//                                  resting frame. With STATE=done it is what
//                                  a buyer who already has the product sees.
//   --dart-define=RESTORE=true     with THANKS: restore in place of buying
//   --dart-define=MOTION=<names>   draw the Hero composition with these
//                                  motion variants in place of LAYOUT: any
//                                  of the HeroMotion enum names, comma
//                                  separated, such as rays,drop,lean,flip
//
// A capture fails when a layout overflows, when the close cross or the button
// is off screen, or when anything scrolls at the default text size.
//
// To capture the developer picker instead of a layout:
//
//   fvm flutter test tool/capture_paywall_layout.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=PICKER=intro --dart-define=T=2.5
//
// PICKER is `page` (the three rows), `intro`, `paywall` or `thanks` (that
// sheet open).
// PRODUCT picks the tab. T lets the tiles play to that second after the
// sheet opens. It writes one size, light and dark, at the default text size.
// PICKED=<layout>,<intro> opens it with those already chosen for Hosted, as
// the developer switches would hold them, to see the mark on a tile.
//
// To capture the previews instead of a layout, as the gallery shows them:
//
//   fvm flutter test tool/capture_paywall_layout.dart --dart-define=PREVIEWS=gallery
//
// It writes four PNGs: the limits section and the extras section, light and
// dark, each preview on its resting frame. LAYOUT, PRODUCT, STATE, BENEFITS
// and SOURCE are not read. Optional:
//   --dart-define=T=<seconds>      let the previews play and capture that
//                                  second. A full loop is 12 seconds.
//   --dart-define=SIZES=38,48      the tile edges to draw (default 56,120,240)
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
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/gallery/paywall_extras_previews_section.dart';
import 'package:critalarm/design/gallery/paywall_limits_previews_section.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _layoutKey = String.fromEnvironment('LAYOUT', defaultValue: 'hero');
const _productKey = String.fromEnvironment('PRODUCT', defaultValue: 'hosted');
const _out = String.fromEnvironment('OUT', defaultValue: 'build/paywall_shots');
const _state = String.fromEnvironment('STATE');
const _benefits = String.fromEnvironment('BENEFITS');
const _t = String.fromEnvironment('T');
const _also = String.fromEnvironment('ALSO');
const _only = String.fromEnvironment('ONLY');
const _sourceKey = String.fromEnvironment('SOURCE');
const _previews = String.fromEnvironment('PREVIEWS');
const _sizes = String.fromEnvironment('SIZES');
const _tap = String.fromEnvironment('TAP');
const _drag = String.fromEnvironment('DRAG');
const _held = bool.fromEnvironment('HELD');
const _then = String.fromEnvironment('THEN');
const _introKey = String.fromEnvironment('INTRO');
const _thanksKey = String.fromEnvironment('THANKS');
const _restore = bool.fromEnvironment('RESTORE');

/// How long the layout plays before the purchase, with THANKS and T.
const double _beforeBuying = 3;
const _motion = String.fromEnvironment('MOTION');
const _picker = String.fromEnvironment('PICKER');
const _picked = String.fromEnvironment('PICKED');

/// The variants MOTION names, or null when a name is none of them.
HeroMotion? _motionOf(String names) {
  var atmosphere = HeroAtmosphereStyle.drift;
  var entrance = HeroEntranceStyle.pop;
  var idle = HeroIdleStyle.bob;
  var arrival = HeroCardArrival.fade;
  for (final name in names.split(',').map((n) => n.trim())) {
    if (name.isEmpty) continue;
    final a = HeroAtmosphereStyle.values.asNameMap()[name];
    final e = HeroEntranceStyle.values.asNameMap()[name];
    final i = HeroIdleStyle.values.asNameMap()[name];
    final c = HeroCardArrival.values.asNameMap()[name];
    if (a == null && e == null && i == null && c == null) return null;
    atmosphere = a ?? atmosphere;
    entrance = e ?? entrance;
    idle = i ?? idle;
    arrival = c ?? arrival;
  }
  return HeroMotion(
    atmosphere: atmosphere,
    entrance: entrance,
    idle: idle,
    arrival: arrival,
  );
}

/// The Hero composition with [motion], on a made-up buy model: what MOTION
/// captures. No layout picks these variants yet, so the tool draws its own.
Widget _motionLayout(PaywallProduct product, HeroMotion motion) =>
    BlocProvider<PaywallBuyCubit>(
      create: (_) {
        final cubit = DemoPaywallBuyCubit(product);
        cubit.load().ignore();
        return cubit;
      },
      child: PaywallRouteInfo(
        layout: PaywallLayoutId.hero,
        source: PaywallSource.direct,
        showsUnbuilt: true,
        child: PaywallFrame(
          closeOnLeft: false,
          restAt: heroEntranceSeconds,
          builder: (context, scope) =>
              HeroComposition(scope: scope, motion: motion),
        ),
      ),
    );

/// The developer picker's route.
const _pickerLocation = '/settings/developer/paywall-layouts';

List<double> _numbers(String text) => [
  for (final part in text.split(',')) ?double.tryParse(part.trim()),
];

/// Plays the touch asked for with TAP or DRAG, then lets THEN seconds run.
/// Returns the finger when HELD keeps it down, for the caller to lift.
Future<TestGesture?> _touch(WidgetTester tester) async {
  TestGesture? finger;
  final tap = _numbers(_tap);
  final drag = _numbers(_drag);
  if (tap.length == 2) {
    await tester.tapAt(Offset(tap[0], tap[1]));
    await tester.pump();
  } else if (drag.length == 4) {
    final from = Offset(drag[0], drag[1]);
    final to = Offset(drag[2], drag[3]);
    finger = await tester.startGesture(from);
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await finger.moveTo(Offset.lerp(from, to, i / steps)!);
      await tester.pump(_frame);
    }
    if (!_held) {
      await finger.up();
      finger = null;
      await tester.pump();
    }
  }
  final then = double.tryParse(_then);
  if (then != null && then > 0) await _stepTo(tester, then);
  return finger;
}

/// One frame of the stepped clock.
const _frame = Duration(milliseconds: 16);

/// Runs the clock to [second], a frame at a time. One long pump would draw
/// an implicit animation that starts on the last frame at its first value.
Future<void> _stepTo(WidgetTester tester, double second) async {
  final end = Duration(microseconds: (second * 1e6).round());
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
  required double pixelRatio,
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
});

/// The largest text size captured.
const double _largest = 2;

/// The two phones, with the insets each one really has.
const _phones = <(String, Size, double, double)>[
  ('390x844', Size(390, 844), 47, 34),
  ('375x667', Size(375, 667), 20, 0),
];

String _scrolls(ScrollableState s) =>
    'Something scrolls at the default text size, by '
    '${s.position.maxScrollExtent.toStringAsFixed(1)} points.';

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        File('assets/fonts/$file').readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ),
      );
    }
    await loader.load();
  }

  await family('Bricolage Grotesque', [
    'BricolageGrotesque-Bold.ttf',
    'BricolageGrotesque-ExtraBold.ttf',
  ]);
  await family('Instrument Sans', [
    'InstrumentSans-Regular.ttf',
    'InstrumentSans-Medium.ttf',
    'InstrumentSans-SemiBold.ttf',
    'InstrumentSans-Bold.ttf',
  ]);
  await family('JetBrains Mono', [
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-SemiBold.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
}

/// The two gallery sections of previews, light and dark.
void _capturePreviews(double? second) {
  test('PREVIEWS and SIZES are known', () {
    expect(_previews, 'gallery', reason: 'PREVIEWS takes gallery only.');
    expect(
      _sizes.split(',').every((s) => s.isEmpty || double.tryParse(s) != null),
      isTrue,
      reason: 'SIZES is a comma separated list of tile edges.',
    );
  });
  if (_previews != 'gallery') return;

  final sizes = [
    for (final s in _sizes.split(',')) ?double.tryParse(s),
  ];
  final sections = <(String, Widget)>[
    (
      'limits',
      sizes.isEmpty
          ? const PaywallLimitsPreviewsSection()
          : PaywallLimitsPreviewsSection(edges: sizes),
    ),
    (
      'extras',
      sizes.isEmpty
          ? const PaywallExtrasPreviewsSection()
          : PaywallExtrasPreviewsSection(edges: sizes),
    ),
  ];

  for (final (sectionName, section) in sections) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final name = [
        'previews',
        sectionName,
        mode.name,
        if (_sizes.isNotEmpty) _sizes.replaceAll(',', '-'),
        if (second != null) 't$_t',
      ].join('_');

      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) =>
            errors.add(details.exceptionAsString());

        const dpr = 2.0;
        // Wide enough for the three default sizes on one row.
        tester.view.physicalSize = const Size(520, 1400) * dpr;
        tester.view.devicePixelRatio = dpr;
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
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: second == null),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  backgroundColor: context.appColors.canvas,
                  body: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: ColoredBox(
                        color: context.appColors.canvas,
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.s5),
                          child: SizedBox(
                            width: double.infinity,
                            child: section,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          if (second != null) await _stepTo(tester, second);

          await _save(
            tester,
            boundaryKey,
            name,
            pixelRatio: dpr,
            isGood: errors.isEmpty,
          );
          expect(errors, isEmpty, reason: errors.join('\n'));
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    }
  }
}

void main() {
  final layout = PaywallLayoutId.fromKey(_layoutKey);
  final product = PaywallProduct.parse(_productKey);
  final second = double.tryParse(_t);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // `test/flutter_test_config.dart` only runs for files under test/, so
    // this tool loads the strings itself or every label renders as its key.
    await loadTestTranslations();
    // After the strings, which start the preferences again from nothing.
    final picked = _picked.split(',');
    if (picked.length == 2) {
      SharedPreferences.setMockInitialValues({
        DevPaywallLayoutSwitch.hostedKey: picked[0].trim(),
        DevPaywallIntroSwitch.hostedKey: picked[1].trim(),
      });
    }
    await configureDependencies();
    await _loadFonts();
  });

  if (_previews.isNotEmpty) {
    _capturePreviews(second);
    return;
  }

  final source = PaywallSource.parse(_sourceKey);
  final intro = PaywallIntroId.fromKey(_introKey);
  final motion = _motionOf(_motion);
  final thanks = PaywallThanksId.fromKey(_thanksKey);
  test('LAYOUT names a layout', () {
    expect(
      _thanksKey.isEmpty || thanks != null,
      isTrue,
      reason: 'Nothing after a purchase has the key "$_thanksKey".',
    );
    expect(layout, isNotNull, reason: 'No layout has the key "$_layoutKey".');
    expect(
      _introKey.isEmpty || intro != null,
      isTrue,
      reason: 'No intro has the key "$_introKey".',
    );
    expect(motion, isNotNull, reason: 'MOTION has a name no variant has.');
    expect(
      const ['', 'page', 'intro', 'paywall', 'thanks'],
      contains(_picker),
      reason: 'PICKER is page, intro, paywall or thanks.',
    );
    expect(product.key, _productKey, reason: 'PRODUCT is hosted or pro.');
    expect(
      _sourceKey.isEmpty || source.wire == _sourceKey,
      isTrue,
      reason: 'No paywall source has the wire name "$_sourceKey".',
    );
  });
  if (layout == null || motion == null) return;
  final isPicker = _picker.isNotEmpty;

  for (final (sizeName, size, topInset, bottomInset) in _phones) {
    // The picker is a developer page: one phone, the default text size.
    if (isPicker && sizeName != _phones.first.$1) continue;
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, if (!isPicker) _largest]) {
        final name = [
          if (isPicker) 'picker_$_picker' else layout.key,
          if (_picked.isNotEmpty) 'picked-${_picked.replaceAll(',', '-')}',
          product.key,
          sizeName,
          mode.name,
          '${scale.toStringAsFixed(1)}x',
          if (_state.isNotEmpty) _state,
          if (_benefits.isNotEmpty) 'benefits-$_benefits',
          if (_sourceKey.isNotEmpty) 'source-$_sourceKey',
          if (second != null) 't$_t',
          if (_tap.isNotEmpty) 'tap-${_tap.replaceAll(',', '-')}',
          if (_drag.isNotEmpty) 'drag-${_drag.replaceAll(',', '-')}',
          if (_held) 'held',
          if (_then.isNotEmpty) 'then$_then',
          if (_introKey.isNotEmpty) 'intro-$_introKey',
          if (_thanksKey.isNotEmpty) 'thanks-$_thanksKey',
          if (_restore) 'restore',
          if (_motion.isNotEmpty) 'motion-${_motion.replaceAll(',', '-')}',
        ].join('_');

        if (_only.isNotEmpty && !_only.split(',').any(name.contains)) continue;
        testWidgets('capture $name', (tester) async {
          final errors = <String>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());

          const dpr = 2.0;
          tester.view.physicalSize = size * dpr;
          tester.view.devicePixelRatio = dpr;
          tester.view.padding = FakeViewPadding(
            top: topInset * dpr,
            bottom: bottomInset * dpr,
          );
          tester.view.viewPadding = tester.view.padding;
          addTearDown(tester.view.reset);

          final location = isPicker
              ? _pickerLocation
              : Uri.parse(paywallLayoutLocation(layout, product))
                    .replace(
                      queryParameters: {
                        'product': product.key,
                        if (intro != null) 'intro': intro.key,
                        if (thanks != null) ...{
                          'thanks': thanks.key,
                          'try': paywallTryOut,
                        },
                        if (_sourceKey.isNotEmpty) 'source': source.wire,
                        if (_state.isNotEmpty) 'state': _state,
                        // The route lists what the build has unless asked
                        // for all.
                        'benefits': _benefits.isEmpty
                            ? paywallAllBenefits
                            : _benefits,
                      },
                    )
                    .toString();
          final boundaryKey = GlobalKey();

          // A test paints every shadow as a solid shape unless told
          // otherwise. A capture is looked at, so it draws them as a phone
          // does.
          debugDisableShadows = false;
          try {
            Widget framed(BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                // Still unless a second was asked for.
                disableAnimations: second == null,
              ),
              child: RepaintBoundary(key: boundaryKey, child: child),
            );
            await tester.pumpWidget(
              BlocProvider<ThemeCubit>.value(
                value: getIt<ThemeCubit>(),
                child: _motion.isEmpty
                    ? MaterialApp.router(
                        theme: buildLightTheme(),
                        darkTheme: buildDarkTheme(),
                        themeMode: mode,
                        routerConfig: buildRouter(initialLocation: location),
                        builder: framed,
                      )
                    : MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: buildLightTheme(),
                        darkTheme: buildDarkTheme(),
                        themeMode: mode,
                        home: _motionLayout(product, motion),
                        builder: framed,
                      ),
              ),
            );
            await tester.pump();
            if (isPicker) {
              // The tab, then the row that opens the sheet asked for.
              if (product == PaywallProduct.pro) {
                await tester.tap(find.text(paywallProductName(product)));
                await tester.pump();
              }
              final row = switch (_picker) {
                'intro' => LocaleKeys.paywall_picker_intro_row,
                'paywall' => LocaleKeys.paywall_picker_paywall_row,
                'thanks' => LocaleKeys.paywall_thanks_picker_row,
                _ => null,
              };
              if (row != null) {
                await tester.tap(find.text(row.tr()));
                await tester.pump();
              }
              await _stepTo(tester, second ?? 0.6);
            } else if (second == null) {
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 300));
            } else if (thanks == null || _state.isNotEmpty) {
              await _stepTo(tester, second);
            }
            if (thanks != null && _state.isEmpty) {
              // The layout plays, the buyer buys or restores, and T counts
              // from the frame the made-up model says the product is held.
              if (second != null) await _stepTo(tester, _beforeBuying);
              final cubit = BlocProvider.of<PaywallBuyCubit>(
                tester.element(find.byType(PaywallBuyBlock).first),
              );
              await tester.runAsync(() async {
                await (_restore ? cubit.restore() : cubit.buy());
              });
              await tester.pump();
              if (second != null) await _stepTo(tester, second);
              // The purchase cue's haptic is a short pattern on a timer.
              if (second == null) {
                await tester.pump(const Duration(milliseconds: 400));
              }
            }
            final finger = await _touch(tester);

            final screen = Offset.zero & size;
            bool onScreen(Finder finder) =>
                finder.evaluate().isNotEmpty &&
                screen.contains(tester.getRect(finder.first).topLeft) &&
                screen.contains(tester.getRect(finder.first).bottomRight);

            final problems = <String>[
              ...errors,
              if (!isPicker &&
                  thanks == null &&
                  !onScreen(find.byType(AppDismissCross)))
                'The close cross is not on screen.',
              if (!isPicker &&
                  _state.isEmpty &&
                  !onScreen(find.byType(AppButton)))
                'The button is not on screen.',
              if (scale == 1.0 && !isPicker)
                for (final s in tester.stateList<ScrollableState>(
                  find.byType(Scrollable),
                ))
                  if (s.position.maxScrollExtent > 0.5) _scrolls(s),
            ];

            await _save(
              tester,
              boundaryKey,
              name,
              pixelRatio: dpr,
              isGood: problems.isEmpty,
            );
            final block = find.byType(PaywallBuyBlock);
            if (block.evaluate().isNotEmpty) {
              final height = tester.getSize(block.first).height;
              print('     buy block ${height.toStringAsFixed(1)} points');
            }

            // The later seconds of the same run, each its own file.
            var at = second ?? 0;
            for (final later in _also.split(',')) {
              final to = double.tryParse(later.trim());
              if (second == null || to == null || to <= at) continue;
              await _stepTo(tester, to - at);
              at = to;
              await _save(
                tester,
                boundaryKey,
                name.replaceFirst('_t$_t', '_t${later.trim()}'),
                pixelRatio: dpr,
                isGood: errors.isEmpty,
              );
            }

            await finger?.up();
            expect(problems, isEmpty, reason: problems.join('\n'));
          } finally {
            debugDisableShadows = true;
            FlutterError.onError = oldHandler;
          }
        });
      }
    }
  }
}
