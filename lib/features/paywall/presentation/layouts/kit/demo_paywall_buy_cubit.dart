import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

/// Made-up Hosted quotes for a build that skips the store. No real plan
/// costs these amounts.
const demoHostedYearly = HostedPlanQuote(
  priceString: r'$12.34', // l10n-ok: demo data
  price: 12.34, // l10n-ok: demo data
  pricePerMonthString: r'$1.03', // l10n-ok: demo data
);
const demoHostedMonthly = HostedPlanQuote(
  priceString: r'$1.23', // l10n-ok: demo data
  price: 1.23, // l10n-ok: demo data
);

/// A made-up Pro offer for a build that skips the store.
const demoProOffer = ProPackOffer(
  handle: 'demo',
  title: 'Crit Alarm Pro', // l10n-ok: demo data
  price: r'$5.67', // l10n-ok: demo data
);

/// The options a build that skips the store draws: two for Hosted, one for
/// Pro. They go through the same rules as the store's own.
List<PaywallPlanOption> demoPlanOptions(PaywallProduct product) =>
    switch (product) {
      PaywallProduct.hosted => hostedPlanOptions(
        yearly: demoHostedYearly,
        monthly: demoHostedMonthly,
      ),
      PaywallProduct.pro => proPlanOptions(const [demoProOffer]),
    };

/// The buy model of a build that skips the store (`SKIP_PAYWALL`, the mock).
///
/// It has made-up options so a layout and its captures have something to
/// draw. Buying asks no store, charges nothing and unlocks nothing: it
/// walks the same states a real purchase does and ends on `done`.
/// [startAs] opens it in one state, for a capture of that state.
class DemoPaywallBuyCubit extends PaywallBuyCubit {
  DemoPaywallBuyCubit(
    super.product, {
    this.startAs,
    this.stepTime = const Duration(milliseconds: 700),
  });

  final PaywallBuyStatus? startAs;
  final Duration stepTime;

  @override
  Future<void> load() async {
    final ready = restingState(
      state,
      options: demoPlanOptions(state.product),
    );
    show(switch (startAs) {
      null || PaywallBuyStatus.ready => ready,
      PaywallBuyStatus.notOnSale => restingState(state, options: const []),
      PaywallBuyStatus.failed => afterStore(
        ready,
        PaywallStoreResult.problem,
      ),
      PaywallBuyStatus.checking => afterConfirmStep(
        ready,
        PaywallConfirmStep.paused,
        pausedKey: LocaleKeys.paywall_kit_paused,
      ),
      final status => ready.copyWith(status: status),
    });
  }

  @override
  Future<void> buy() async {
    if (!state.canBuy) return;
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    await Future<void>.delayed(stepTime);
    show(afterStore(state, PaywallStoreResult.done));
    await Future<void>.delayed(stepTime);
    show(
      afterConfirmStep(
        state,
        PaywallConfirmStep.done,
        pausedKey: LocaleKeys.paywall_kit_paused,
      ),
    );
  }

  @override
  Future<void> restore() async {
    if (!state.canRestore) return;
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    await Future<void>.delayed(stepTime);
    show(
      afterConfirmStep(
        state,
        PaywallConfirmStep.nothingToRestore,
        pausedKey: LocaleKeys.paywall_kit_paused,
      ),
    );
  }

  @override
  Future<void> checkAgain() async {
    if (state.status != PaywallBuyStatus.checking || !state.isPaused) return;
    show(
      afterConfirmStep(
        state,
        PaywallConfirmStep.done,
        pausedKey: LocaleKeys.paywall_kit_paused,
      ),
    );
  }
}
