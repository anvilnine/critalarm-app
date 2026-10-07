import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/entities/plan_saving.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

// Every rule of the buy model that needs no store and no widget, so each
// one has a test.

/// What the store says one Hosted plan costs.
class HostedPlanQuote {
  const HostedPlanQuote({
    required this.priceString,
    required this.price,
    this.pricePerMonthString,
  });

  /// The billed amount, as the store words it.
  final String priceString;

  /// The same amount as a number, read only to work out the saving.
  final double price;

  /// The store's own per month figure, where it gives one.
  final String? pricePerMonthString;
}

/// "Save 33%", or null when either price is missing or yearly is not
/// cheaper. The app never claims a saving the store prices do not show.
String? yearlySavingLabel({
  required double? monthlyPrice,
  required double? yearlyPrice,
}) {
  final percent = yearlySavingPercent(
    monthlyPrice: monthlyPrice,
    yearlyPrice: yearlyPrice,
  );
  if (percent == null) return null;
  return LocaleKeys.paywall_badge_save.tr(namedArgs: {'percent': '$percent'});
}

/// The Hosted options, yearly first. A plan the store did not send is left
/// out, and no amount is ever made up for it.
List<PaywallPlanOption> hostedPlanOptions({
  required HostedPlanQuote? yearly,
  required HostedPlanQuote? monthly,
}) {
  final perMonth = yearly?.pricePerMonthString;
  return [
    if (yearly != null)
      PaywallPlanOption(
        id: PaywallPlanOption.yearlyId,
        title: SubscriptionTier.yearly.displayName,
        price: yearly.priceString,
        perPeriodLine: perMonth == null || perMonth.isEmpty
            ? null
            : LocaleKeys.paywall_price_per_month.tr(
                namedArgs: {'price': perMonth},
              ),
        savingLabel: yearlySavingLabel(
          monthlyPrice: monthly?.price,
          yearlyPrice: yearly.price,
        ),
        renewalLine: LocaleKeys.paywall_kit_renews_yearly.tr(),
      ),
    if (monthly != null)
      PaywallPlanOption(
        id: PaywallPlanOption.monthlyId,
        title: SubscriptionTier.monthly.displayName,
        price: monthly.priceString,
        renewalLine: LocaleKeys.paywall_kit_renews_monthly.tr(),
      ),
  ];
}

/// The Pro options: the store's own title and price for each offer, in the
/// store's order, and nothing else.
List<PaywallPlanOption> proPlanOptions(List<ProPackOffer> offers) => [
  for (final offer in offers)
    PaywallPlanOption(
      id: offer.handle,
      title: offer.title,
      price: offer.price,
    ),
];

/// How many plan cards the block draws. None for Pro with one offer: there
/// is nothing to pick, so its price goes on the button. While the store is
/// being asked, Hosted holds room for the two plans it usually has.
int planCardCount(PaywallBuyState state) {
  final isHosted = state.product == PaywallProduct.hosted;
  if (state.status == PaywallBuyStatus.loading) return isHosted ? 2 : 0;
  if (!isHosted && state.options.length == 1) return 0;
  return state.options.length;
}

/// The price the button carries, or null when a plan card shows it. One
/// rule for every layout, so the billed amount is on screen exactly once
/// per plan.
String? priceOnButton(PaywallBuyState state) {
  if (state.status == PaywallBuyStatus.loading) return null;
  return planCardCount(state) == 0 ? state.selected?.price : null;
}

/// What the buy button says: "Check again" over a check that paused, the
/// product and its price where no card shows the price, the product alone
/// everywhere else.
String buyButtonLabel(PaywallBuyState state, {required String name}) {
  if (state.status == PaywallBuyStatus.checking && state.isPaused) {
    return LocaleKeys.paywall_kit_button_check_again.tr();
  }
  final price = priceOnButton(state);
  return price == null
      ? LocaleKeys.paywall_kit_button_get.tr(namedArgs: {'name': name})
      : LocaleKeys.paywall_kit_button_get_price.tr(
          namedArgs: {'name': name, 'price': price},
        );
}

