import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
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
    this._incidents,
    this._alarm,
    this.ringTick = const Duration(seconds: 1),
    DateTime Function()? now,
    this._onboardingCompleted,
  ]) : _now = now ?? DateTime.now,
       super(const CriticalAlarmState());

  final GetIncidentUsecase _getIncident;
  final GetIncidentsUsecase _getIncidents;
  final AcknowledgeIncidentUsecase _acknowledgeIncident;
  final CloseIncidentUsecase _closeIncident;

  /// The shared incident list. What the server answers to an acknowledge or a
  /// close goes in here, so every other screen and the app icon badge follow
  /// without asking the server again. Optional so a test can build the cubit
  /// without it.
  final IncidentsCubit? _incidents;

  /// Stops the ring on this device. Optional so a test can build the cubit
  /// without a platform channel behind it.
  final AlarmHost? _alarm;

  /// How often the ringing line is redrawn while the alarm is live. A test
  /// passes something short so it does not have to wait a real second.
  final Duration ringTick;

  /// Tells the demo celebration which pair of exits to draw. Optional so a
  /// test can build the cubit without it; absent reads as not finished,
  /// which is onboarding's own shape.
  final GetOnboardingCompletedUsecase? _onboardingCompleted;

  final DateTime Function() _now;

  /// Redraws the ringing line. Null whenever nothing is ringing.
  Timer? _ticker;

  /// Stop the local alarm for [incidentId]. Never throws: a platform channel
  /// that is missing or unhappy must not stop the acknowledge from going out.
  ///
  /// Names the incident, and only the incident. [AlarmHost.stopRinging] stops
  /// the sound whatever it belongs to, and Android runs one alarm service for
  /// the whole app, so asking for it here let an acknowledge or a close on one
  /// incident silence a different one nobody had answered.
  /// [AlarmHost.cancelAlarm] carries the id to the native side, which stops
  /// the service only when that id is the one ringing. A repeat push on an
  /// incident the app already holds as acknowledged rings under that same id,
  /// so the cancel still reaches it.
  ///
  /// [handOverToStatusCard] is only true for an acknowledge on a real
  /// incident. A close ends the incident, and the demo incident never existed
  /// on the server, so neither may leave an acked card behind: it is ongoing,
  /// so it cannot be swiped away, and its Done button has nothing to close.
  Future<void> _silence(
    String incidentId, {
    required bool handOverToStatusCard,
  }) async {
    try {
      await _alarm?.cancelAlarm(
        incidentId,
        handOverToStatusCard: handOverToStatusCard,
        // The acked card is built natively, with no engine and no network, so
        // it only knows what it is handed. Without these it read "Critical
        // incident" while the screen behind it named the topic.
        title: state.title.isEmpty ? null : state.title,
        body: state.body.isEmpty ? null : state.body,
      );
    } on Object catch (_) {
      // Nothing to do. The ack below is what the server cares about.
    }
  }

  /// Stops the ring on this device without telling the server anything.
  ///
  /// For the case where the incident could not be loaded: the phone is
  /// screaming and the screen has no id to acknowledge, so the least it can do
  /// is stop the noise. The incident stays open on the server.
  Future<void> silenceThisPhone() async {
    try {
      await _alarm?.stopRinging();
    } on Object catch (_) {
      // Nothing to do. There is no id to fall back on here.
    }
  }

  Future<void> load({String? incidentId}) async {
    _stopRingTicker();
    emit(const CriticalAlarmState(status: CriticalAlarmStatus.loading));
    if (incidentId == 'inc_demo') {
      // Read before the screen is drawn, so the exits never flash the
      // onboarding pair at someone who only re-tested from Settings.
      final done = await _onboardingCompleted?.call(const NoParams());
      if (isClosed) return;
      emit(state.copyWith(isOnboardingDone: done?.getOrNull() ?? false));
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
    _stopRingTicker();
    emit(
      CriticalAlarmState(
        status: CriticalAlarmStatus.failure,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> acknowledge() async {
    if (state.isAcknowledged || state.incident == null) return;

    final incident = state.incident!;
    final targetId = incident.id;

    if (targetId == 'inc_demo') {
      emit(state.copyWith(isAcknowledging: true));
      // The demo incident is not on the server, so a card for it would have
      // nothing behind its Done button.
      await _silence(targetId, handOverToStatusCard: false);
      _showAcknowledged(
        incident.copyWith(state: IncidentStates.acked, ackedAt: _now()),
        face: FaceState.calm,
      );
      return;
    }

    // The screen the person is looking at moves first, and so does every
    // other screen, because they all read the same list. Nothing here waits
    // on the server.
    final ringing = state;
    final ack = _incidents?.acknowledgeNow(incident);
    _showAcknowledged(
      ack?.guess ??
          incident.copyWith(state: IncidentStates.acked, ackedAt: _now()),
    );

    // Silence next, still before anything goes on the wire. The person
    // pressed Stop, so the noise is over whatever the server says: a slow or
    // refused ack must not keep it ringing.
    await _silence(targetId, handOverToStatusCard: true);

    final result = await _acknowledgeIncident(targetId);
    if (isClosed) return;

    result.fold(
      (updatedIncident) {
        // The server's own copy, which carries the real acked_at.
        _incidents?.applyIncident(updatedIncident);
        _showAcknowledged(updatedIncident);
      },
      (failure) {
        // 409 means it was acknowledged somewhere else, so the guess on
        // screen was right and there is nothing to put back.
        if (failure is ApiFailure && failure.statusCode == 409) return;

        // The server did not take the acknowledge, so the incident is still
        // open and can ring again. Saying "acknowledged" here sent people
        // back to sleep on a page nobody had handled. The phone is quiet,
        // because Stop already silenced it, and the screen goes back to the
        // ringing state so the button is there to try again.
        if (ack != null) _incidents?.revert(ack);
        emit(
          ringing.copyWith(
            status: CriticalAlarmStatus.ringing,
            incident: ack?.before ?? incident,
            isAcknowledged: false,
            isAcknowledging: false,
            isLive: true,
            errorMessage: LocaleKeys.critical_alarm_ack_failed.tr(),
          ),
        );
        _startRingTicker();
      },
    );
  }

  /// The acknowledged screen, for a guess and for the server's answer alike.
  void _showAcknowledged(
    Incident incident, {
    FaceState face = FaceState.acked,
  }) {
    _stopRingTicker();
    final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
      namedArgs: {'time': _formatTime(incident.ackedAt ?? _now())},
    );
    emit(
      state.copyWith(
        status: CriticalAlarmStatus.acknowledged,
        incident: incident,
        isAcknowledged: true,
        isAcknowledging: false,
        severityMode: SeverityMode.ack,
        faceState: face,
        isLive: false,
        word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
        subtext: ackMsg,
        feedbackMessage: ackMsg,
        clearError: true,
      ),
    );
  }

  /// Redraws the ringing line every [ringTick]. The duration used to be worked
  /// out once, when the screen loaded, so the number sat still while the person
  /// watched it.
  void _startRingTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(ringTick, (_) {
      final incident = state.incident;
      if (state.status != CriticalAlarmStatus.ringing || incident == null) {
        _stopRingTicker();
        return;
      }
      emit(
        state.copyWith(
          subtext: LocaleKeys.critical_alarm_stage_sub_ringing.tr(
            namedArgs: {'duration': _ringingFor(incident)},
          ),
        ),
      );
    });
  }

  void _stopRingTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Future<void> close() {
    _stopRingTicker();
    return super.close();
  }

  /// How long this incident has been ringing, right now. The string used to
  /// be the literal "Ringing 2 min 14 s.", a mockup value that shipped, so the
  /// screen claimed the same duration whatever was happening.
  String _ringingFor(Incident incident) {
    final openedAt = incident.openedAt;
    if (openedAt == null) return formatRingDuration(Duration.zero);
    return formatRingDuration(_now().difference(openedAt));
  }

  Future<void> closeIncident() async {
    final incidentId = state.incident?.id;
    if (incidentId == null) return;

    _stopRingTicker();

    // Closing ends the incident, so nothing should still be ringing for it and
    // no card should be left over it either.
    await _silence(incidentId, handOverToStatusCard: false);

    final result = await _closeIncident(incidentId);
    result.fold(
      (closedIncident) {
        _incidents?.applyIncident(closedIncident);
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
  }

  void _applyIncident(Incident incident) {
    _stopRingTicker();
    final firstMsg = incident.messages.firstOrNull;
    // A page with no title or no body used to fall back to a sample outage
    // about a database, which read as the real thing to someone woken by it.
    // Say what is actually known instead: the topic, and that nothing came
    // with it.
    final title =
        firstMsg?.title ??
        LocaleKeys.critical_alarm_fallback_title.tr(
          namedArgs: {'topic': incident.topic},
        );
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
      _startRingTicker();
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
