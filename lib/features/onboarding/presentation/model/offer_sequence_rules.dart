import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';

// The rules of the offer sequence that need no screen: whether the store can
// sell, when the once-per-install flag is written, and what happens when
// something else takes the user off the step. The screen hands in the facts.

/// How long the step waits for the store before it gives up and moves on.
const Duration offerSaleWait = Duration(seconds: 2);

/// The intro the offer plays. The setup test has just closed its incident,
/// and this is the first place a user can meet the false alarm.
const PaywallIntroId offerIntro = PaywallIntroId.falseAlarm;

/// What the step does with the buy model's answer about the store.
enum OfferSaleDecision {
  /// The product is on sale: the sequence plays.
  goOn,

  /// Nothing to buy, or the store could not say: the step finishes with no
  /// intro.
  skip,

  /// No answer yet and time is left.
  keepWaiting,
}

/// Reads the buy model's [status] after it was asked what is on sale.
///
/// Only `ready` goes on. Not on sale and a failure skip, and so does a
/// product the store says is already held, since there is nothing to sell.
/// No answer yet (null, or still loading) keeps waiting until [timedOut].
OfferSaleDecision offerSaleDecision(
  PaywallBuyStatus? status, {
  required bool timedOut,
}) => switch (status) {
  PaywallBuyStatus.ready => OfferSaleDecision.goOn,
  PaywallBuyStatus.notOnSale ||
  PaywallBuyStatus.failed ||
  PaywallBuyStatus.purchasing ||
  PaywallBuyStatus.checking ||
  PaywallBuyStatus.done => OfferSaleDecision.skip,
  PaywallBuyStatus.loading ||
  null => timedOut ? OfferSaleDecision.skip : OfferSaleDecision.keepWaiting,
};

/// Whether opening the sequence uses up the false alarm's one showing.
///
/// Only a real run does, and only when the intro can play: with reduced
/// motion the intro host plays none, so the showing is kept for a later
/// look. A replay writes nothing.
bool offerUsesUpFalseAlarm({
  required PaywallIntroId intro,
  required bool isReplay,
  required bool reduceMotion,
}) => intro == PaywallIntroId.falseAlarm && !isReplay && !reduceMotion;

/// Whether the sequence may be on screen. A real alarm under way wins, and
/// so does anything that took the user off the step: the layer must not sit
/// on top of the alarm screen or hide it.
bool offerLayerMayStay({
  required bool stepIsHere,
  required bool alarmIsUnderWay,
}) => stepIsHere && !alarmIsUnderWay;

/// Whether the user bought: the layer said so, or the buy model reached
/// `done`, which a back gesture from the thanks leaves behind.
bool offerDidBuy({
  required bool? layerResult,
  required PaywallBuyStatus status,
}) => (layerResult ?? false) || status == PaywallBuyStatus.done;

/// How the layer came to an end.
enum OfferLayerEnd {
  /// The user bought.
  bought,

  /// The user closed it, or left it with the system back.
  closed,

  /// The step went away under it: something else took the user off the
  /// step, such as the alarm screen. The step is finished in the engine
  /// without a move, and no purchase is recorded.
  interrupted,
}

OfferLayerEnd offerLayerEnd({
  required bool didBuy,
  required bool stepIsHere,
}) {
  if (!stepIsHere) return OfferLayerEnd.interrupted;
  return didBuy ? OfferLayerEnd.bought : OfferLayerEnd.closed;
}