/// The second line of a plan card, under the name and the billed amount
/// and smaller than both: the per month figure where the plan has one,
/// when it renews where it has none.
String? planCardSecondLine(PaywallPlanOption option) =>
    option.perPeriodLine ?? option.renewalLine;

/// The small badge on a plan card: the saving, and only where the store
/// prices show one. Null draws no badge.
String? planCardBadge(PaywallPlanOption option) => option.savingLabel;

/// Whether the picker keeps room above its cards for a badge, which sits
/// half over a card's top edge.
///
/// It does when a card has one. While the store is being asked it does for
/// Hosted, whose yearly plan usually has one, so the cards do not move
/// when the prices arrive.
bool planPickerKeepsBadgeRoom(PaywallBuyState state) {
  if (state.status == PaywallBuyStatus.loading) {
    return state.product == PaywallProduct.hosted;
  }
  if (planCardCount(state) == 0) return false;
  return state.options.any((option) => planCardBadge(option) != null);
}

/// The small print under the button, for the option that is picked.
///
/// Hosted renews, so its line says at what price, how often, that it goes
/// on until cancelled and where to cancel. [store] is the account the store
/// charges, as that store names it. Pro is bought once and only says who
/// charges.
String legalLine(PaywallBuyState state, {required String store}) {
  if (state.product == PaywallProduct.pro) {
    return LocaleKeys.paywall_kit_legal_pro.tr(namedArgs: {'store': store});
  }
  final picked = state.selected;
  final key = switch (picked?.id) {
    PaywallPlanOption.yearlyId => LocaleKeys.paywall_kit_legal_hosted_yearly,
    PaywallPlanOption.monthlyId => LocaleKeys.paywall_kit_legal_hosted_monthly,
    _ => LocaleKeys.paywall_kit_legal_hosted,
  };
  return key.tr(namedArgs: {'store': store, 'price': picked?.price ?? ''});
}

/// The option picked when the paywall opens: the first one, which for
/// Hosted is yearly.
String? defaultPlanOptionId(List<PaywallPlanOption> options) =>
    options.isEmpty ? null : options.first.id;

/// The state the block rests in with [options] on sale: ready with the
/// default picked, or not on sale. A pick the buyer already made is kept
/// while that option is still there.
PaywallBuyState restingState(
  PaywallBuyState state, {
  List<PaywallPlanOption>? options,
  String? messageKey,
}) {
  final next = options ?? state.options;
  final keepsPick = next.any((option) => option.id == state.selectedId);
  return PaywallBuyState(
    product: state.product,
    status: next.isEmpty ? PaywallBuyStatus.notOnSale : PaywallBuyStatus.ready,
    options: next,
    selectedId: keepsPick ? state.selectedId : defaultPlanOptionId(next),
    messageKey: messageKey,
  );
}

/// How one trip to the store ended, as far as the store goes.
enum PaywallStoreResult {
  /// The store finished the purchase or the restore.
  done,

  /// The buyer backed out.
  cancelled,

  /// The store took the purchase and is holding the payment: it waits for
  /// an approval or for the money. Nothing failed and nothing is held yet.
  pending,

  /// The store reported a problem of its own.
  problem,
}

/// How a Hosted purchase that came back as a failure ended.
///
/// The repository says a cancel and a held payment with the same failure
/// type as every other store error, so its own two lines are the only way
/// to tell them apart. [cancelledText] and [pendingText] are those lines as
/// the repository words them, and [message] is the failure's.
PaywallStoreResult storeResultOfPurchaseFailure(
  String? message, {
  required String cancelledText,
  required String pendingText,
}) {
  if (message == null) return PaywallStoreResult.problem;
  if (message == cancelledText) return PaywallStoreResult.cancelled;
  if (message == pendingText) return PaywallStoreResult.pending;
  return PaywallStoreResult.problem;
}

