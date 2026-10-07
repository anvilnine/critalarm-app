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
        renewalLine: SubscriptionTier.yearly.durationName,
      ),
    if (monthly != null)
      PaywallPlanOption(
        id: PaywallPlanOption.monthlyId,
        title: SubscriptionTier.monthly.displayName,
        price: monthly.priceString,
        renewalLine: SubscriptionTier.monthly.durationName,
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
enum PaywallStoreResult { done, cancelled, problem }

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
/// the confirming: it never means the product is held.
PaywallBuyState afterStore(PaywallBuyState state, PaywallStoreResult result) {
  switch (result) {
    case PaywallStoreResult.cancelled:
      return restingState(state);
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
