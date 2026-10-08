import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/telemetry/paywall_layout_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_reporter.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/plain_paywall_layout.dart';
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
  PaywallLayoutId.doors: (_) => const DoorsPaywallLayout(),
  PaywallLayoutId.falseAlarm: (_) => const FalseAlarmPaywallLayout(),
  PaywallLayoutId.plain: (_) => const PlainPaywallLayout(),
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

/// The location that opens [layout] selling [product]. The one place this
/// path is built.
///
/// [sourceWire] replaces [source] for an entry point that is not a
/// [PaywallSource], which is every Pro one. [showsUnbuilt] asks for the
/// developer view that lists every benefit, built or not.
String paywallLayoutLocation(
  PaywallLayoutId layout,
  PaywallProduct product, {
  PaywallSource source = PaywallSource.direct,
  String? sourceWire,
  bool showsUnbuilt = false,
}) => Uri(
  path: paywallLayoutPathFor(layout.key),
  queryParameters: {
    'product': product.key,
    'source': sourceWire ?? source.wire,
    if (showsUnbuilt) 'benefits': paywallAllBenefits,
  },
).toString();

/// One paywall on screen: it provides the buy model for [product] and
/// builds the layout registered for [layout].
class PaywallLayoutScreen extends StatelessWidget {
  const PaywallLayoutScreen({
    required this.layout,
    required this.product,
    this.source = PaywallSource.direct,
    this.sourceWire,
    this.demoStatus,
    this.showsUnbuilt = false,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallProduct product;
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
      ),
      source: isHosted
          ? source.wire
          : ProPackSheetSource.parse(sourceWire).wire,
    );
  }

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  @override
  Widget build(BuildContext context) {
    final builder = paywallLayoutBuilders[paywallLayoutDrawnFor(layout)]!;

    return BlocProvider<PaywallBuyCubit>(
      create: (_) {
        final cubit = getIt<PaywallBuyCubit>(
          param1: product,
          param2: demoStatus,
        );
        final reporter = _reporter();
        cubit.reporter = reporter;
        reporter?.viewed();
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocListener<PaywallBuyCubit, PaywallBuyState>(
        // A Hosted purchase lands where it always has. Pro stays here and
        // the buy block says it is on.
        listenWhen: (before, after) =>
            product == PaywallProduct.hosted &&
            _wasBuying(before) &&
            after.status == PaywallBuyStatus.done,
        listener: (context, _) => context.pushReplacement('/paywall/success'),
        child: PaywallRouteInfo(
          layout: layout,
          source: source,
          showsUnbuilt: showsUnbuilt,
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}
