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
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_scene.dart';
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
    await loadAppFonts();
  });

  setUp(() => getIt.registerSingleton<PaywallCues>(_SilentCues()));
  tearDown(() async => getIt.reset());

  Future<void> run(WidgetTester tester, int milliseconds) async {
    for (var i = 0; i < milliseconds / 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the bare cross wears the ink of the scene under it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: BlocProvider<PaywallBuyCubit>(
            create: (_) {
              final cubit = DemoPaywallBuyCubit(PaywallProduct.hosted);
              unawaited(cubit.load());
              return cubit;
            },
            child: const PaywallRouteInfo(
              layout: PaywallLayoutId.reel,
              source: PaywallSource.direct,
              child: PaywallLayoutView(
                layout: PaywallLayoutId.reel,
                product: PaywallProduct.hosted,
              ),
            ),
          ),
        ),
      ),
    );
    await run(tester, 3000);

    Color crossColor() =>
        tester.widget<AppDismissCross>(find.byType(AppDismissCross)).color!;
    Color inkOf(ReelTone tone) => ReelToneColors.of(
      tester.element(find.byType(ReelComposition)),
      tone,
    ).ink;

    expect(reelToneFor(0), ReelTone.cream);
    expect(crossColor(), inkOf(ReelTone.cream));

    // A tap on the right half goes on: scene 2, then the dark panel scene.
    expect(reelToneFor(2), ReelTone.panel);
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(360, 400));
      await run(tester, 1500);
    }
    expect(crossColor(), inkOf(ReelTone.panel));
    expect(inkOf(ReelTone.panel), isNot(inkOf(ReelTone.cream)));
    // Still the one bare cross.
    expect(find.byType(AppDismissCross), findsOneWidget);
  });
}
