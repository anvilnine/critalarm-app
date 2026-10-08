import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/limits/limits_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/stamp/stamp_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/unlock/unlock_thanks.dart';

/// Every version of the step after a purchase that is built, by id. To add
/// one, add its line here. `none` has no line, and an id with no line
/// plays nothing: the purchase ends as it did before there was a step.
final Map<PaywallThanksId, PaywallThanks> paywallThanksBuilders = {
  PaywallThanksId.confetti: confettiThanks,
  PaywallThanksId.unlock: unlockThanks,
  PaywallThanksId.stamp: stampThanks,
  PaywallThanksId.limits: limitsThanks,
};

/// Whether [thanks] can be played as asked: `none` always can, and any
/// other id when it has a line above.
bool paywallThanksIsBuilt(PaywallThanksId thanks) =>
    thanks == PaywallThanksId.none || paywallThanksBuilders.containsKey(thanks);

/// Whether [thanks] puts something of its own on screen after a purchase.
bool paywallThanksTakesOver(PaywallThanksId thanks) =>
    paywallThanksBuilders.containsKey(thanks);
