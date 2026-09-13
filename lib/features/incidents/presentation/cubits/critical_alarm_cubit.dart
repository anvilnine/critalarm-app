import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/update_incident_badge_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing CriticalAlarmScreen state.
class CriticalAlarmCubit extends Cubit<CriticalAlarmState> {
  CriticalAlarmCubit(
    this._getIncident,
    this._getIncidents,
    this._acknowledgeIncident,
    this._closeIncident, [
    this._updateBadge,
  ]) : super(const CriticalAlarmState());

  final GetIncidentUsecase _getIncident;
  final GetIncidentsUsecase _getIncidents;
  final AcknowledgeIncidentUsecase _acknowledgeIncident;
  final CloseIncidentUsecase _closeIncident;

  /// Keeps the app icon showing how many incidents are still open. Optional so
  /// a test can build the cubit without a platform channel behind it.
  final UpdateIncidentBadgeUsecase? _updateBadge;

  Future<void> load({String? incidentId}) async {
    emit(state.copyWith(status: CriticalAlarmStatus.loading));

    if (incidentId != null && incidentId.isNotEmpty) {
      final result = await _getIncident(incidentId);
      result.fold(
        _applyIncident,
        (failure) {
          // If not found, fall back to alarmed mock data
          emit(
            state.copyWith(
              status: CriticalAlarmStatus.ringing,
              severityMode: SeverityMode.crit,
              faceState: FaceState.alarmed,
              isLive: true,
              isAcknowledged: false,
              errorMessage: failure.message,
            ),
          );
        },
      );
      return;
    }

    // No specific incidentId given; find active open incident or default
    final incidentsResult = await _getIncidents(
      const GetIncidentsParams(state: 'open'),
    );

    await incidentsResult.fold(
      (incidents) async {
        final critIncident = incidents.where((i) {
          return i.messages.any((m) => m.priority == 5) || i.isOpen;
        }).firstOrNull;

        if (critIncident != null) {
          _applyIncident(critIncident);
        } else {
          // Check for seeded alarmed fixture
          final fixtureResult = await _getIncident('inc_alarmed_proddb');
          fixtureResult.fold(
            _applyIncident,
            (_) {
              // Default fixture state
              emit(
                state.copyWith(
                  status: CriticalAlarmStatus.ringing,
                  severityMode: SeverityMode.crit,
                  faceState: FaceState.alarmed,
                  isLive: true,
                  isAcknowledged: false,
                ),
              );
            },
          );
        }
      },
      (failure) async {
        // Fall back to default alarmed state
        emit(
          state.copyWith(
            status: CriticalAlarmStatus.ringing,
            severityMode: SeverityMode.crit,
            faceState: FaceState.alarmed,
            isLive: true,
            isAcknowledged: false,
          ),
        );
      },
    );
  }

  Future<void> acknowledge() async {
    if (state.isAcknowledged) return;

    emit(state.copyWith(isAcknowledging: true));

    final targetId = state.incident?.id ?? 'inc_alarmed_proddb';
    final result = await _acknowledgeIncident(targetId);

    result.fold(
      (updatedIncident) {
        final ackedTime = updatedIncident.ackedAt ?? DateTime.now();
        final timeStr = _formatTime(ackedTime);
        final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
          namedArgs: {'time': timeStr},
        );

        emit(
          state.copyWith(
            status: CriticalAlarmStatus.acknowledged,
            incident: updatedIncident,
            isAcknowledged: true,
            isAcknowledging: false,
            severityMode: SeverityMode.ack,
            faceState: FaceState.acked,
            isLive: false,
            word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
            subtext: ackMsg,
            feedbackMessage: ackMsg,
            clearError: true,
          ),
        );
      },
      (failure) {
        final isConflict = failure is ApiFailure && failure.statusCode == 409;
        final timeStr = _formatTime(DateTime.now());
        final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
          namedArgs: {'time': timeStr},
        );

        if (isConflict) {
          emit(
            state.copyWith(
              status: CriticalAlarmStatus.acknowledged,
              isAcknowledged: true,
              isAcknowledging: false,
              severityMode: SeverityMode.ack,
              faceState: FaceState.acked,
              isLive: false,
              word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
              subtext: ackMsg,
              feedbackMessage: ackMsg,
              clearError: true,
            ),
          );
        } else {
          // If backend returned error, transition locally with feedback
          emit(
            state.copyWith(
              status: CriticalAlarmStatus.acknowledged,
              isAcknowledged: true,
              isAcknowledging: false,
              severityMode: SeverityMode.ack,
              faceState: FaceState.acked,
              isLive: false,
              word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
              subtext: ackMsg,
              feedbackMessage: ackMsg,
              errorMessage: failure.message,
            ),
          );
        }
      },
    );
    await _updateBadge?.call();
  }

  Future<void> closeIncident() async {
    final incidentId = state.incident?.id;
    if (incidentId == null) return;

    final result = await _closeIncident(incidentId);
    result.fold(
      (closedIncident) {
        emit(
          state.copyWith(
            status: CriticalAlarmStatus.closed,
            incident: closedIncident,
            word: LocaleKeys.critical_alarm_stage_word_closed.tr(),
            severityMode: SeverityMode.none,
            faceState: FaceState.calm,
            isLive: false,
          ),
        );
      },
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
      },
    );
    await _updateBadge?.call();
  }

  void _applyIncident(Incident incident) {
    final firstMsg = incident.messages.firstOrNull;
    final title =
        firstMsg?.title ?? LocaleKeys.critical_alarm_fallback_title.tr();
    final body = (firstMsg != null && firstMsg.message.isNotEmpty)
        ? firstMsg.message
        : LocaleKeys.critical_alarm_fallback_body.tr();
    final topic = incident.topic.isNotEmpty ? incident.topic : 'prod-db';

    if (incident.isAcked) {
      final ackedTime = incident.ackedAt != null
          ? _formatTime(incident.ackedAt!)
          : '03:14';
      final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
        namedArgs: {'time': ackedTime},
      );

      emit(
        state.copyWith(
          status: CriticalAlarmStatus.acknowledged,
          incident: incident,
          topic: topic,
          title: title,
          body: body,
          word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
          subtext: ackMsg,
          feedbackMessage: ackMsg,
          severityMode: SeverityMode.ack,
          faceState: FaceState.acked,
          isLive: false,
          isAcknowledged: true,
          clearError: true,
        ),
      );
    } else if (incident.isClosed) {
      emit(
        state.copyWith(
          status: CriticalAlarmStatus.closed,
          incident: incident,
          topic: topic,
          title: title,
          body: body,
          word: LocaleKeys.critical_alarm_stage_word_closed.tr(),
          severityMode: SeverityMode.none,
          faceState: FaceState.calm,
          isLive: false,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: CriticalAlarmStatus.ringing,
          incident: incident,
          topic: topic,
          title: title,
          body: body,
          word: LocaleKeys.critical_alarm_stage_word_critical.tr(),
          subtext: LocaleKeys.critical_alarm_stage_sub_ringing.tr(),
          severityMode: SeverityMode.crit,
          faceState: FaceState.alarmed,
          isLive: true,
          isAcknowledged: false,
          clearError: true,
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
