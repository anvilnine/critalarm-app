import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for TopicDetailScreen.
///
/// The topic and its incidents come from the app-level cubits, so this screen
/// shows the same thing Home does without fetching either again.
class TopicDetailCubit extends Cubit<TopicDetailState> {
  TopicDetailCubit(
    this._incidents,
    this._topics,
    this._updateTopic,
    this._incidentRepository, {
    this.alarm,
    this.identityStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const TopicDetailState());

  final IncidentsCubit _incidents;
  final TopicsCubit _topics;
  final UpdateTopicUsecase _updateTopic;

  /// Still here for the message poll and for acknowledging, which are not
  /// list reads.
  final IncidentRepository _incidentRepository;

  /// Null off iOS, where there is no AlarmKit and nothing to gate on.
  final AlarmHost? alarm;

  /// Says which tier the account is on, so this screen shows the same window
  /// History does. Null in tests, and then nothing is hidden.
  final DeviceIdentityStore? identityStore;

  final DateTime Function() _now;

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

  List<Incident>? _builtFromIncidents;
  List<Topic>? _builtFromTopics;

  int _buildId = 0;

  /// The oldest message this tier may show, or null for everything held.
  /// Same rule as History (api.md §4.2), read from one place.
  Future<DateTime?> _lowerBound() async {
    final identity = await identityStore?.readOrCreate();
    if (identity == null) return null;
    return HistoryWindow.lowerBound(
      tier: identity.tier,
      historyDays: identity.caps.historyDays ?? 7,
      now: _now(),
    );
  }

  static List<Message> _insideWindow(List<Message> messages, DateTime? bound) {
    if (bound == null) return messages;
    final seconds = bound.toUtc().millisecondsSinceEpoch ~/ 1000;
    return [
      for (final message in messages)
        if (message.time >= seconds) message,
    ];
  }

  /// An acknowledge is still on the wire. Separate from
  /// [TopicDetailState.isMarkingAsRead], which is only the spinner on the
  /// button and goes off as soon as the guess is on screen.
  bool _acking = false;

  /// While this screen is making its own change, an upstream emission is
  /// ignored: what the change is about to emit is newer than anything a
  /// rebuild would derive halfway through it.
  bool get _busy =>
      _acking || state.isMarkingAsRead || state.isUpdatingCritical;

  Future<void> load(String topicName) async {
    _incidentsSub ??= _incidents.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
    _topicsSub ??= _topics.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
    // A different topic than last time, so nothing drawn so far counts.
    _builtFromIncidents = null;
    _builtFromTopics = null;

    emit(
      state.copyWith(
        status: TopicDetailStatus.loading,
        topicName: topicName,
      ),
    );

    final authorization = await alarm?.authorizationStatus();
    if (authorization != null) {
      emit(state.copyWith(alarm: authorization));
    }

    await Future.wait([_incidents.ensureLoaded(), _topics.ensureLoaded()]);
    await _rebuildIfChanged();
  }

  /// Draws [example] and nothing else: no server, no updates. The tour uses
  /// it for a topic that only exists to be shown.
  void showExample(TopicDetailState example) => emit(example);

  /// Pull-to-refresh. Asks the shared lists again, where [load] only makes
  /// sure they are there. True when both loaded, so the face can say so.
  Future<bool> refresh() async {
    final authorization = await alarm?.authorizationStatus();
    if (isClosed) return false;
    if (authorization != null) {
      emit(state.copyWith(alarm: authorization));
    }

    await Future.wait([_incidents.refresh(), _topics.refresh()]);
    await _rebuildIfChanged();
    return _incidents.state.status != AppDataStatus.failure &&
        _topics.state.status != AppDataStatus.failure;
  }

  @override
  Future<void> close() async {
    await _incidentsSub?.cancel();
    await _topicsSub?.cancel();
    return super.close();
  }

  Future<void> _rebuildIfChanged() async {
    if (isClosed || _busy || state.topicName.isEmpty) return;
    final incidents = _incidents.state;
    final topics = _topics.state;

    final failure = incidents.status == AppDataStatus.failure
        ? incidents.errorMessage
        : topics.status == AppDataStatus.failure
        ? topics.errorMessage
        : null;
    if (failure != null) {
      _builtFromIncidents = null;
      _builtFromTopics = null;
      emit(
        state.copyWith(
          status: TopicDetailStatus.failure,
          errorMessage: failure,
        ),
      );
      return;
    }

    if (!incidents.isReady || !topics.isReady) return;
    if (identical(incidents.incidents, _builtFromIncidents) &&
        identical(topics.topics, _builtFromTopics)) {
      return;
    }
    _builtFromIncidents = incidents.incidents;
    _builtFromTopics = topics.topics;

    final id = ++_buildId;
    final next = await _buildState(state.topicName);
    if (isClosed || id != _buildId) return;
    emit(next);
  }

  Future<TopicDetailState> _buildState(String topicName) async {
    final topic = _topics.state.named(topicName);
    if (topic == null) {
      return state.copyWith(
        status: TopicDetailStatus.failure,
        errorMessage: LocaleKeys.api_errors_not_found.tr(),
      );
    }

    final pollResult = await _incidentRepository.pollMessages(
      topicName,
      poll: 1,
    );
    if (pollResult.isError()) {
      return state.copyWith(
        status: TopicDetailStatus.failure,
        errorMessage: pollResult.exceptionOrNull()?.message,
      );
    }
    final polled = _insideWindow(
      pollResult.getOrNull() ?? <Message>[],
      await _lowerBound(),
    );

    final openIncidents = _incidents.state
        .forTopic(topicName)
        .where((i) => i.state == 'open')
        .toList();

    final hasCrit =
        topic.critical &&
        openIncidents.any((i) => i.messages.any((m) => m.priority == 5));
    final hasHigh =
        openIncidents.any((i) => i.messages.any((m) => m.priority == 4)) ||
        polled.any((m) => m.priority == 4);

    SeverityMode severity;
    FaceState face;
    String word;

    if (hasCrit) {
      severity = SeverityMode.crit;
      face = FaceState.alarmed;
      word = LocaleKeys.topic_detail_stage_word_critical.tr();
    } else if (hasHigh) {
      severity = SeverityMode.high;
      face = FaceState.worried;
      word = LocaleKeys.topic_detail_stage_word_warning.tr();
    } else {
      severity = SeverityMode.none;
      face = FaceState.calm;
      word = LocaleKeys.topic_detail_stage_word_clear.tr();
    }

    final priorityLabel = hasCrit
        ? 'critical'
        : hasHigh
        ? 'high'
        : 'default';
    final messages = polled.reversed
        .map(
          (m) => TopicDetailMessageItem(
            title: m.title ?? m.topic,
            timestamp: DateFormat('MMM d HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(m.time * 1000).toLocal(),
            ),
            body: m.message,
            source: m.tags.join(', '),
            isHigh: m.priority == 4,
          ),
        )
        .toList();
    final count = messages.length;
    // A topic with nothing in it gets its own line. The counted form reads
    // as nonsense at zero.
    final subText = count == 0
        ? LocaleKeys.topic_detail_stage_sub_empty.tr(
            namedArgs: {'priority': priorityLabel},
          )
        : LocaleKeys.topic_detail_stage_sub.plural(
            count,
            namedArgs: {
              'priority': priorityLabel,
              'count': count.toString(),
            },
          );

    return state.copyWith(
      status: TopicDetailStatus.success,
      topicName: topic.name,
      critical: topic.critical,
      severity: severity,
      faceState: face,
      word: word,
      subText: subText,
      messages: messages,
      openIncidentIds: openIncidents.map((i) => i.id).toList(),
      clearError: true,
    );
  }

  Future<void> toggleCriticalDelivery({required bool isCritical}) async {
    emit(state.copyWith(isUpdatingCritical: true, clearError: true));

    final result = await _updateTopic(
      UpdateTopicParams(name: state.topicName, critical: isCritical),
    );

    result.fold(
      (updatedTopic) {
        // Every other screen reads the same topic list, so the switch lands
        // there too rather than only here.
        _topics.applyTopic(updatedTopic);
        _markUpstreamAccountedFor();
        emit(
          state.copyWith(
            isUpdatingCritical: false,
            critical: updatedTopic.critical,
          ),
        );
      },
      (failure) {
        _markUpstreamAccountedFor();
        emit(
          state.copyWith(
            isUpdatingCritical: false,
            errorMessage: failure.message,
            capReached: CapReached.fromFailure(failure),
          ),
        );
      },
    );
  }

  /// Acknowledge every open incident on this topic, and stop the noise first.
  ///
  /// The phone goes quiet before any request is made. A slow server, a dead
  /// network or a refused ack must never leave the alarm ringing: the person
  /// pressed the button, so the sound is over whatever the server says next.
  Future<void> markAsRead() async {
    _acking = true;
    emit(state.copyWith(isMarkingAsRead: true));

    // Every stop names its incident. Asking for "whatever is ringing" was how
    // pressing Stop on topic X silenced an unacknowledged incident on topic Y:
    // Android runs one alarm service for the whole app.
    await _silence(state.openIncidentIds);

    // What the page looked like while it was ringing. Whatever the server
    // will not take goes back to this.
    final ringing = state;
    final targets = state.openIncidentIds.toList();

    // The page and every other screen move now, before anything is sent.
    final guesses = _guessAcked(targets);
    _markUpstreamAccountedFor();
    emit(
      state.copyWith(
        isMarkingAsRead: false,
        severity: SeverityMode.none,
        faceState: FaceState.calm,
        word: LocaleKeys.topic_detail_stage_word_clear.tr(),
        messages: state.messages.map((m) => m.copyWith(isHigh: false)).toList(),
        openIncidentIds: const [],
        clearError: true,
      ),
    );

    final stillOpen = await _sendAcks(guesses);
    if (isClosed) return;

    // An incident can open between this page being drawn and Stop being
    // pressed, so catch up and take those too.
    await _incidents.refresh();
    if (isClosed) return;
    final openedLate = _incidents.state
        .forTopic(ringing.topicName)
        .where((i) => i.isOpen && !guesses.containsKey(i.id))
        .map((i) => i.id)
        .toList();
    if (openedLate.isNotEmpty) {
      await _silence(openedLate);
      stillOpen.addAll(await _sendAcks(_guessAcked(openedLate)));
      if (isClosed) return;
    }

    _acking = false;
    _markUpstreamAccountedFor();

    // Clearing the list on a failed ack told the user the page was handled
    // and took the button away, while the incident was still open and free to
    // ring again.
    if (stillOpen.isNotEmpty) {
      emit(
        ringing.copyWith(
          isMarkingAsRead: false,
          openIncidentIds: stillOpen,
          errorMessage: LocaleKeys.topic_detail_ack_failed.tr(),
        ),
      );
    }
  }

  /// Marks each of [ids] acknowledged in the shared list, before any request
  /// goes out. Home, History and search all read that list, so they move on
  /// the tap too.
  Map<String, OptimisticAck> _guessAcked(Iterable<String> ids) {
    final guesses = <String, OptimisticAck>{};
    for (final id in ids) {
      final incident = _incidents.state.incidents
          .where((i) => i.id == id)
          .firstOrNull;
      if (incident == null) continue;
      guesses[id] = _incidents.acknowledgeNow(incident);
    }
    return guesses;
  }

  /// Sends one acknowledge per guess and returns the ids the server would not
  /// take, having put each of those back in the shared list. A 409 means it
  /// was already acknowledged somewhere else, which is a success here.
  Future<List<String>> _sendAcks(Map<String, OptimisticAck> guesses) async {
    final stillOpen = <String>[];
    final acked = <Incident>[];
    for (final entry in guesses.entries) {
      final result = await _incidentRepository.ackIncident(entry.key);
      final failure = result.exceptionOrNull();
      if (failure == null) {
        final incident = result.getOrNull();
        if (incident != null) acked.add(incident);
        continue;
      }
      if (failure is ApiFailure && failure.statusCode == 409) continue;
      stillOpen.add(entry.key);
      _incidents.revert(entry.value);
    }
    // The server's own copies, which carry the real acked_at.
    _incidents.applyIncidents(acked);
    return stillOpen;
  }

  /// This screen has just written the state it wants from lists it changed
  /// itself, so the emission those changes are about to cause must not come
  /// back round and overwrite it.
  void _markUpstreamAccountedFor() {
    _builtFromIncidents = _incidents.state.incidents;
    _builtFromTopics = _topics.state.topics;
  }

  /// Stop the local alarm for each incident. Never throws: a platform channel
  /// that is missing or unhappy must not stop the acknowledge from going out.
  ///
  /// Every caller here is acknowledging, so each incident stays open and its
  /// ringing card hands over to the acked one.
  Future<void> _silence(Iterable<String> incidentIds) async {
    final host = alarm;
    if (host == null) return;
    for (final id in incidentIds) {
      try {
        await host.cancelAlarm(id, handOverToStatusCard: true);
      } on Object catch (_) {
        // Nothing to do. The ack below is what the server cares about.
      }
    }
  }
}
