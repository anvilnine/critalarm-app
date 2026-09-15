import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
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
    this._alarm,
  ]) : super(const CriticalAlarmState());

  final GetIncidentUsecase _getIncident;
  final GetIncidentsUsecase _getIncidents;
  final AcknowledgeIncidentUsecase _acknowledgeIncident;
  final CloseIncidentUsecase _closeIncident;

  /// Keeps the app icon showing how many incidents are still open. Optional so
  /// a test can build the cubit without a platform channel behind it.
  final UpdateIncidentBadgeUsecase? _updateBadge;

  /// Stops the ring on this device. Optional so a test can build the cubit
  /// without a platform channel behind it.
  final AlarmHost? _alarm;

  /// Stop the local alarm. Never throws: a platform channel that is missing or
  /// unhappy must not stop the acknowledge from going out.
  ///
  /// Asks twice on purpose. [AlarmHost.stopRinging] stops the sound whatever
  /// incident it belongs to, which is what the person pressing Stop means, and
  /// matters because the server can ring an incident the app already has as
  /// acknowledged. [AlarmHost.cancelAlarm] then clears the scheduled alarm and
  /// its notification for this incident.
  Future<void> _silence(String incidentId) async {
    try {
      await _alarm?.stopRinging();
      await _alarm?.cancelAlarm(incidentId);
    } on Object catch (_) {
      // Nothing to do. The ack below is what the server cares about.
    }
  }

  Future<void> load({String? incidentId}) async {
    emit(const CriticalAlarmState(status: CriticalAlarmStatus.loading));
    if (incidentId == 'inc_demo') {
      final now = DateTime.now();
      _applyIncident(
        Incident(
          id: 'inc_demo',
          topic: 'demo-topic',
          openedAt: now,
          messages: [
            Message(
              id: 'msg_demo',
              topic: 'demo-topic',
              title: 'Crit Alarm Test',
              message:
                  'This is a test alarm to verify your device rings '
                  'through silent mode.',
              priority: 5,
              time: now.millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        ),
      );
      return;
    }
    if (incidentId != null && incidentId.isNotEmpty) {
      final result = await _getIncident(incidentId);
      result.fold(_applyIncident, _showFailure);
      return;
    }
    final result = await _getIncidents(const GetIncidentsParams(state: 'open'));
    result.fold((incidents) {
      final incident = incidents.where((i) => i.isOpen).firstOrNull;
      if (incident == null) {
        emit(const CriticalAlarmState());
      } else {
        _applyIncident(incident);
      }
    }, _showFailure);
  }

  void _showFailure(Failure failure) {
    emit(
      CriticalAlarmState(
        status: CriticalAlarmStatus.failure,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> acknowledge() async {
    if (state.isAcknowledged || state.incident == null) return;

    emit(state.copyWith(isAcknowledging: true));

    final targetId = state.incident!.id;

    // Silence first. The person pressed Stop, so the noise is over whatever
    // the server says next. A slow or refused ack must not keep it ringing.
    await _silence(targetId);

    if (targetId == 'inc_demo') {
      final now = DateTime.now();
      final updated = state.incident!.copyWith(
        state: 'acked',
        ackedAt: now,
      );
      final timeStr = _formatTime(now);
      final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
        namedArgs: {'time': timeStr},
      );
      emit(
        state.copyWith(
          status: CriticalAlarmStatus.acknowledged,
          incident: updated,
          isAcknowledged: true,
          isAcknowledging: false,
          severityMode: SeverityMode.ack,
          faceState: FaceState.calm,
          isLive: false,
          word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
          subtext: ackMsg,
          feedbackMessage: ackMsg,
          clearError: true,
        ),
      );
      return;
    }

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

  /// How long this incident has been ringing, right now. The string used to
  /// be the literal "Ringing 2 min 14 s.", a mockup value that shipped, so the
  /// screen claimed the same duration whatever was happening.
  String _ringingFor(Incident incident) {
    final openedAt = incident.openedAt;
    if (openedAt == null) return formatRingDuration(Duration.zero);
    return formatRingDuration(DateTime.now().difference(openedAt));
  }

  Future<void> closeIncident() async {
    final incidentId = state.incident?.id;
    if (incidentId == null) return;

    // Closing ends the incident, so nothing should still be ringing for it.
    await _silence(incidentId);

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
    final topic = incident.topic;
    emit(
      state.copyWith(
        meta: firstMsg == null
            ? ''
            : '${_formatTime(DateTime.fromMillisecondsSinceEpoch(firstMsg.time * 1000).toLocal())} / ${firstMsg.tags.join(', ')}',
      ),
    );

    if (incident.isAcked) {
      final ackedTime = incident.ackedAt != null
          ? _formatTime(incident.ackedAt!)
          : '';
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
    } else if (!incident.isOpen) {
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
          subtext: LocaleKeys.critical_alarm_stage_sub_ringing.tr(
            namedArgs: {'duration': _ringingFor(incident)},
          ),
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
