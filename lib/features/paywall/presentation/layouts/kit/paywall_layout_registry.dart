import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/telemetry/paywall_layout_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_reporter.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe_paywall_layout.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Builds one layout. The widget it returns starts with a `PaywallFrame`.
typedef PaywallLayoutBuilder = Widget Function(BuildContext context);

/// Every layout that is built, by id. To add one, add its line here. An id
/// with no line draws [paywallFallbackLayout].
final Map<PaywallLayoutId, PaywallLayoutBuilder> paywallLayoutBuilders = {
  PaywallLayoutId.hero: (_) => const HeroPaywallLayout(),
  PaywallLayoutId.bento: (_) => const BentoPaywallLayout(),
  PaywallLayoutId.doors: (_) => const DoorsPaywallLayout(),
  PaywallLayoutId.proof: (_) => const ProofPaywallLayout(),
  PaywallLayoutId.receipt: (_) => const ReceiptPaywallLayout(),
  PaywallLayoutId.reel: (_) => const ReelPaywallLayout(),
  PaywallLayoutId.sentence: (_) => const SentencePaywallLayout(),
  PaywallLayoutId.sheet: (_) => const SheetPaywallLayout(),
  PaywallLayoutId.wipe: (_) => const WipePaywallLayout(),
};

/// What an id with no layout of its own draws.
const PaywallLayoutId paywallFallbackLayout = PaywallLayoutId.hero;

/// The id whose layout is drawn for [layout]: its own when it is built,
/// [paywallFallbackLayout] when it is not.
PaywallLayoutId paywallLayoutDrawnFor(PaywallLayoutId layout) =>
    paywallLayoutIsBuilt(layout) ? layout : paywallFallbackLayout;

/// Whether [layout] has a layout of its own, or falls back.
bool paywallLayoutIsBuilt(PaywallLayoutId layout) =>
    paywallLayoutBuilders.containsKey(layout);

/// The `?benefits=` value that also lists the benefits not in this build.
/// Only a developer build reads it.
const String paywallAllBenefits = 'all';

/// The `?try=` value of the developer picker's "Open it": see
/// `PaywallLayoutScreen.isTryOut`. Only a developer build reads it.
const String paywallTryOut = 'buy';

/// The location that opens [layout] selling [product], after [intro] when
/// one is given, with [thanks] after a confirmed purchase when one is
/// given. The one place this path is built.
///
/// [sourceWire] replaces [source] for an entry point that is not a
/// [PaywallSource], which is every Pro one. [showsUnbuilt] asks for the
/// developer view that lists every benefit, built or not, and [isTryOut]
/// for the one where a build that skips the store confirms a purchase at
/// once.
String paywallLayoutLocation(
  PaywallLayoutId layout,
  PaywallProduct product, {
  PaywallIntroId intro = PaywallIntroId.none,
  PaywallThanksId thanks = PaywallThanksId.none,
  PaywallSource source = PaywallSource.direct,
  String? sourceWire,
  bool showsUnbuilt = false,
  bool isTryOut = false,
}) => Uri(
  path: paywallLayoutPathFor(layout.key),
  queryParameters: {
    'product': product.key,
    'source': sourceWire ?? source.wire,
    if (intro != PaywallIntroId.none) 'intro': intro.key,
    if (thanks != PaywallThanksId.none) 'thanks': thanks.key,
    if (showsUnbuilt) 'benefits': paywallAllBenefits,
    if (isTryOut) 'try': paywallTryOut,
  },
).toString();

