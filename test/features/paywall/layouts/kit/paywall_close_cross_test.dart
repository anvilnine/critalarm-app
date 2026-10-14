import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../tool/capture_fonts.dart';
import '../../../../helpers/load_translations.dart';

class _SilentCues extends PaywallCues {
  @override
  void play(PaywallCue cue) {}
}

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    // The preview pictures are measured in the app's own fonts.
    await loadAppFonts();
  });

  setUp(() {
    getIt.registerSingleton<PaywallCues>(_SilentCues());
  });

  tearDown(() async {
    await getIt.reset();
  });

  const phone = Size(390, 844);

  /// The cross of [layout] selling [product], after the entrance has played.
  Future<Rect> openAndFindCross(
    WidgetTester tester,
    PaywallLayoutId layout,
    PaywallProduct product,
  ) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: BlocProvider<PaywallBuyCubit>(
            create: (_) {
              final cubit = DemoPaywallBuyCubit(product);
              unawaited(cubit.load());
              return cubit;
            },
            child: PaywallRouteInfo(
              layout: layout,
              source: PaywallSource.direct,
              child: PaywallLayoutView(layout: layout, product: product),
            ),
          ),
        ),
      ),
    );
    // The clock never stops, so nothing waits for stillness: pump past the
    // longest entrance instead.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return tester.getRect(find.byType(AppDismissCross));
  }

  // Every layout id that is built, for both products.
  final layouts = paywallLayoutBuilders.keys.toList();

  group('every paywall layout draws the same close control', () {
    final rects = <String, Rect>{};

    for (final layout in layouts) {
      for (final product in PaywallProduct.values) {
        final name = '${layout.key} ${product.key}';
        testWidgets(name, (tester) async {
          final handle = tester.ensureSemantics();
          final rect = await openAndFindCross(tester, layout, product);
          rects[name] = rect;

          // One control, the house cross, drawn by the kit.
          expect(find.byType(AppDismissCross), findsOneWidget);
          expect(find.byType(PaywallCloseCross), findsOneWidget);

          // At least a 48 point tap target, whatever the layout.
          expect(rect.size, const Size(48, 48));

          // The same spoken label, once.
          expect(find.bySemanticsLabel('Close'), findsOneWidget);

          // Bare: no round disc is drawn behind the cross.
          final discs = find.byWidgetPredicate((widget) {
            final decoration = switch (widget) {
              DecoratedBox(:final decoration) => decoration,
              Container(:final decoration) => decoration,
              _ => null,
            };
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle;
          });
          for (final disc in discs.evaluate()) {
            final box = disc.renderObject! as RenderBox;
            final at = box.localToGlobal(Offset.zero) & box.size;
            final isUnderCross =
                at.overlaps(rect) &&
                at.width <= 48 &&
                at.height <= 48 &&
                at.contains(rect.center);
            expect(isUnderCross, isFalse, reason: 'a disc at $at');
          }

          handle.dispose();
        });
      }
    }

    tearDownAll(() {
      // The same corner: every cross is the same distance from the right
      // edge, whatever the layout and the product.
      final rights = rects.values.map((r) => r.right).toSet();
      expect(rects.length, layouts.length * PaywallProduct.values.length);
      expect(rights, hasLength(1), reason: '$rects');
      expect(rights.single, phone.width - PaywallCloseCross.edgeInset);
    });
  });
}
