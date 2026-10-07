// Captures one paywall layout for one product, off the device, with the mock
// API and made-up plans.
//
//   fvm flutter test tool/capture_paywall_layout.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=LAYOUT=plain --dart-define=PRODUCT=hosted
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
//   --dart-define=BENEFITS=all     also list the benefits not in this build
//   --dart-define=SOURCE=<wire>    what opened the paywall, as a PaywallSource
//                                  wire name such as history (default direct)
//   --dart-define=T=<seconds>      let motion run and capture that second,
//                                  to look at an entrance half way. The clock
//                                  is stepped a frame at a time, so every
//                                  frame up to that second is laid out and an
//                                  overflow on the way fails the capture.
//
// A capture fails when a layout overflows, when the close cross or the button
// is off screen, or when anything scrolls at the default text size.
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
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/gallery/paywall_extras_previews_section.dart';
import 'package:critalarm/design/gallery/paywall_limits_previews_section.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _layoutKey = String.fromEnvironment('LAYOUT', defaultValue: 'plain');
const _productKey = String.fromEnvironment('PRODUCT', defaultValue: 'hosted');
const _out = String.fromEnvironment('OUT', defaultValue: 'build/paywall_shots');
const _state = String.fromEnvironment('STATE');
const _benefits = String.fromEnvironment('BENEFITS');
const _t = String.fromEnvironment('T');
const _sourceKey = String.fromEnvironment('SOURCE');
const _previews = String.fromEnvironment('PREVIEWS');
const _sizes = String.fromEnvironment('SIZES');

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
    await configureDependencies();
    await _loadFonts();
  });

  if (_previews.isNotEmpty) {
    _capturePreviews(second);
    return;
  }

  final source = PaywallSource.parse(_sourceKey);
  test('LAYOUT names a layout', () {
    expect(layout, isNotNull, reason: 'No layout has the key "$_layoutKey".');
    expect(product.key, _productKey, reason: 'PRODUCT is hosted or pro.');
    expect(
      _sourceKey.isEmpty || source.wire == _sourceKey,
      isTrue,
      reason: 'No paywall source has the wire name "$_sourceKey".',
    );
  });
  if (layout == null) return;

  for (final (sizeName, size, topInset, bottomInset) in _phones) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, _largest]) {
        final name = [
          layout.key,
          product.key,
          sizeName,
          mode.name,
          '${scale.toStringAsFixed(1)}x',
          if (_state.isNotEmpty) _state,
          if (_benefits.isNotEmpty) 'benefits-$_benefits',
          if (_sourceKey.isNotEmpty) 'source-$_sourceKey',
          if (second != null) 't$_t',
        ].join('_');

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

          final location = Uri.parse(paywallLayoutLocation(layout, product))
              .replace(
                queryParameters: {
                  'product': product.key,
                  if (_sourceKey.isNotEmpty) 'source': source.wire,
                  if (_state.isNotEmpty) 'state': _state,
                  if (_benefits.isNotEmpty) 'benefits': _benefits,
                },
              )
              .toString();
          final boundaryKey = GlobalKey();

          // A test paints every shadow as a solid shape unless told
          // otherwise. A capture is looked at, so it draws them as a phone
          // does.
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
                      // Still unless a second was asked for.
                      disableAnimations: second == null,
                    ),
                    child: RepaintBoundary(key: boundaryKey, child: child),
                  ),
                ),
              ),
            );
            await tester.pump();
            if (second == null) {
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 300));
            } else {
              await _stepTo(tester, second);
            }

            final screen = Offset.zero & size;
            bool onScreen(Finder finder) =>
                finder.evaluate().isNotEmpty &&
                screen.contains(tester.getRect(finder.first).topLeft) &&
                screen.contains(tester.getRect(finder.first).bottomRight);

            final problems = <String>[
              ...errors,
              if (!onScreen(find.byType(AppDismissCross)))
                'The close cross is not on screen.',
              if (_state.isEmpty && !onScreen(find.byType(AppButton)))
                'The button is not on screen.',
              if (scale == 1.0)
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
