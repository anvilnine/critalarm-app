import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';

// The one rule of the photo try on the Look page, with nothing drawn and
// nothing written: when a framed photo is saved and when it is only held.

/// What happens to a photo the person has framed.
enum OwnPhotoDestination {
  /// Written to the phone, as the own look.
  save,

  /// Kept in memory for this visit to the page and written nowhere. The
  /// person sees it as their alarm, and the button that keeps it is the one
  /// that asks for the plan.
  hold,
}

/// Where a framed photo goes, for [decision] on whether alarm looks may be
/// kept and [isPlanRead] on whether the plan has been read.
///
/// It asks `lockTapFor` for a keep and writes no branch of its own. A photo
/// is saved only when that answers "do it". A locked look, a plan not read
/// yet and a look that is not offered all hold the photo: nothing is saved
/// on a guess.
OwnPhotoDestination ownPhotoDestinationFor({
  required FeatureDecision decision,
  required bool isPlanRead,
}) {
  final answer = lockTapFor(
    decision: decision,
    isPlanRead: isPlanRead,
    hasTry: true,
    tap: LockTapKind.keep,
  );
  return answer is DoIt ? OwnPhotoDestination.save : OwnPhotoDestination.hold;
}
