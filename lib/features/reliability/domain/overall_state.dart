import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';

/// The one state for the whole list: broken if any check is broken, else
/// needs a look if any needs one, else fine. Checks that are not on this phone
/// are ignored, and so is an empty list.
///
/// The result is never [ReliabilityState.notOnThisPhone].
ReliabilityState overallReliabilityState(Iterable<ReliabilityCheck> checks) {
  var overall = ReliabilityState.fine;
  for (final check in checks) {
    switch (check.state) {
      case ReliabilityState.broken:
        return ReliabilityState.broken;
      case ReliabilityState.needsLook:
        overall = ReliabilityState.needsLook;
      case ReliabilityState.fine:
      case ReliabilityState.notOnThisPhone:
        break;
    }
  }
  return overall;
}
