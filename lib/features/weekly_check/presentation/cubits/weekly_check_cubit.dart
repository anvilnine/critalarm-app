import 'dart:async';

import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the unlocked weekly check row draws from.
@immutable
final class WeeklyCheckRowState {
  const WeeklyCheckRowState({
    this.check,
    this.missedByClock = false,
    this.isSelfHosted = false,
    this.isBusy = false,
    this.didFail = false,
  });

  /// The relay's last answer, or null when it never answered on this phone.
  final WeeklyCheck? check;

  /// This phone's own clock says two rounds in a row were missed, the same
  /// answer that raises the notice on Home.
  final bool missedByClock;

  /// The phone is connected to a self-hosted server.
  final bool isSelfHosted;

  /// A tap on the switch is on its way to the relay.
  final bool isBusy;

  /// The last tap on the switch could not reach the relay.
  final bool didFail;

  WeeklyCheckRowState copyWith({
    WeeklyCheck? Function()? check,
    bool? missedByClock,
    bool? isSelfHosted,
    bool? isBusy,
    bool? didFail,
  }) => WeeklyCheckRowState(
    check: check == null ? this.check : check(),
    missedByClock: missedByClock ?? this.missedByClock,
    isSelfHosted: isSelfHosted ?? this.isSelfHosted,
    isBusy: isBusy ?? this.isBusy,
    didFail: didFail ?? this.didFail,
  );

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRowState &&
      other.check == check &&
      other.missedByClock == missedByClock &&
      other.isSelfHosted == isSelfHosted &&
      other.isBusy == isBusy &&
      other.didFail == didFail;

  @override
  int get hashCode =>
      Object.hash(check, missedByClock, isSelfHosted, isBusy, didFail);
}

/// The weekly check row on the Reliability screen: what the relay last
/// said, and the switch.
class WeeklyCheckCubit extends Cubit<WeeklyCheckRowState> {
  WeeklyCheckCubit({
    required this._monitor,
    required this._readIsSelfHosted,
  }) : super(WeeklyCheckRowState(check: _monitor.check)) {
    _changes = _monitor.changes.listen((_) => unawaited(_show()));
  }

  final WeeklyCheckMonitor _monitor;
  final Future<bool> Function() _readIsSelfHosted;
  late final StreamSubscription<void> _changes;

  /// What the monitor holds now. An extra emit can change the outcome of
  /// nothing: it is the same read every time.
  Future<void> _show({bool? isBusy, bool? didFail}) async {
    var missedByClock = false;
    try {
      missedByClock = await _monitor.twoRoundsMissed();
    } on Object {
      // Unknown reads as no.
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        check: () => _monitor.check,
        missedByClock: missedByClock,
        isBusy: isBusy,
        didFail: didFail,
      ),
    );
  }

  /// Reads the check again. For when the row comes on screen. [force] reads
  /// even inside the monitor's one-minute window, for after a fix.
  Future<void> load({bool force = false}) async {
    var isSelfHosted = state.isSelfHosted;
    try {
      isSelfHosted = await _readIsSelfHosted();
    } on Object {
      // Unknown is drawn as whatever it was.
    }
    if (isClosed) return;
    emit(state.copyWith(isSelfHosted: isSelfHosted));
    await _monitor.refresh(force: force);
    await _show();
  }

  /// The switch was tapped. One tap at a time.
  Future<WeeklyCheckSwitchOutcome?> setEnabled({required bool enabled}) async {
    if (state.isBusy) return null;
    emit(state.copyWith(isBusy: true, didFail: false));
    final outcome = await _monitor.setEnabled(enabled: enabled);
    await _show(
      isBusy: false,
      didFail: outcome == WeeklyCheckSwitchOutcome.failed,
    );
    return outcome;
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
