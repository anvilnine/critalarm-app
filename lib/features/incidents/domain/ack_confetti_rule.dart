import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';

/// Whether the acknowledged screen may throw its confetti, and play the
/// success haptic that goes with it.
///
/// One celebration per setup run. When the offer step follows the test
/// alarm, the offer's own thanks is the celebration, so the setup test's
/// acknowledged screen stays calm. Every other exit keeps its confetti.
///
/// [isOfferAhead] is what `OnboardingOfferGate.isAhead()` answered, or null
/// while it has not answered yet. Only [AckedExits.continueSetup] reads it,
/// and it throws nothing until the answer is a plain no. A read that failed
/// is already a no from the gate.
bool ackConfettiMayFly({
  required AckedExits exits,
  required bool? isOfferAhead,
  required bool reduceMotion,
}) {
  if (reduceMotion) return false;
  if (exits != AckedExits.continueSetup) return true;
  return isOfferAhead == false;
}
