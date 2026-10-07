import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/plain_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof_paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet_paywall_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Builds one layout. The widget it returns starts with a `PaywallFrame`.
typedef PaywallLayoutBuilder = Widget Function(BuildContext context);

/// Every layout that is built, by id. To add one, add its line here. An id
/// with no line draws `plain`.
final Map<PaywallLayoutId, PaywallLayoutBuilder> paywallLayoutBuilders = {
  PaywallLayoutId.bento: (_) => const BentoPaywallLayout(),
  PaywallLayoutId.plain: (_) => const PlainPaywallLayout(),
  PaywallLayoutId.proof: (_) => const ProofPaywallLayout(),
  PaywallLayoutId.sheet: (_) => const SheetPaywallLayout(),
};

/// Whether [layout] has a layout of its own, or falls back to `plain`.
bool paywallLayoutIsBuilt(PaywallLayoutId layout) =>
    paywallLayoutBuilders.containsKey(layout);

/// The location that opens [layout] selling [product]. The one place this
/// path is built.
String paywallLayoutLocation(
  PaywallLayoutId layout,
  PaywallProduct product, {
  PaywallSource source = PaywallSource.direct,
}) => Uri(
  path: paywallLayoutPathFor(layout.key),
  queryParameters: {'product': product.key, 'source': source.wire},
).toString();

/// One paywall on screen: it provides the buy model for [product] and
/// builds the layout registered for [layout].
class PaywallLayoutScreen extends StatelessWidget {
  const PaywallLayoutScreen({
    required this.layout,
    required this.product,
    this.source = PaywallSource.direct,
    this.demoStatus,
    this.showsUnbuilt = false,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallProduct product;
  final PaywallSource source;

  /// Developer builds only: opens a build that skips the store in one buy
  /// state, to look at it. A build with a store ignores it.
  final PaywallBuyStatus? demoStatus;

  /// Developer builds only: also lists the benefits not in this build.
  final bool showsUnbuilt;

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  @override
  Widget build(BuildContext context) {
    final builder =
        paywallLayoutBuilders[layout] ??
        paywallLayoutBuilders[PaywallLayoutId.plain]!;

    return BlocProvider<PaywallBuyCubit>(
      create: (_) {
        final cubit = getIt<PaywallBuyCubit>(
          param1: product,
          param2: demoStatus,
        );
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
