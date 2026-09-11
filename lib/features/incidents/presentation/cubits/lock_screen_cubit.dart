import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for LockScreen.
class LockScreenCubit extends Cubit<LockScreenState> {
  LockScreenCubit(this._getIncidents) : super(const LockScreenState());

  final GetIncidentsUsecase _getIncidents;

  Future<void> load() async {
    emit(state.copyWith(status: LockScreenStatus.loading));

    final result = await _getIncidents();
    result.fold(
      (incidents) {
        if (incidents.isEmpty) {
          emit(state.copyWith(status: LockScreenStatus.success));
          return;
        }

        final items = <LockNotificationItem>[];
        for (final inc in incidents) {
          final firstMsg = inc.messages.firstOrNull;
          final isCrit = inc.isOpen && inc.messages.any((m) => m.priority == 5);
          final isQuiet = !isCrit && inc.isClosed;

          items.add(
            LockNotificationItem(
              topic: inc.topic,
              title: firstMsg?.title ?? 'Incident ${inc.id}',
              body: firstMsg?.message ?? '',
              faceState: isCrit ? FaceState.alarmed : FaceState.calm,
              ringingPillText: isCrit
                  ? 'Ringing through silent mode. Tap to acknowledge.'
                  : null,
              timeText: isCrit ? 'now' : '02:04',
              isCrit: isCrit,
              isQuiet: isQuiet,
              incidentId: inc.id,
            ),
          );
        }

        // If items were produced from real incidents, use them;
        // otherwise retain the default mockup notifications.
        emit(
          state.copyWith(
            status: LockScreenStatus.success,
            notifications: items.isNotEmpty ? items : state.notifications,
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
