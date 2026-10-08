import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:flutter/foundation.dart';

/// The Pro pack as a holding. It wraps [ProPackAccess] and adds nothing:
/// the relay's list, the developer switch and the other-grant function all
/// stay in there.
final class ProHoldingSource implements HoldingSource {
  const ProHoldingSource(this._access);

  final ProPackAccess _access;

  @override
  Holding get holding => Holding.pro;

  /// Held when the pack is held. Pending while the store has finished a
  /// purchase and the relay has not listed the pack yet. A purchase that
  /// was only started is not held.
  @override
  HoldingState get state {
    if (_access.isHeld) return HoldingState.held;
    if (_access.isStoreAcceptedAwaitingRelay) return HoldingState.pending;
    return HoldingState.notHeld;
  }

  @override
  Listenable get changes => _access.changes;
}
