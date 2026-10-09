import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';

/// Says a feature is locked only when that is certain.
///
/// For code that takes something away or downgrades it on its own, such as
/// putting the default app icon back. A wrong "locked" there costs a paying
/// person something, so four things have to be true before it says so:
///
/// - The holdings and the saved server mode have been read
///   ([FeatureAccess.ready]). A cold start reads "not held" until then.
/// - The server is known. A phone connected to nothing has no plan to
///   have ended, so nothing is taken from it.
/// - [FeatureAccess.decide] says locked.
/// - Where Hosted would unlock the feature, the store itself does not say
///   Hosted is active. The server's tier can trail a purchase by a few
///   seconds. A store that cannot answer counts as "may still be held".
///
/// When a holding that would unlock the feature could not be read, nobody
/// knows, and [isLocked] throws [HoldingUnreadable] like every other "once
/// ready" ask. The caller keeps what is there.
///
/// A screen that only draws a lock reads [FeatureAccess] and never this.
final class SureLock {
  const SureLock({
    required this._access,
    required this._hosted,
    this._table = featureTable,
  });

  final FeatureAccess _access;
  final HostedHoldingSource _hosted;
  final Map<AppFeature, FeatureRule> _table;

  /// Throws [HoldingUnreadable] when nobody knows.
  Future<bool> isLocked(AppFeature feature) async {
    if ((await _access.decideOnceReady(feature)) is! FeatureLocked) {
      return false;
    }
    if (_access.serverMode == null) return false;
    final unlockedBy = _table[feature]?.unlockedBy ?? const <Holding>{};
    if (unlockedBy.contains(Holding.hosted) &&
        await _hosted.storeMayStillHold()) {
      return false;
    }
    // The store may have answered while this waited.
    return _access.decide(feature) is FeatureLocked;
  }
}
