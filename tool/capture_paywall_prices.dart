// Captures the Hosted paywall (hero) and the Pro paywall (sheet) on the
// made-up buy model, which draws the price book's prices. Off the device,
// no store and no server.
//
//   fvm flutter test tool/capture_paywall_prices.dart \
//     --dart-define=OUT=<folder>
//
// It writes <layout>_<product>_<phone>_light_1.0x.png for a 390 by 844 and
// a 320 by 568 phone, at the default text size, and prints each path. It
// fails on an overflow, a scroll at the default text size, or a close cross
// that is off screen.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
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
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _normal = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 568), 20, 0);

/// Cues make no sound in a capture.
class _SilentCues extends PaywallCues {
  const _SilentCues();

  @override
  void play(PaywallCue cue) {}
}

/// One layout on the made-up buy model.
Widget _paywall(PaywallLayoutId layout, PaywallProduct product) =>
    BlocProvider<PaywallBuyCubit>(
      create: (_) {
        final cubit = DemoPaywallBuyCubit(product);
        cubit.load().ignore();
        return cubit;
      },
      child: PaywallRouteInfo(
        layout: layout,
        source: PaywallSource.direct,
        child: Builder(builder: paywallLayoutBuilders[layout]!),
      ),
    );

const _frame = Duration(milliseconds: 16);

/// Runs the clock from zero to [to] seconds a frame at a time.
Future<void> _stepTo(WidgetTester tester, double to) async {
  var at = Duration.zero;
  final end = Duration(microseconds: (to * 1e6).round());
  while (at < end) {
    await tester.pump(_frame);
    at += _frame;
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

  for (final (layout, product) in [
    (PaywallLayoutId.hero, PaywallProduct.hosted),
    (PaywallLayoutId.sheet, PaywallProduct.pro),
  ]) {
    for (final phone in [_normal, _narrow]) {
      final name = '${layout.key}_${product.key}_${phone.name}_light_1.0x';
      testWidgets('capture $name', (tester) async {
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
              builder: (context, child) => RepaintBoundary(
                key: boundaryKey,
                child: child,
              ),
              home: Scaffold(body: _paywall(layout, product)),
            ),
          );
          await tester.pump();
          await _stepTo(tester, 6);
          await tester.pump(const Duration(milliseconds: 400));

          final problems = <String>[];
          final screen = Offset.zero & phone.size;
          final cross = find.byType(AppDismissCross);
          if (cross.evaluate().isEmpty ||
              !screen.contains(tester.getRect(cross.first).topLeft) ||
              !screen.contains(tester.getRect(cross.first).bottomRight)) {
            problems.add('The close cross is not on screen.');
          }
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
          await _save(boundaryKey, name, tester);
          expect(
            [...errors, ...problems],
            isEmpty,
            reason: [...errors, ...problems].join('\n'),
          );
        } finally {
          // Unmount, then let the timers the paywall started run out.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
          debugDisableShadows = true;
          FlutterError.onError = oldHandler;
        }
      });
    }
  }
}
