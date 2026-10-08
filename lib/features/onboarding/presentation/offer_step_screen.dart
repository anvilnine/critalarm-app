import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The `offer` setup step: a frame around one paywall layout.
///
/// It draws nothing itself. It asks `OnboardingOfferGate` what to do, and
/// either finishes at once or puts the layout the switches name over the
/// whole screen. The words, the prices and the buying all belong to the
/// layout and its buy block. Closing the layout finishes the step, and so
/// does a purchase, so nothing here can hold the rest of setup back.
class OfferStepScreen extends StatefulWidget {
  const OfferStepScreen({super.key});

  @override
  State<OfferStepScreen> createState() => _OfferStepScreenState();
}

class _OfferStepScreenState extends State<OfferStepScreen> {
  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted) return;
    _hasStarted = true;
    final isReplay = isOnboardingReplay(context);
    // After the first frame, so the layout opens over a step that is
    // already on screen.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_run(isReplay: isReplay)),
    );
  }

  Future<void> _run({required bool isReplay}) async {
    final decision = await getIt<OnboardingOfferGate>().decide(
      isReplay: isReplay,
    );
    if (!mounted) return;
    final product = decision.product;
    final layout = PaywallLayoutId.fromKey(decision.layoutKey);
    final builder = paywallLayoutBuilders[layout];
    if (product == null || layout == null || builder == null) {
      return _finish();
    }

    final funnel = getIt<OnboardingFunnel>();
    final flowId = getIt<OnboardingFlowEngine>().runningFlow().id;
    unawaited(
      funnel.offerShown(
        product: product.key,
        layout: layout.key,
        flowId: flowId,
        isReplay: isReplay,
      ),
    );
    final didBuy = await Navigator.of(context, rootNavigator: true).push<bool>(
      AmbientPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => _OfferLayoutHost(
          product: product,
          layout: layout,
          builder: builder,
        ),
      ),
    );
    // The step went away under the layout: the user is somewhere else, and
    // this run has nothing left to finish.
    if (!mounted) return;
    final report = (didBuy ?? false) ? funnel.offerBought : funnel.offerClosed;
    unawaited(
      report(
        product: product.key,
        layout: layout.key,
        flowId: flowId,
        isReplay: isReplay,
      ),
    );
    await _finish();
  }

  Future<void> _finish() =>
      finishOnboardingStep(context, OnboardingStepId.offer);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// One registered paywall layout with its buy model, as the paywall route
/// would build it. The layout's own close pops this page. A purchase pops it
/// too, with true.
class _OfferLayoutHost extends StatelessWidget {
  const _OfferLayoutHost({
    required this.product,
    required this.layout,
    required this.builder,
  });

  final PaywallProduct product;
  final PaywallLayoutId layout;
  final PaywallLayoutBuilder builder;

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PaywallBuyCubit>(
      // The same factory the paywall route uses: the store's buy path, and
      // the stand-in only in a build compiled to skip the store.
      create: (_) {
        final cubit = getIt<PaywallBuyCubit>(param1: product);
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocListener<PaywallBuyCubit, PaywallBuyState>(
        listenWhen: (before, after) =>
            _wasBuying(before) && after.status == PaywallBuyStatus.done,
        listener: (context, _) => Navigator.of(context).pop(true),
        child: PaywallRouteInfo(
          layout: layout,
          source: PaywallSource.onboardingOffer,
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}
