import 'dart:async';

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for LockScreen.
class LockScreenCubit extends Cubit<LockScreenState> {
  LockScreenCubit(this._getIncidents, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const LockScreenState());

  final GetIncidentsUsecase _getIncidents;

  /// Injected in tests so the clock can be moved without waiting.
  final DateTime Function() _now;

  Timer? _clockTimer;

  /// How long until the wall clock rolls over to the next minute.
  ///
  /// The screen shows HH:mm, so a one-second timer would wake up 59 times for
  /// nothing. A plain one-minute repeat is just as wrong the other way: start
  /// it at 10:30:59 and every change lands 59 seconds late. Waiting for the
  /// boundary and then re-arming keeps the reading right without the drift.
  static Duration untilNextMinute(DateTime now) =>
      const Duration(minutes: 1) -
      Duration(
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      );

  Future<void> load() async {
    _emitClock(status: LockScreenStatus.loading);
    _scheduleClockTick();

    final result = await _getIncidents();
    result.fold(
      (incidents) {
        final items = <LockNotificationItem>[];
        for (final inc in incidents) {
          final firstMsg = inc.messages.firstOrNull;
          final isCrit = inc.isOpen && inc.messages.any((m) => m.priority == 5);
          final isQuiet = !isCrit && inc.isClosed;

          items.add(
            LockNotificationItem(
              topic: inc.topic,
              title:
                  firstMsg?.title ??
                  LocaleKeys.lock_screen_incident_title.tr(
                    namedArgs: {'id': inc.id},
                  ),
              body: firstMsg?.message ?? '',
              faceState: isCrit ? FaceState.alarmed : FaceState.calm,
              ringingPillText: isCrit
                  ? LocaleKeys.lock_screen_ringing_pill.tr()
                  : null,
              timeText: inc.lastMessageAt == null
                  ? null
                  : DateFormat('HH:mm').format(inc.lastMessageAt!.toLocal()),
              isCrit: isCrit,
              isQuiet: isQuiet,
              incidentId: inc.id,
            ),
          );
        }

        emit(
          state.copyWith(
            status: LockScreenStatus.success,
            notifications: items,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: LockScreenStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  void _scheduleClockTick() {
    _clockTimer?.cancel();
    _clockTimer = Timer(untilNextMinute(_now()), () {
      _emitClock();
      _scheduleClockTick();
    });
  }

  void _emitClock({LockScreenStatus? status}) {
    final now = _now();
    emit(
      state.copyWith(
        status: status,
        dateText: DateFormat('EEEE d MMMM').format(now),
        timeText: DateFormat('HH:mm').format(now),
      ),
    );
  }

  @override
  Future<void> close() {
    _clockTimer?.cancel();
    _clockTimer = null;
    return super.close();
  }
}