/// One layout with the intro that plays before it and what plays after a
/// purchase, and nothing else: no buy model, no route.
/// `PaywallLayoutScreen` draws one for a user and a picker tile draws one
/// small. Above it there must be a
/// `BlocProvider<PaywallBuyCubit>` and a [PaywallRouteInfo].
class PaywallLayoutView extends StatelessWidget {
  const PaywallLayoutView({
    required this.layout,
    required this.product,
    this.intro = PaywallIntroId.none,
    this.thanks = PaywallThanksId.none,
    this.onThanksDone,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallProduct product;
  final PaywallIntroId intro;

  /// What plays once a purchase is confirmed. `none` plays nothing.
  final PaywallThanksId thanks;

  /// Where the one button of [thanks] goes.
  final VoidCallback? onThanksDone;

  @override
  Widget build(BuildContext context) => PaywallThanksHost(
    thanks: thanks,
    product: product,
    onDone: onThanksDone,
    child: PaywallIntroHost(
      intro: intro,
      product: product,
      child: Builder(
        builder: paywallLayoutBuilders[paywallLayoutDrawnFor(layout)]!,
      ),
    ),
  );
}

/// One paywall on screen: it provides the buy model for [product], plays
/// [intro] once, builds the layout registered for [layout], and plays
/// [thanks] once a purchase is confirmed.
class PaywallLayoutScreen extends StatelessWidget {
  const PaywallLayoutScreen({
    required this.layout,
    required this.product,
    this.intro = PaywallIntroId.none,
    this.thanks = PaywallThanksId.none,
    this.isTryOut = false,
    this.source = PaywallSource.direct,
    this.sourceWire,
    this.demoStatus,
    this.showsUnbuilt = false,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallProduct product;

  /// The intro that plays before the layout, once.
  final PaywallIntroId intro;

  /// What plays once a purchase is confirmed. `none`, or an id this build
  /// has no version for, ends the purchase as it always has.
  final PaywallThanksId thanks;

  /// Developer builds only: the picker's "Open it". A build that skips the
  /// store then confirms a purchase at once and a restore finds the
  /// product, so the step after a purchase can be seen and heard, and its
  /// button comes back to the picker.
  final bool isTryOut;
  final PaywallSource source;

  /// The `?source=` value as it arrived. A Pro entry point is not a
  /// [PaywallSource], so [source] reads it as direct and only this still
  /// names it.
  final String? sourceWire;

  /// Developer builds only: opens a build that skips the store in one buy
  /// state, to look at it. A build with a store ignores it.
  final PaywallBuyStatus? demoStatus;

  /// Developer builds only: also lists the benefits not in this build.
  final bool showsUnbuilt;

  /// What reports this paywall, or null in a build with no telemetry.
  PaywallLayoutReporter? _reporter() {
    if (!getIt.isRegistered<TelemetryGate>()) return null;
    final isHosted = product == PaywallProduct.hosted;
    return PaywallLayoutReporter(
      PaywallLayoutAnalytics(
        getIt<TelemetryGate>(),
        layout: layout,
        isHosted: isHosted,
        intro: paywallIntroIsBuilt(intro) ? intro : PaywallIntroId.none,
        thanks: paywallThanksIsBuilt(thanks) ? thanks : PaywallThanksId.none,
      ),
      source: isHosted
          ? source.wire
          : ProPackSheetSource.parse(sourceWire).wire,
    );
  }

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  /// Where the one button after a purchase goes: where the purchase went
  /// before there was a step. Hosted starts the app over at home, telling
  /// every screen the plan changed. Pro closes the paywall.
  void _afterThanks(BuildContext context) {
    if (isTryOut || product == PaywallProduct.pro) {
      unawaited(Navigator.maybePop(context));
      return;
    }
    appPlanChanges.bump();
    appAccountIdentityChanges.bump();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final takesOver = paywallThanksTakesOver(thanks);
    return BlocProvider<PaywallBuyCubit>(
      create: (_) {
        final cubit = getIt<PaywallBuyCubit>(
          param1: product,
          param2: demoStatus,
        );
        if (isTryOut && cubit is DemoPaywallBuyCubit) cubit.isTryOut = true;
        final reporter = _reporter();
        cubit.reporter = reporter;
        reporter?.viewed();
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocListener<PaywallBuyCubit, PaywallBuyState>(
        // A Hosted purchase lands where it always has. Pro stays here and
        // the buy block says it is on. With a step of its own after the
        // purchase, that step has the screen and its button goes on.
        listenWhen: (before, after) =>
            !takesOver &&
            product == PaywallProduct.hosted &&
            _wasBuying(before) &&
            after.status == PaywallBuyStatus.done,
        listener: (context, _) => context.pushReplacement('/paywall/success'),
        child: PaywallRouteInfo(
          layout: layout,
          source: source,
          showsUnbuilt: showsUnbuilt,
          child: Builder(
            builder: (context) => PaywallLayoutView(
              layout: layout,
              product: product,
              intro: intro,
              thanks: thanks,
              onThanksDone: () => _afterThanks(context),
            ),
          ),
        ),
      ),
    );
  }
}
