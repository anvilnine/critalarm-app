import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layouts_dev_screen.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Paywall layouts page of Developer options, on switches saved in
/// memory. Nothing remote is behind it.
void main() {
  late DevPaywallLayoutSwitches switches;

  Future<void> open(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    switches = DevPaywallLayoutSwitches(
      hosted: DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.hostedKey),
      pro: DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.proKey),
      hostedIntro: DevPaywallIntroSwitch(
        prefs,
        DevPaywallIntroSwitch.hostedKey,
      ),
      proIntro: DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.proKey),
      hostedThanks: DevPaywallThanksSwitch(
        prefs,
        DevPaywallThanksSwitch.hostedKey,
      ),
      proThanks: DevPaywallThanksSwitch(prefs, DevPaywallThanksSwitch.proKey),
      hostedOutro: DevPaywallOutroSwitch(
        prefs,
        DevPaywallOutroSwitch.hostedKey,
      ),
      proOutro: DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.proKey),
    );
    await getIt.reset();
    getIt.registerSingleton<DevPaywallLayoutSwitches>(switches);
    addTearDown(getIt.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PaywallLayoutsDevScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('with nothing saved every step reads Auto, and no row says '
      'remote', (tester) async {
    await open(tester);

    // Intro, outro and what plays after a purchase.
    expect(find.text('Auto'), findsNWidgets(3));
    // The paywall row and the routing choice under it.
    expect(find.text('Auto, by entry point'), findsNWidgets(2));
    expect(find.textContaining('remote'), findsNothing);
    expect(find.textContaining('Remote'), findsNothing);
    expect(find.text('What ships today'), findsNothing);
    expect(switches.hosted.value, isNull);
  });

  testWidgets('the words an older build saved read as Auto', (tester) async {
    await open(
      tester,
      saved: {
        'dev.paywall_layout': 'shipped',
        'dev.pro_paywall_layout': 'auto',
      },
    );
    expect(tester.takeException(), isNull);
    expect(switches.hosted.value, isNull);
    expect(switches.pro.value, isNull);
    expect(find.text('Auto, by entry point'), findsNWidgets(2));
  });

  testWidgets('Auto is the first choice of the outro picker, and it hands '
      'the choice back', (tester) async {
    await open(tester, saved: {'dev.paywall_outro': 'break_lift'});
    expect(switches.hostedOutro.value, PaywallOutroId.breakLift);
    final pinned = paywallOutroName(PaywallOutroId.breakLift);

    await tester.tap(find.text(pinned));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // The sheet is drawn over the page, so its words are the last found.
    final auto = find.text('Auto').last;
    expect(find.text('Auto'), findsNWidgets(3), reason: 'two rows, one sheet');
    for (final outro in PaywallOutroId.values) {
      final name = find.text(paywallOutroName(outro));
      if (name.evaluate().isEmpty) continue;
      expect(
        tester.getTopLeft(auto).dy,
        lessThan(tester.getTopLeft(name.last).dy),
        reason: 'Auto is above ${outro.key}',
      );
    }

    await tester.tap(auto);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(switches.hostedOutro.value, isNull);
  });

  testWidgets('a pinned layout is named on its row, and Auto unpins it', (
    tester,
  ) async {
    await open(tester, saved: {'dev.paywall_layout': 'proof'});
    expect(
      switches.hosted.value,
      const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
    );
    // The routing choice is the one row left that says Auto for the layout.
    expect(find.text('Auto, by entry point'), findsOneWidget);
    await tester.tap(find.text('Auto, by entry point'));
    await tester.pump();
    expect(switches.hosted.value, isNull);
    expect(find.text('Auto, by entry point'), findsNWidgets(2));
  });
}
