import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
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
    this._hasOwnedTopic,
    this._setupTestIncidentIds,
    this._setupFlowHasRealRing,
    this._endSetupTest,
    this._setupRing,
  ]) : _now = now ?? DateTime.now,
       super(const CriticalAlarmState()) {
    current = this;
    // A second incident can open while the screen is already up. The shared
    // list is where every other screen and the push binding write, so listening
    // here is how the alarm screen hears about it without asking the server.
    _incidentsSub = _incidents?.stream.listen(_onIncidentsChanged);
  }

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

  /// Whether the user has owned a topic, a local read. The demo celebration
  /// offers "Create your first topic" only while the answer is no. Absent
  /// reads as no.
  final Future<bool> Function()? _hasOwnedTopic;

  /// The incidents the server opened for setup's test alarm, read from the
  /// phone. Empty when none was sent. Absent reads as none.
  final Set<String> Function()? _setupTestIncidentIds;

  /// Whether the setup flow the user is in has the real ring step. Absent
  /// reads as no, which is the first shipped order.
  final bool Function()? _setupFlowHasRealRing;

  /// Ends one setup test on the server. Absent in tests that never do.
  final EndSetupTestUsecase? _endSetupTest;

  /// Where the phone keeps the alarm the user's first hook-up message set
  /// off, while its own acknowledged screen is owed. Absent reads as none.
  final SetupTestRing? _setupRing;

  final DateTime Function() _now;

  /// The cubit the alarm screen is showing right now, or null when the screen
  /// is not up. The push binding reads it to hand a tapped incident id to the
  /// screen already on the display instead of navigating to a new one.
  static CriticalAlarmCubit? current;

  /// Redraws the ringing line. Null whenever nothing is ringing.
  Timer? _ticker;

  /// The subscription to the shared incident list. Cancelled on [close] so a
  /// cubit that outlives its screen does not try to emit after it is closed.
  StreamSubscription<IncidentsState>? _incidentsSub;

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
    String? title,
    String? body,
  }) async {
    final cardTitle = title ?? state.title;
    final cardBody = body ?? state.body;
    try {
      await _alarm?.cancelAlarm(
        incidentId,
        handOverToStatusCard: handOverToStatusCard,
        // The acked card is built natively, with no engine and no network, so
        // it only knows what it is handed. Without these it read "Critical
        // incident" while the screen behind it named the topic.
        title: cardTitle.isEmpty ? null : cardTitle,
        body: cardBody.isEmpty ? null : cardBody,
      );
    } on Object catch (_) {
      // Nothing to do. The ack below is what the server cares about.
    }
  }

  /// Tells the native side this incident is acknowledged here. Never throws,
  /// for the same reason [_silence] does not.
  Future<void> _markAcked(String incidentId) async {
    try {
      await _alarm?.markAcked(incidentId);
    } on Object catch (_) {
      // Nothing to do. The ack below is what the server cares about.
    }
  }

  /// Silence, and nothing else.
  ///
  /// The person wants the noise to stop; they have not said they are up. The
  /// incident stays open, the phone sets its own next ring at
  /// `now + repeat_interval_s` for the same id, and the server keeps repeating
  /// too. Only [acknowledge] ends the loop.
  ///
  /// The demo alarm has no incident on the server, so it is silenced and left
  /// alone: the native side answers false for it and no re-arm is set.
  Future<void> silence() async {
    final incidentId = state.incident?.id;
    if (incidentId == null || incidentId.isEmpty) {
      await silenceThisPhone();
      return;
    }
    int? seconds;
    try {
      seconds = await _alarm?.rearmAlarm(incidentId);
    } on Object catch (_) {
      // A missing or unhappy channel must not leave the screen stuck. The
      // server repeat is still the backstop.
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        feedbackMessage: seconds == null
            ? null
            : LocaleKeys.critical_alarm_silenced_message.tr(
                namedArgs: {'seconds': '$seconds'},
              ),
        clearFeedback: seconds == null,
      ),
    );
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

  /// What this phone can promise for a ring, so the demo message never says
  /// "through silent mode" on an iPhone that cannot do it.
  Future<RingClaim> _ringClaim() async {
    try {
      final authorization = await _alarm?.authorizationStatus();
      return authorization == null
          ? RingClaim.alarm
          : RingClaim.forPhone(authorization);
    } on Object catch (_) {
      return RingClaim.alarm;
    }
  }

  Future<void> load({String? incidentId}) async {
    _stopRingTicker();
    emit(const CriticalAlarmState(status: CriticalAlarmStatus.loading));
    // Only a setup test needs to know where setup stands: the phone-only
    // alarm, or any alarm while a server-sent test is on record. A real
    // alarm outside setup reads nothing extra on its way to the screen.
    //
    // Nothing here may stop the alarm from loading. A read that throws is
    // taken as "not a setup test", and the incident is loaded all the same.
    try {
      final setupTestIds = _setupTestIncidentIds?.call() ?? const <String>{};
      if (incidentId == 'inc_demo' || setupTestIds.isNotEmpty) {
        // Read before the screen is drawn, so the exits never flash the
        // onboarding pair at someone who only re-tested from Settings.
        final done = await _onboardingCompleted?.call(const NoParams());
        if (isClosed) return;
        final hasOwnedTopic = await _hasOwnedTopic?.call() ?? false;
        if (isClosed) return;
        emit(
          state.copyWith(
            isOnboardingDone: done?.getOrNull() ?? false,
            hasOwnedTopic: hasOwnedTopic,
            setupTestIncidentIds: setupTestIds,
            setupFlowHasRealRing: _setupFlowHasRealRing?.call() ?? false,
          ),
        );
      }
    } on Object catch (_) {
      if (isClosed) return;
    }
    if (incidentId == 'inc_demo') {
      final now = DateTime.now();
      final claim = await _ringClaim();
      if (isClosed) return;
      _applyIncident(
        Incident(
          id: 'inc_demo',
          topic: 'demo-topic',
          openedAt: now,
          messages: [
            Message(
              id: 'msg_demo',
              topic: 'demo-topic',
              title: LocaleKeys.critical_alarm_demo_title.tr(),
              message: claim == RingClaim.timeSensitive
                  ? LocaleKeys.critical_alarm_demo_body_time_sensitive.tr()
                  : LocaleKeys.critical_alarm_demo_body.tr(),
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
      result.fold(
        (incident) => _applyIncident(
          incident,
          openIncidents: incident.isOpen ? [incident] : const <Incident>[],
        ),
        _showFailure,
      );
      return;
    }
    final result = await _getIncidents(const GetIncidentsParams(state: 'open'));
    result.fold((incidents) {
      final open = _newestFirst(incidents.where((i) => i.isOpen));
      if (open.isEmpty) {
        emit(const CriticalAlarmState());
      } else {
        _applyIncident(open.first, openIncidents: open);
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

  /// Shows [incidentId] instead of the newest. Used when the user taps the
  /// second notification while the screen is up, and when they pick a row in
  /// the "other alarms" sheet. The list keeps its newest-first order; only
  /// what is on screen changes.
  void select(String incidentId) {
    final match = state.openIncidents
        .where((i) => i.id == incidentId)
        .firstOrNull;
    if (match == null || state.incident?.id == incidentId) return;
    _applyIncident(match);
  }

  /// Open incidents, newest first by server time. A null [Incident.openedAt]
  /// sorts last, so a page the server never dated cannot jump the queue.
  List<Incident> _newestFirst(Iterable<Incident> incidents) {
    final list = incidents.toList()
      ..sort((a, b) {
        final at = a.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return list;
  }

  /// The shared list changed. A new open incident takes over the screen; a
  /// list that only shrank leaves the shown incident alone, because an
  /// acknowledge or a close already moves the screen itself.
  void _onIncidentsChanged(IncidentsState incidents) {
    if (isClosed) return;
    final open = _newestFirst(incidents.openIncidents);
    final previousIds = state.openIncidents.map((i) => i.id).toSet();
    final hasNew = open.any((i) => !previousIds.contains(i.id));
    if (hasNew) {
      _applyIncident(open.first, openIncidents: open);
    } else {
      emit(state.copyWith(openIncidents: open));
    }
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
    // Text of the incident being answered, read before the screen swaps to
    // the next one so the handed-over card names the right incident.
    final ackTitle = state.title;
    final ackBody = state.body;
    final ack = _incidents?.acknowledgeNow(incident);

    // What is still open once this one is acknowledged, newest first.
    final remaining = _newestFirst(
      state.openIncidents.where((i) => i.id != targetId),
    );

    if (remaining.isNotEmpty) {
      // Another incident is still ringing. Swap to it and stay on the ringing
      // layout, so one tap answers one incident and nothing is lost.
      _applyIncident(remaining.first, openIncidents: remaining);
    } else {
      _showAcknowledged(
        ack?.guess ??
            incident.copyWith(state: IncidentStates.acked, ackedAt: _now()),
        openIncidents: remaining,
      );
    }

    // Silence next, still before anything goes on the wire. The person
    // pressed Stop, so the noise is over whatever the server says: a slow or
    // refused ack must not keep it ringing.
    await _silence(
      targetId,
      handOverToStatusCard: true,
      title: ackTitle,
      body: ackBody,
    );

    // Marked before the send, so a repeat push that lands while the request
    // is in flight does not ring. A reopen clears it again.
    await _markAcked(targetId);

    final result = await _acknowledgeIncident(targetId);
    if (isClosed) return;

    result.fold(
      (updatedIncident) {
        // The server's own copy, which carries the real acked_at. Only the
        // acknowledged screen reads it; a swap keeps the next one ringing.
        _incidents?.applyIncident(updatedIncident);
        if (remaining.isEmpty) {
          _showAcknowledged(updatedIncident, openIncidents: remaining);
        }
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

  /// Says whether [incident] is still the first ring of the alarm the
  /// user's first hook-up message set off, and keeps the phone's record in
  /// step: what the incident looked like is saved the first time, and the
  /// record is forgotten the moment the incident is anything else (a
  /// reopen, a joined message, a close).
  ///
  /// Returns the id the setup acknowledged screen applies to, or null.
  /// Local reads and unawaited local writes only, and it never throws:
  /// nothing here may slow an alarm down or stop it showing.
  String? _firstToolIdFor(Incident incident) {
    if (state.isPreview) return state.firstToolIncidentId;
    final ring = _setupRing;
    if (ring == null) return null;
    try {
      final held = ring.firstTool;
      switch (firstToolVerdictFor(held: held, incident: incident)) {
        case FirstToolVerdict.notIt:
          return null;
        case FirstToolVerdict.over:
          unawaited(_quietly(ring.forgetFirstTool));
          return null;
        case FirstToolVerdict.firstRing:
          if (held != null && !held.wasSeen) {
            unawaited(
              _quietly(
                () => ring.noteFirstToolSeen(
                  openedAt: incident.openedAt,
                  lastMessageAt: incident.lastMessageAt,
                ),
              ),
            );
          }
          if (incident.isAcked && !(held?.wasAcked ?? true)) {
            unawaited(_quietly(ring.noteFirstToolAcked));
          }
          return incident.id;
      }
    } on Object catch (_) {
      return null;
    }
  }

  /// Runs a write to the phone that must never surface as an error.
  static Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (_) {
      // The phone would not save it. The alarm goes on regardless.
    }
  }

  /// The acknowledged screen, for a guess and for the server's answer alike.
  void _showAcknowledged(
    Incident incident, {
    FaceState face = FaceState.acked,
    List<Incident>? openIncidents,
  }) {
    _stopRingTicker();
    final firstToolId = _firstToolIdFor(incident);
    final ackMsg = LocaleKeys.critical_alarm_acknowledged_message.tr(
      namedArgs: {'time': _formatTime(incident.ackedAt ?? _now())},
    );
    emit(
      state.copyWith(
        status: CriticalAlarmStatus.acknowledged,
        incident: incident,
        openIncidents: openIncidents ?? state.openIncidents,
        isAcknowledged: true,
        isAcknowledging: false,
        severityMode: SeverityMode.ack,
        faceState: face,
        isLive: false,
        word: LocaleKeys.critical_alarm_stage_word_acknowledged.tr(),
        subtext: ackMsg,
        feedbackMessage: ackMsg,
        clearError: true,
        firstToolIncidentId: firstToolId,
        clearFirstTool: firstToolId == null,
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
          ringTimeSpoken: spokenRingTime(_ringingDuration(incident)),
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
    unawaited(_incidentsSub?.cancel());
    if (identical(current, this)) current = null;
    return super.close();
  }

  /// How long this incident has been ringing, right now. The string used to
  /// be the literal "Ringing 2 min 14 s.", a mockup value that shipped, so the
  /// screen claimed the same duration whatever was happening.
  String _ringingFor(Incident incident) =>
      formatRingDuration(_ringingDuration(incident));

  /// The one source of the ring time: the server's `opened_at` against the
  /// clock. The acknowledged screen counts from the same start.
  Duration _ringingDuration(Incident incident) {
    final openedAt = incident.openedAt;
    if (openedAt == null) return Duration.zero;
    return _now().difference(openedAt);
  }

  /// A VoiceOver magic tap, the two-finger double tap. It does what the
  /// "I'm up" button does, through the same [acknowledge], and only while
  /// the ringing screen is the one in front.
  ///
  /// Answers whether it acknowledged. Anything else is left alone: a screen
  /// that is loading, already acknowledged, mid-acknowledge, or covered by
  /// another screen or a sheet.
  Future<bool> acknowledgeFromMagicTap({
    required bool isRingingScreenInFront,
  }) async {
    if (!isRingingScreenInFront) return false;
    if (state.status != CriticalAlarmStatus.ringing ||
        state.isAcknowledged ||
        state.isAcknowledging ||
        state.incident == null) {
      return false;
    }
    await acknowledge();
    return true;
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
        // Same rule as acknowledge: an incident still open takes over, and the
        // closed screen only appears once nothing is left ringing.
        final remaining = _newestFirst(
          state.openIncidents.where((i) => i.id != incidentId),
        );
        if (remaining.isNotEmpty) {
          _applyIncident(remaining.first, openIncidents: remaining);
        } else {
          emit(
            state.copyWith(
              status: CriticalAlarmStatus.closed,
              incident: closedIncident,
              openIncidents: remaining,
              word: LocaleKeys.critical_alarm_stage_word_closed.tr(),
              severityMode: SeverityMode.none,
              faceState: FaceState.calm,
              isLive: false,
            ),
          );
        }
      },
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
      },
    );
  }

  /// Continue, on the acknowledged screen of a server-sent setup test:
  /// ends every test incident of this setup run, so none of them can ring
  /// again later looking like a real alarm.
  ///
  /// [incidentId] is the test the screen was showing when the user tapped.
  /// Nothing happens unless that is still the incident on screen and it is
  /// one of the stored setup tests, so a real alarm that took the screen
  /// over a moment before the tap is never silenced or closed here.
  ///
  /// Answers whether the screen may move on. False when it did nothing, and
  /// false when a real alarm took the screen over while the server was
  /// being asked: the user stays with that alarm.
  ///
  /// The screen is not redrawn. Only the named ids are silenced and closed.
  Future<bool> closeSetupTests(String incidentId) async {
    // A copy: a close that fails takes its id out of the stored set.
    final ids = {...?_setupTestIncidentIds?.call()};
    if (state.incident?.id != incidentId || !ids.contains(incidentId)) {
      return false;
    }
    // The one on screen first. The others are earlier tries of the same
    // run, which the user never answered.
    for (final id in [incidentId, ...ids.where((id) => id != incidentId)]) {
      try {
        await _alarm?.cancelAlarm(id, handOverToStatusCard: false);
      } on Object catch (_) {
        // Nothing to do. The close below is what the server cares about.
      }
      await _endSetupTest?.call(
        id,
        isAcknowledged: id == incidentId,
        onClosed: (closed) => _incidents?.applyIncident(closed),
      );
      if (isClosed) return false;
    }
    return state.incident?.id == incidentId;
  }

  /// The one button on the acknowledged screen of the first tool alarm:
  /// ends that incident, so its desk timer cannot ring the phone again ten
  /// minutes after setup said it was done.
  ///
  /// [incidentId] is the alarm the button was drawn for. Nothing happens
  /// unless it is still the incident on screen and is the first tool alarm
  /// on record, so no other incident is ever silenced or closed here. A
  /// real alarm that took the screen over a moment before the tap is left
  /// exactly as it is.
  ///
  /// Answers whether the screen may leave for Home. False when it did
  /// nothing, and false when another alarm took the screen over while the
  /// server was being asked: the user stays with that alarm.
  Future<bool> finishFirstToolAlarm(String incidentId) async {
    if (state.incident?.id != incidentId || !state.isFirstToolAlarm) {
      return false;
    }
    // A developer's look at the screen. Nothing is sent or saved.
    if (state.isPreview) return true;
    final ring = _setupRing;
    String? heldId;
    try {
      heldId = ring?.firstToolIncidentId;
    } on Object catch (_) {
      heldId = null;
    }
    if (heldId != incidentId) {
      // The phone no longer holds it, so this is not that alarm any more.
      // The setup screen has one button and it just did nothing: the
      // normal acknowledged screen takes its place, with every control.
      emit(state.copyWith(clearFirstTool: true));
      return false;
    }
    try {
      await _alarm?.cancelAlarm(incidentId, handOverToStatusCard: false);
    } on Object catch (_) {
      // Nothing to do. The close below is what the server cares about.
    }
    await _endSetupTest?.call(
      incidentId,
      isAcknowledged: true,
      onClosed: (closed) => _incidents?.applyIncident(closed),
    );
    // Done with, whether the server closed it or not: a close that failed
    // leaves a real incident, which rings and is answered like any other.
    if (ring != null) await _quietly(ring.forgetFirstTool);
    if (isClosed) return false;
    return state.incident?.id == incidentId;
  }

  /// Puts the screen on the acknowledged state of a made-up first tool
  /// alarm, so a developer can look at it. Nothing is sent or saved, and
  /// its button reaches no server.
  void previewFirstToolAlarm() {
    const id = 'inc_preview';
    final now = _now();
    _stopRingTicker();
    emit(
      CriticalAlarmState(
        status: CriticalAlarmStatus.acknowledged,
        incident: Incident(
          id: id,
          topic: 'my-topic',
          state: IncidentStates.acked,
          openedAt: now.subtract(const Duration(seconds: 6)),
          ackedAt: now,
        ),
        topic: 'my-topic',
        isAcknowledged: true,
        severityMode: SeverityMode.ack,
        faceState: FaceState.acked,
        isOnboardingDone: true,
        firstToolIncidentId: id,
        isPreview: true,
      ),
    );
  }

  void _applyIncident(Incident incident, {List<Incident>? openIncidents}) {
    _stopRingTicker();
    final open = openIncidents ?? state.openIncidents;
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

    // Hand the text to the notification extension. It has no way of its own to
    // read what the app loaded, so without this every repeat push on this
    // incident costs another `GET /v1/incidents/{id}`. Only a real message is
    // worth keeping: caching a fallback line would hide the real text.
    if (firstMsg != null && incident.id != 'inc_demo') {
      final cached = _alarm?.cacheIncidentContent(
        incidentId: incident.id,
        title: title,
        body: body,
        tags: firstMsg.tags,
        click: firstMsg.click,
        topic: topic,
        lastMessageAt: incident.lastMessageAt == null
            ? null
            : incident.lastMessageAt!.millisecondsSinceEpoch ~/ 1000,
      );
      if (cached != null) unawaited(cached);
    }

    // Read once, before anything is drawn: the same incident id can be a
    // later ring, and then it is an alarm like any other.
    final firstToolId = _firstToolIdFor(incident);

    emit(
      state.copyWith(
        openIncidents: open,
        firstToolIncidentId: firstToolId,
        clearFirstTool: firstToolId == null,
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
          openIncidents: open,
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
          openIncidents: open,
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
          openIncidents: open,
          topic: topic,
          title: title,
          body: body,
          word: LocaleKeys.critical_alarm_stage_word_critical.tr(),
          subtext: LocaleKeys.critical_alarm_stage_sub_ringing.tr(
            namedArgs: {'duration': _ringingFor(incident)},
          ),
          ringTimeSpoken: spokenRingTime(_ringingDuration(incident)),
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
