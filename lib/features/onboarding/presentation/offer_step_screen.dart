import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sale_probe.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sequence_rules.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What plays after a purchase here: the confetti, with a button that goes
/// on to the hook-up step.
const PaywallThanksId _offerThanks = PaywallThanksId.confetti;

/// The query a developer replay reads the answer from.
const String _replayUseParam = 'use';

/// The `offer` setup step: a frame around the offer sequence.
///
/// It draws nothing itself while it decides. It asks `OnboardingOfferGate`
/// what to do, then takes the store's answer about the product (cached since
/// the real alarm step started, so it rarely waits), and either finishes at
/// once or puts the sequence over the whole screen: the reel that opens on
/// the user's answer, and on a purchase the confetti thanks. There is no
/// intro: the user's first real alarm has only just stopped. The words, the
/// prices and the buying all belong to the layout and its buy block.
///
/// Closing the layer finishes the step, and so does a purchase, so nothing
/// here can hold the rest of setup back. Neither ends on Home: the next
/// step opens.
///
/// A real alarm wins. The layer sits on the root navigator, above the
/// router's pages, so a screen the router opens would draw under it. When
/// the step goes away under the layer, or an alarm starts, the layer is
/// taken off at once.
class OfferStepScreen extends StatefulWidget {
  const OfferStepScreen({super.key});

  @override
  State<OfferStepScreen> createState() => _OfferStepScreenState();
}

class _OfferStepScreenState extends State<OfferStepScreen> {
  bool _hasStarted = false;
  bool _hasBumpedPlan = false;

  /// Where the router stands for this step. A page the router replaces stays
  /// built while it slides out, so the step is only here while the router
  /// is still on its path.
  late GoRouter _router;
  late String _path;

