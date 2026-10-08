import 'dart:async';

import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the weekly check row draws from.
@immutable
final class WeeklyCheckRowState {
  const WeeklyCheckRowState({
    this.check,
    this.missedByClock = false,
    this.isBusy = false,
    this.switchOutcome,
  });

  /// The relay's last answer, or null when it never answered on this phone.
  final WeeklyCheck? check;

  /// This phone's own clock says two rounds in a row were missed, the same
  /// answer that raises the notice on Home.
  final bool missedByClock;

  /// A tap on the switch is on its way to the relay.
  final bool isBusy;

  /// The last tap on the switch could not reach the relay.
  bool get didFail => switchOutcome == WeeklyCheckSwitchOutcome.failed;

  /// How the last tap on the switch ended, while that still has something
  /// to say: the relay refused it, or could not be reached. Null after a
  /// tap that worked and before any tap. The row words one line from it
  /// (`weeklyCheckSwitchLineKey`), so a refused tap never ends in silence.
  final WeeklyCheckSwitchOutcome? switchOutcome;

  WeeklyCheckRowState copyWith({
    WeeklyCheck? Function()? check,
    bool? missedByClock,
    bool? isBusy,
    WeeklyCheckSwitchOutcome? Function()? switchOutcome,
  }) => WeeklyCheckRowState(
    check: check == null ? this.check : check(),
    missedByClock: missedByClock ?? this.missedByClock,
    isBusy: isBusy ?? this.isBusy,
    switchOutcome: switchOutcome == null ? this.switchOutcome : switchOutcome(),
  );

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRowState &&
      other.check == check &&
      other.missedByClock == missedByClock &&
      other.isBusy == isBusy &&
      other.switchOutcome == switchOutcome;

  @override
  int get hashCode => Object.hash(check, missedByClock, isBusy, switchOutcome);
}

/// The weekly check row on the Reliability screen: what the relay last
/// said, and the switch.
class WeeklyCheckCubit extends Cubit<WeeklyCheckRowState> {
  WeeklyCheckCubit({required this._monitor})
    : super(WeeklyCheckRowState(check: _monitor.check)) {
    _changes = _monitor.changes.listen((_) => unawaited(_show()));
  }

  final WeeklyCheckMonitor _monitor;
  late final StreamSubscription<void> _changes;

  /// What the monitor holds now. An extra emit can change the outcome of
  /// nothing: it is the same read every time.
  Future<void> _show({
    bool? isBusy,
    WeeklyCheckSwitchOutcome? Function()? switchOutcome,
  }) async {
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
        switchOutcome: switchOutcome,
      ),
    );
  }

  /// Reads the check again. For when the row comes on screen. [force] reads
  /// even inside the monitor's one-minute window, for after a fix.
  Future<void> load({bool force = false}) async {
    await _monitor.refresh(force: force);
    await _show();
  }

  /// The switch was tapped. One tap at a time.
  Future<WeeklyCheckSwitchOutcome?> setEnabled({required bool enabled}) async {
    if (state.isBusy) return null;
    emit(state.copyWith(isBusy: true, switchOutcome: () => null));
    final outcome = await _monitor.setEnabled(enabled: enabled);
    await _show(
      isBusy: false,
      switchOutcome: () =>
          outcome == WeeklyCheckSwitchOutcome.done ? null : outcome,
    );
    return outcome;
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
