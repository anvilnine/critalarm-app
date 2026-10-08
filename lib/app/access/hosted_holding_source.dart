import 'dart:async';

import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:flutter/foundation.dart';

/// The Hosted subscription as a holding.
///
/// Three things feed it, the same three `AccountAccess.isPaid` reads:
///
/// - The tier the server registered this device on.
/// - The store, for the seconds between a purchase and its webhook.
/// - The developer switch, in a build compiled with one.
///
/// The registered tier is kept from the last read of the stored identity,
/// so [state] is synchronous. It is read again whenever [PlanChanges] or
/// one of `identityChanges` fires. Until the first read lands ([ready]),
/// the tier counts as not paid.
final class HostedHoldingSource implements HoldingSource {
  HostedHoldingSource({
    required this._readIdentity,
    PlanChanges? planChanges,
    ProOverride? proOverride,
    this._identityChanges = const [],
  }) : _plan = planChanges ?? appPlanChanges,
       _override = proOverride ?? appProOverride {
    _plan.addListener(_planChanged);
    _override.listenable?.addListener(_bell.ring);
    for (final changes in _identityChanges) {
      changes.addListener(_reload);
    }
    ready = _read();
  }

  final Future<DeviceIdentity?> Function() _readIdentity;
  final PlanChanges _plan;
  final ProOverride _override;
  final List<Listenable> _identityChanges;
  final _bell = _Bell();

  DeviceIdentity? _identity;
  int _reads = 0;
  bool _isDisposed = false;

  /// Done once the stored identity has been read for the first time.
  late final Future<void> ready;

  /// The rule, as a function of its three inputs.
  ///
  /// `held` when the registered tier is paid or the developer switch forces
  /// it, `pending` when only the store says so, else `notHeld`. Anything
  /// but `notHeld` is exactly when `AccountAccess.isPaid` is true.
  static HoldingState stateFor({
    required DeviceIdentity? identity,
    required bool storeSaysPro,
    required bool isForcingPro,
  }) {
    if (AccountAccess(identity).isRegisteredPaid || isForcingPro) {
      return HoldingState.held;
    }
    return storeSaysPro ? HoldingState.pending : HoldingState.notHeld;
  }

  @override
  Holding get holding => Holding.hosted;

  @override
  HoldingState get state => stateFor(
    identity: _identity,
    storeSaysPro: _plan.storeSaysPro,
    isForcingPro: _override.isForcingPro,
  );

  @override
  Listenable get changes => _bell;

  /// The store flag reads live, so listeners hear it at once. The tier may
  /// have moved too, so the identity is read again and they hear that after.
  void _planChanged() {
    _bell.ring();
    _reload();
  }

  void _reload() => unawaited(_read());

  Future<void> _read() async {
    final read = ++_reads;
    DeviceIdentity? identity;
    try {
      identity = await _readIdentity();
    } on Object catch (error) {
      // What was known stays.
      debugPrint('hosted_holding_read_failed error=${error.runtimeType}');
      return;
    }
    // A newer read started while this one was out.
    if (read != _reads || _isDisposed) return;
    _identity = identity;
    _bell.ring();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _plan.removeListener(_planChanged);
    _override.listenable?.removeListener(_bell.ring);
    for (final changes in _identityChanges) {
      changes.removeListener(_reload);
    }
    _bell.dispose();
  }
}

/// Tells its listeners something changed and carries no value.
final class _Bell extends ChangeNotifier {
  void ring() => notifyListeners();
}