PaywallStoreResult storeResultOfProPack(ProPackStoreResult result) =>
    switch (result) {
      ProPackStoreResult.done => PaywallStoreResult.done,
      ProPackStoreResult.cancelled => PaywallStoreResult.cancelled,
      ProPackStoreResult.problem => PaywallStoreResult.problem,
    };

/// The state that follows a purchase or a restore at the store.
///
/// Backing out is not a failure and says nothing. A problem says so and
/// leaves the options up to try again. A store that finished only starts
/// the confirming: it never means the product is held. A payment the store
/// is holding is none of those: the block says so and rests as a check
/// that paused, so the button asks again and never buys a second time.
PaywallBuyState afterStore(PaywallBuyState state, PaywallStoreResult result) {
  switch (result) {
    case PaywallStoreResult.cancelled:
      return restingState(state);
    case PaywallStoreResult.pending:
      return state.copyWith(
        status: PaywallBuyStatus.checking,
        messageKey: LocaleKeys.purchase_errors_payment_pending,
        isPaused: true,
      );
    case PaywallStoreResult.problem:
      final rest = restingState(
        state,
        messageKey: LocaleKeys.paywall_kit_failed,
      );
      return rest.status == PaywallBuyStatus.ready
          ? rest.copyWith(
              status: PaywallBuyStatus.failed,
              messageKey: rest.messageKey,
            )
          : rest;
    case PaywallStoreResult.done:
      return state.copyWith(status: PaywallBuyStatus.checking);
  }
}

/// One answer to "does this install have the product now".
enum PaywallConfirmAnswer {
  /// It does.
  held,

  /// The store was read and it does not.
  notHeld,

  /// Nothing is known: the call failed or the answer said nothing.
  unknown,
}

PaywallConfirmAnswer confirmAnswerOfProPack(ProPackRefreshOutcome outcome) =>
    switch (outcome) {
      ProPackRefreshOutcome.held => PaywallConfirmAnswer.held,
      ProPackRefreshOutcome.notHeld => PaywallConfirmAnswer.notHeld,
      ProPackRefreshOutcome.unknown => PaywallConfirmAnswer.unknown,
    };

/// What the confirming does with one answer.
enum PaywallConfirmStep { done, askAgain, nothingToRestore, paused }

/// The step that follows one confirm answer.
///
/// After a restore, a store that was read and holds nothing is a real
/// answer. After a purchase the store has just taken one, so the same
/// answer only means the news has not arrived: ask again. An answer that
/// says nothing is never a failed purchase and never "no product". When the
/// tries run out the check pauses, it does not fail.
PaywallConfirmStep afterConfirm(
  PaywallConfirmAnswer answer, {
  required bool afterPurchase,
  required bool hasTriesLeft,
}) {
  if (answer == PaywallConfirmAnswer.held) return PaywallConfirmStep.done;
  if (answer == PaywallConfirmAnswer.notHeld && !afterPurchase) {
    return PaywallConfirmStep.nothingToRestore;
  }
  return hasTriesLeft ? PaywallConfirmStep.askAgain : PaywallConfirmStep.paused;
}

/// The state a finished confirm leaves the block in. [pausedKey] is the
/// line a paused check shows.
PaywallBuyState afterConfirmStep(
  PaywallBuyState state,
  PaywallConfirmStep step, {
  required String pausedKey,
}) => switch (step) {
  PaywallConfirmStep.done => state.copyWith(status: PaywallBuyStatus.done),
  PaywallConfirmStep.nothingToRestore => restingState(
    state,
    messageKey: LocaleKeys.paywall_kit_nothing_to_restore,
  ),
  PaywallConfirmStep.paused => state.copyWith(
    status: PaywallBuyStatus.checking,
    messageKey: pausedKey,
    isPaused: true,
  ),
  PaywallConfirmStep.askAgain => state.copyWith(
    status: PaywallBuyStatus.checking,
  ),
};
