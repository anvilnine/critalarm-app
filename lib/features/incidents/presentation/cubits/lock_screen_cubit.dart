import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for LockScreen.
class LockScreenCubit extends Cubit<LockScreenState> {
  LockScreenCubit(this._getIncidents) : super(const LockScreenState());

  final GetIncidentsUsecase _getIncidents;

  Future<void> load() async {
    final now = DateTime.now();
    emit(
      state.copyWith(
        status: LockScreenStatus.loading,
        dateText: DateFormat('EEEE d MMMM').format(now),
        timeText: DateFormat('HH:mm').format(now),
      ),
    );

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
}
