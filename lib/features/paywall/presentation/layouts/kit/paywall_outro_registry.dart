import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_outro.dart';

/// Every success outro that is built, by id. To add one, add its line
/// here. `none` has no line, and an id with no line plays nothing: the
/// purchase goes straight to the thanks.
final Map<PaywallOutroId, PaywallOutro> paywallOutroBuilders = {
  PaywallOutroId.breakLiftRing: breakLiftRing,
  PaywallOutroId.cloudClimb: cloudClimb,
};

/// Whether [outro] can be played as asked: `none` always can, and any
/// other id when it has a line above.
bool paywallOutroIsBuilt(PaywallOutroId outro) =>
    outro == PaywallOutroId.none || paywallOutroBuilders.containsKey(outro);