  /// The layer while it is on screen, and the navigator that holds it.
  Route<bool>? _layer;
  NavigatorState? _navigator;
  StreamSubscription<bool>? _alarmStarts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
    _path = GoRouterState.of(context).uri.path;
    if (_hasStarted) return;
    _hasStarted = true;
    final isReplay = isOnboardingReplay(context);
    if (isReplay) _readReplayUse(GoRouterState.of(context).uri);
    // After the first frame, so the layer opens over a step that is
    // already on screen.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_run(isReplay: isReplay)),
    );
  }

  /// A developer build can open the sequence on one answer: `?use=` takes
  /// a wire id. It is held in memory for the replay and saved nowhere.
  void _readReplayUse(Uri uri) {
    if (!buildHasOnboardingDeveloperTools) return;
    final use = SetupUse.tryParse(uri.queryParameters[_replayUseParam]);
    if (use != null) getIt<SetupUseReplay>().set(use);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    unawaited(_alarmStarts?.cancel());
    _takeLayerOffAfterThisFrame();
    super.dispose();
  }

  /// The step is going away while the layer is up: something else took the
  /// user off it. The layer must not stay over whatever opens. It is taken
  /// off once this frame is done, since the navigator cannot be changed
  /// while the tree is being taken apart.
  bool get _isHere =>
      mounted && _router.routerDelegate.currentConfiguration.uri.path == _path;

  void _takeLayerOffAfterThisFrame() {
    final layer = _layer;
    final navigator = _navigator;
    if (layer == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (layer.isActive && navigator.mounted) navigator.removeRoute(layer);
    });
  }

  Future<void> _run({required bool isReplay}) async {
    final gate = getIt<OnboardingOfferGate>();
    final decision = await gate.decide(isReplay: isReplay);
    if (!mounted || !_isHere) return;
    final product = decision.product;
    final layout = PaywallLayoutId.fromKey(decision.layoutKey);
    final builder = paywallLayoutBuilders[layout];
    if (product == null || layout == null || builder == null) {
      getIt<OfferSaleProbe>().discard();
      return _finish();
    }
    // A real alarm is already under way: nothing plays over it.
    if (!offerLayerMayStay(
      stepIsHere: true,
      alarmIsUnderWay: getIt<AlarmFocus>().on,
    )) {
      getIt<OfferSaleProbe>().discard();
      return _finish();
    }

    // Before anything opens: is the product on sale? The store was asked
    // when the real alarm step started, so the answer is usually in. If it
    // is not, the screen stays as it is, the shell's canvas, while it
    // answers.
    final buy = await getIt<OfferSaleProbe>().takeOnSale(product);
    if (!mounted || !_isHere) {
      unawaited(buy?.close());
      return _finishQuietly(isReplay: isReplay);
    }
    if (buy == null || getIt<AlarmFocus>().on) {
      unawaited(buy?.close());
      return _finish();
    }

    final use = gate.readUse(isReplay: isReplay);
    final useWord = (use ?? SetupUse.other).wire;
    final funnel = getIt<OnboardingFunnel>();
    final flowId = getIt<OnboardingFlowEngine>().runningFlow().id;
    unawaited(
      funnel.offerShown(
        product: product.key,
        layout: layout.key,
        use: useWord,
        flowId: flowId,
        isReplay: isReplay,
      ),
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    final layer = _OfferLayerRoute(
      builder: (_) => _OfferLayer(
        buy: buy,
        product: product,
        layout: layout,
        lead: decision.lead,
        onBought: () => _afterPurchase(product),
      ),
    );
    // The buy model goes when the layer is gone, not before: the layer
    // still draws it while it slides out.
    unawaited(layer.completed.whenComplete(buy.close));
    _navigator = navigator;
    _layer = layer;
    _alarmStarts = getIt<AlarmFocus>().stream
        .where((isOn) => isOn)
        .listen((_) => _takeLayerOff());
    // The router moving off this step takes the layer off at once. Left to
    // the navigator, the layer would slide out with its page and show
    // through the screen that opens.
    _router.routerDelegate.addListener(_onRouteChanged);
    final result = await navigator.push<bool>(layer);
    _router.routerDelegate.removeListener(_onRouteChanged);
    unawaited(_alarmStarts?.cancel());
    _alarmStarts = null;
    _layer = null;
    // Let the layer finish leaving before the next step opens, so the two
    // never show through each other. A layer taken off at once is gone
    // already.
    await layer.completed.timeout(
      AppDurations.slow,
      onTimeout: () => null,
    );

    final end = offerLayerEnd(
      didBuy: offerDidBuy(layerResult: result, status: buy.state.status),
      stepIsHere: _isHere,
    );
    switch (end) {
      case OfferLayerEnd.interrupted:
        // The step went away under the layer, and the alarm screen or
        // whatever else took its place has the screen. The step is over;
        // nothing moves and no purchase is recorded.
        return _finishQuietly(isReplay: isReplay);
      case OfferLayerEnd.bought:
        // A back gesture from the thanks leaves the button unpressed.
        _afterPurchase(product);
        unawaited(
          funnel.offerBought(
            product: product.key,
            layout: layout.key,
            use: useWord,
            flowId: flowId,
            isReplay: isReplay,
          ),
        );
      case OfferLayerEnd.closed:
        unawaited(
          funnel.offerClosed(
            product: product.key,
            layout: layout.key,
            use: useWord,
            flowId: flowId,
            isReplay: isReplay,
          ),
        );
    }
    await _finish();
  }

  /// A confirmed purchase changes the plan: screens look again, and Hosted
  /// is a new account state too. Once only, whichever way the layer ends.
  void _afterPurchase(PaywallProduct product) {
    if (_hasBumpedPlan) return;
    _hasBumpedPlan = true;
    appPlanChanges.bump();
    if (product == PaywallProduct.hosted) appAccountIdentityChanges.bump();
  }

  void _onRouteChanged() {
    if (!_isHere) _takeLayerOff();
  }

  /// Takes the layer off with no animation, so whatever is under it is not
  /// hidden for a moment longer.
  void _takeLayerOff() {
    final layer = _layer;
    final navigator = _navigator;
    if (layer == null || navigator == null) return;
    if (layer.isActive && navigator.mounted) navigator.removeRoute(layer);
  }

  Future<void> _finish() =>
      finishOnboardingStep(context, OnboardingStepId.offer);

  /// Finishes the step in the engine and moves nowhere: the user is
  /// already somewhere else.
  Future<void> _finishQuietly({required bool isReplay}) =>
      finishOnboardingStepInEngine(OnboardingStepId.offer, isReplay: isReplay);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// The layer's route. The reel rises over the setup step from the bottom
/// edge, fully opaque, so the setup canvas and its tracker are covered by
/// the moving edge and never show through a half-faded reel. Nothing blank
/// is drawn: the first frame is the setup step as it was, and the next
/// already shows the rising reel. With reduced motion it opens at once.
/// It leaves with the short slide and fade every ambient route leaves with,
/// with reduced motion at once.
class _OfferLayerRoute extends AmbientPageRoute<bool> {
  _OfferLayerRoute({required super.builder}) : super(fullscreenDialog: true);

  @override
  Duration get transitionDuration => _isReduced ? Duration.zero : _riseTime;

  @override
  Duration get reverseTransitionDuration =>
      _isReduced ? Duration.zero : AppDurations.quick;

  bool get _isReduced => navigator?.context.reduceMotion ?? false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildOfferLayerTransition(animation: animation, child: child);
}

/// How long the reel takes to rise over the setup step.
const Duration _riseTime = AppDurations.slow;

/// The offer layer's way in and out, driven by the route's [animation].
///
/// Coming in, the layer rises from the bottom edge and is opaque the whole
/// way. Leaving, it slides a little to the right and fades, as an ambient
/// route does. The widget tree is the same both ways, so the reel keeps its
/// state when the direction turns.
@visibleForTesting
Widget buildOfferLayerTransition({
  required Animation<double> animation,
  required Widget child,
}) => AnimatedBuilder(
  animation: animation,
  child: child,
  builder: (context, child) {
    final isLeaving = animation.status == AnimationStatus.reverse;
    final value = animation.value;
    return Opacity(
      opacity: isLeaving ? Curves.easeOut.transform(value) : 1,
      child: FractionalTranslation(
        translation: isLeaving
            ? Offset(0.12 * (1 - AppCurves.easeOut.transform(value)), 0)
            : Offset(0, 1 - Curves.easeOutCubic.transform(value)),
        child: child,
      ),
    );
  },
);

/// The sequence over the setup: one registered paywall layout with the
/// confetti thanks after a purchase, on the buy model the step made. The
/// layout's own close pops the layer with nothing. The thanks button pops it
/// with true.
class _OfferLayer extends StatelessWidget {
  const _OfferLayer({
    required this.buy,
    required this.product,
    required this.layout,
    required this.lead,
    required this.onBought,
  });

  final PaywallBuyCubit buy;
  final PaywallProduct product;
  final PaywallLayoutId layout;
  final PaywallLead? lead;

  /// Called once the buyer pressed the thanks button, before the layer
  /// closes.
  final VoidCallback onBought;

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  @override
  Widget build(BuildContext context) {
    final thanks = paywallThanksIsBuilt(_offerThanks)
        ? _offerThanks
        : PaywallThanksId.none;
    final takesOver = paywallThanksTakesOver(thanks);
    return BlocProvider<PaywallBuyCubit>.value(
      value: buy,
      child: BlocListener<PaywallBuyCubit, PaywallBuyState>(
        // With a thanks of its own, the purchase waits for its button.
        // Without one, a confirmed purchase closes the layer at once.
        listenWhen: (before, after) =>
            !takesOver &&
            _wasBuying(before) &&
            after.status == PaywallBuyStatus.done,
        listener: (context, _) => Navigator.of(context).pop(true),
        child: PaywallRouteInfo(
          layout: layout,
          source: PaywallSource.onboardingOffer,
          lead: lead,
          child: Builder(
            builder: (context) => PaywallLayoutView(
              layout: layout,
              product: product,
              thanks: thanks,
              buttonLabel: LocaleKeys.onboarding_offer_thanks_button.tr(),
              onThanksDone: () {
                onBought();
                Navigator.of(context).pop(true);
              },
            ),
          ),
        ),
      ),
    );
  }
}
