import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _HeardCues extends PaywallCues {
  final heard = <PaywallCue>[];

  @override
  void play(PaywallCue cue) => heard.add(cue);
}

void main() {
  late _HeardCues cues;
  late GoRouter router;

  setUp(() {
    cues = _HeardCues();
    getIt.registerSingleton<PaywallCues>(cues);
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  // The frame's clock never stops, so nothing here waits for stillness: a
  // second is longer than any page transition.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  /// A home screen with one paywall frame pushed over it. [startAs] opens
  /// the buy model in one state and [muted] draws it as a thumbnail does.
  Future<void> open(
    WidgetTester tester, {
    PaywallBuyStatus? startAs,
    bool muted = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'paywall',
              builder: (_, _) {
                final Widget frame = PaywallFrame(
                  builder: (_, _) => const SizedBox.expand(),
                );
                return BlocProvider<PaywallBuyCubit>(
                  create: (_) {
                    final cubit = DemoPaywallBuyCubit(
                      PaywallProduct.pro,
                      startAs: startAs,
                    );
                    unawaited(cubit.load());
                    return cubit;
                  },
                  child: muted ? PaywallMuted(child: frame) : frame,
                );
              },
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/paywall');
    await settle(tester);
    cues.heard.clear();
  }

  List<PaywallCue> closes() =>
      cues.heard.where((cue) => cue == PaywallCue.close).toList();

  testWidgets('the cross says close once', (tester) async {
    await open(tester);
    await tester.tap(find.byType(AppDismissCross));
    await tester.pump();
    expect(closes(), hasLength(1));
    await settle(tester);
    expect(find.text('home'), findsOneWidget);
    expect(closes(), hasLength(1));
  });

  testWidgets('back says close as the route starts to go, and once', (
    tester,
  ) async {
    await open(tester);
    // What the system back button and a finished back swipe do.
    await tester.binding.handlePopRoute();
    await tester.pump();
    // The paywall is still on its way out, and the cue has been sent.
    expect(find.byType(PaywallFrame), findsOneWidget);
    expect(closes(), hasLength(1));
    await settle(tester);
    expect(find.byType(PaywallFrame), findsNothing);
    expect(closes(), hasLength(1));
  });

  testWidgets('a route taken away without a pop still says close', (
    tester,
  ) async {
    await open(tester);
    router.go('/');
    await settle(tester);
    expect(find.byType(PaywallFrame), findsNothing);
    expect(closes(), hasLength(1));
  });

  testWidgets('leaving with the product in hand is silent', (tester) async {
    await open(tester, startAs: PaywallBuyStatus.done);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(PaywallFrame), findsNothing);
    expect(closes(), isEmpty);
  });

  testWidgets('a thumbnail going away is silent', (tester) async {
    await open(tester, muted: true);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(closes(), isEmpty);
  });
}
