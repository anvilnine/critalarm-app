import 'dart:async';

import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// True while this account is on Pro. Drives the Pro badge.
///
/// Reads again whenever the plan or the account changes, so the badge shows
/// up the moment a purchase goes through and leaves on sign-out.
class ProStatusCubit extends Cubit<bool> {
  ProStatusCubit({
    required Future<bool> Function() readHoldsHosted,
    Stream<Object?>? holdingChanges,
    PlanChanges? planChanges,
    AccountIdentityChanges? identityChanges,
  }) : // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _readHoldsHosted = readHoldsHosted,
       _planChanges = planChanges ?? appPlanChanges,
       _identityChanges = identityChanges ?? appAccountIdentityChanges,
       super(false) {
    _planChanges.addListener(_onChanged);
    _identityChanges.addListener(_onChanged);
    _holdingSub = holdingChanges?.listen((_) => _onChanged());
    unawaited(load());
  }

  final Future<bool> Function() _readHoldsHosted;
  final PlanChanges _planChanges;
  final AccountIdentityChanges _identityChanges;

  /// `Holdings.stream` in the app: what is held changed.
  StreamSubscription<Object?>? _holdingSub;

  void _onChanged() => unawaited(load());

  @visibleForTesting
  Future<void> load() async {
    bool holdsHosted;
    try {
      holdsHosted = await _readHoldsHosted();
    } on Object catch (_) {
      // No badge beats a wrong badge.
      holdsHosted = false;
    }
    if (!isClosed) emit(holdsHosted);
  }

  @override
  Future<void> close() {
    _planChanges.removeListener(_onChanged);
    _identityChanges.removeListener(_onChanged);
    unawaited(_holdingSub?.cancel());
    return super.close();
  }
}
