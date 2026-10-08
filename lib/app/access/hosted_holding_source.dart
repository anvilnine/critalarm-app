import 'dart:async';

import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
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
///
/// Two named questions sit next to the rule, for the two callers that must
/// not get the plain answer: [readHeldByServer] and [storeMayStillHold].
final class HostedHoldingSource implements HoldingSource {
  HostedHoldingSource({
    required this._readIdentity,
    PlanChanges? planChanges,
    ProOverride? proOverride,
    this._identityChanges = const [],
    this._readStore,
  }) : _plan = planChanges ?? appPlanChanges,
       _override = proOverride ?? appProOverride {
    _plan.addListener(_planChanged);
    _override.listenable?.addListener(_bell.ring);
    for (final changes in _identityChanges) {
      changes.addListener(_reload);
    }
    _latestRead = _read();
  }

  final Future<DeviceIdentity?> Function() _readIdentity;
  final PlanChanges _plan;
  final ProOverride _override;
  final List<Listenable> _identityChanges;

  /// The store, asked only by [storeMayStillHold]. Null in a build that
  /// has no store.
  final SubscriptionRepository Function()? _readStore;
  final _bell = _Bell();

  DeviceIdentity? _identity;
  int _reads = 0;
  bool _isDisposed = false;

  late Future<void> _latestRead;

  /// Done once the stored identity has been read, and read again after the
  /// last thing that may have moved it. A read that starts while this
  /// waits is waited for too, so [state] is never older than the last
  /// change when this completes.
  @override
  Future<void> get ready async {
    Future<void> waitedFor;
    do {
      waitedFor = _latestRead;
      await waitedFor;
    } while (!identical(waitedFor, _latestRead));
  }

  /// Whether the server's own tier says Hosted, read from the stored
  /// identity at this moment.
  ///
  /// It leaves out the store and the developer switch on purpose. It is
  /// for code that reports what the server did, such as "your plan has
  /// ended", which a developer switch going off must never trigger.
  Future<bool> readHeldByServer() async =>
      AccountAccess(await _readIdentity()).isRegisteredPaid;

  /// Asks the store itself whether Hosted is active. True as well when the
  /// store cannot answer.
  ///
  /// The registered tier can trail a purchase by a few seconds, and the
  /// store's flag is only mirrored once the store has spoken in this run.
  /// Code about to take something away asks this after [state] said
  /// `notHeld`, so a wrong "no" never costs a paying person anything.
  /// False in a build with no store: there is nobody to ask.
  Future<bool> storeMayStillHold() async {
    final store = _readStore;
    if (store == null) return false;
    try {
      return (await store().isProActive()).getOrNull() ?? true;
    } on Object catch (_) {
      return true;
    }
  }

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

  void _reload() => _latestRead = _read();

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
