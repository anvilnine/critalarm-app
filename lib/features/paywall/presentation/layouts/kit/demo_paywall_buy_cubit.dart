import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

/// The options a build that skips the store draws: two for Hosted, one for
/// Pro. They come from the price book, through the same rules as the
/// store's own. [book] is the running app's book unless one is given.
List<PaywallPlanOption> demoPlanOptions(
  PaywallProduct product, {
  PriceBook? book,
}) => bookPlanOptions(product, book ?? PriceBookInUse.current);

/// The buy model of a build that skips the store (`SKIP_PAYWALL`, the mock).
///
/// It draws the price book's prices so a layout and its captures have
/// something to draw. Buying asks no store, charges nothing and unlocks
/// nothing: it walks the same states a real purchase does and ends on
/// `done`.
/// [startAs] opens it in one state, for a capture of that state.
class DemoPaywallBuyCubit extends PaywallBuyCubit {
  DemoPaywallBuyCubit(
    super.product, {
    this.startAs,
    this.stepTime = const Duration(milliseconds: 700),
    this._priceBook,
  });

  /// Null reads the running app's book each time it loads.
  final PriceBook? _priceBook;
  final PaywallBuyStatus? startAs;
  final Duration stepTime;

  /// Set by the developer picker and its tiles: a purchase is confirmed at
  /// once and a restore finds the product, so what plays after either can
  /// be looked at with no store. It still walks every state on the way.
  bool isTryOut = false;

  Duration get _step => isTryOut ? Duration.zero : stepTime;

  @override
  Future<void> load() async {
    final ready = restingState(
      state,
      options: demoPlanOptions(state.product, book: _priceBook),
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
    began(PaywallBuyAction.purchase);
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    await Future<void>.delayed(_step);
    show(afterStore(state, PaywallStoreResult.done));
    await Future<void>.delayed(_step);
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
    began(PaywallBuyAction.restore);
    show(state.copyWith(status: PaywallBuyStatus.purchasing));
    await Future<void>.delayed(_step);
    show(
      afterConfirmStep(
        state,
        isTryOut
            ? PaywallConfirmStep.done
            : PaywallConfirmStep.nothingToRestore,
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
