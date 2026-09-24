import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/home_face_rule.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for HomeScreen.
///
/// Topics and incidents come from the app-level cubits, so opening this screen
/// does not repeat a fetch another screen already made, and an acknowledge
/// anywhere lands here without a pop or a resume.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._incidents,
    this._topics,
    this._incidentRepository, [
    this._messageSync,
    this._getConnection,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 5),
  ]) : _now = clock ?? DateTime.now,
       super(const HomeState());

  final IncidentsCubit _incidents;
  final TopicsCubit _topics;

  /// Still here for the per-topic message poll, which is the one thing on this
  /// screen that is neither an incident nor a topic.
  final IncidentRepository _incidentRepository;

  /// Catches up on priority 1-3, which push never delivers (api.md 1.7).
  final MessageSyncService? _messageSync;

  /// Tells a load that failed because no server is set up from a load that
  /// failed because the server that is set up did not answer. Topics live on
  /// the server, so the two need different screens.
  final GetConnectionUsecase? _getConnection;

  final DateTime Function() _now;

  /// How often the face is worked out again from the lists already held, so a
  /// countdown or a face that only lasts a while moves without a reload. A
  /// test passes something short so it does not have to wait.
  final Duration tick;

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

  Timer? _timer;
  List<Incident>? _lastIncidents;
  List<Topic>? _lastTopics;
  Set<String>? _lastWarningTopics;
  Map<String, int>? _lastPriorities;

  /// The lists this screen was last built from. An upstream change that leaves
  /// them alone, such as a refresh starting, is not worth polling every topic
  /// for again.
  List<Incident>? _builtFromIncidents;
  List<Topic>? _builtFromTopics;

  /// Only the newest build may emit. An earlier one that finishes late would
  /// put a stale list back on screen.
  int _buildId = 0;

  /// Pull-to-refresh. Asks the shared lists again; the rebuild follows from
  /// what they answer. True when both lists loaded, so the face can say so.
  Future<bool> refresh() async {
    await Future.wait([_incidents.refresh(), _topics.refresh()]);
    await _rebuildIfChanged();
    return _incidents.state.status != AppDataStatus.failure &&
        _topics.state.status != AppDataStatus.failure;
  }

  Future<void> load() async {
    _listenToAppState();
    if (state.topicItems.isEmpty) {
      emit(state.copyWith(status: HomeStatus.loading));
    }
    await Future.wait([_incidents.ensureLoaded(), _topics.ensureLoaded()]);
    await _rebuildIfChanged();
  }

  void _listenToAppState() {
    _incidentsSub ??= _incidents.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
    _topicsSub ??= _topics.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    await _incidentsSub?.cancel();
    await _topicsSub?.cancel();
    return super.close();
  }

  void _syncTimer(bool needsTick) {
    if (needsTick) {
      _timer ??= Timer.periodic(tick, (_) {
        if (isClosed) return;
        final incidents = _lastIncidents;
        final topics = _lastTopics;
        final warningTopics = _lastWarningTopics;
        final priorities = _lastPriorities;
        if (incidents == null ||
            topics == null ||
            warningTopics == null ||
            priorities == null) {
          return;
        }
        final result = resolveHomeFace(
          topics: topics,
          incidents: incidents,
          warningTopics: warningTopics,
          now: _now(),
        );
        final items = _buildTopicItems(result.rows, topics, priorities);
        emit(
          state.copyWith(
            faceState: result.hero.faceState,
            word: result.hero.word,
            subText: result.hero.subText,
            severity: result.hero.severity,
            ringingIncidentId: result.hero.ringingIncidentId,
            clearRinging: result.hero.ringingIncidentId == null,
            topicItems: items,
          ),
        );
        _syncTimer(result.needsTick);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _rebuildIfChanged() async {
    if (isClosed) return;
    final incidents = _incidents.state;
    final topics = _topics.state;

    final failure = incidents.status == AppDataStatus.failure
        ? incidents.errorMessage
        : topics.status == AppDataStatus.failure
        ? topics.errorMessage
        : null;
    if (failure != null) {
      // Forget what was drawn, so the next good answer builds again even if
      // the lists come back unchanged.
      _builtFromIncidents = null;
      _builtFromTopics = null;
      // A build that is still running belongs to the answer before this one.
      // Retire it, or its success lands on top of this failure and the screen
      // goes back to smiling at a list it can no longer reach.
      final id = ++_buildId;
      final next = await _failureState(failure);
      if (isClosed || id != _buildId) return;
      emit(next);
      return;
    }

    // Half a screen is worse than the one it would replace, so wait for both.
    if (!incidents.isReady || !topics.isReady) return;
    if (identical(incidents.incidents, _builtFromIncidents) &&
        identical(topics.topics, _builtFromTopics)) {
      return;
    }
    _builtFromIncidents = incidents.incidents;
    _builtFromTopics = topics.topics;

    final id = ++_buildId;
    final next = await _buildState(incidents.incidents, topics.topics, id);
    if (isClosed || id != _buildId) return;
    emit(next);
  }

  /// The screen to show when the lists did not load. There are two of them,
  /// because a load fails for two different reasons.
  ///
  /// No server set up at all: the rows on screen came from a server the user
  /// has left, and nothing on the phone re-creates them, so drop them. This is
  /// a setup problem, not an alarm, so the severity stays at none and the red
  /// card above the stage carries the message.
  ///
  /// A server is set up but did not answer: the rows are still the user's,
  /// only old. Keep them, mark them old, and say when they were last true.
  Future<HomeState> _failureState(String? message) async {
    if (!await _hasServer()) {
      return state.copyWith(
        status: HomeStatus.failure,
        errorMessage: message,
        topicItems: const [],
        faceState: FaceState.watching,
        word: LocaleKeys.home_stage_word_no_server.tr(),
        subText: LocaleKeys.home_stage_sub_no_server.tr(),
        severity: SeverityMode.none,
        clearRinging: true,
        isStale: false,
        clearLastKnownGood: true,
        hasServer: false,
      );
    }

    final seenAt = state.lastKnownGoodAt;
    return state.copyWith(
      status: HomeStatus.failure,
      errorMessage: message,
      faceState: FaceState.watching,
      word: LocaleKeys.home_stage_word_unreachable.tr(),
      // No last good time means the list never loaded here, so there is
      // nothing old on screen to put a time on.
      subText: seenAt == null
          ? LocaleKeys.home_load_failed.tr()
          : LocaleKeys.home_stage_sub_unreachable.tr(
              namedArgs: {'time': DateFormat.Hm().format(seenAt.toLocal())},
            ),
      severity: SeverityMode.none,
      clearRinging: true,
      isStale: seenAt != null,
      hasServer: true,
    );
  }

  /// A server counts as set up when the saved connection has a URL, the same
  /// test the home prompts use.
  Future<bool> _hasServer() async {
    final getConnection = _getConnection;
    if (getConnection == null) return true;
    final connection = (await getConnection(const NoParams())).getOrNull();
    return connection != null && connection.serverUrl.trim().isNotEmpty;
  }

  Future<HomeState> _buildState(
    List<Incident> incidents,
    List<Topic> topics,
    int id,
  ) async {
    if (topics.isEmpty) {
      _lastIncidents = incidents;
      _lastTopics = topics;
      _lastWarningTopics = const {};
      _lastPriorities = const {};
      _syncTimer(false);
      return state.copyWith(
        status: HomeStatus.success,
        topicItems: const [],
        faceState: FaceState.watching,
        word: LocaleKeys.home_stage_word_no_topics.tr(),
        subText: LocaleKeys.home_stage_sub_no_topics.tr(),
        severity: SeverityMode.none,
        clearRinging: true,
        clearError: true,
        isStale: false,
        lastKnownGoodAt: _now(),
        hasServer: true,
      );
    }

    await _messageSync?.syncAll(topics.map((t) => t.name));

    final now = _now();
    final openIncidentIds = incidents
        .where((i) => i.state == 'open')
        .map((i) => i.id)
        .toSet();

    final warningTopics = <String>{};
    final priorities = <String, int>{};
    for (final t in topics) {
      final pollResult = await _incidentRepository.pollMessages(
        t.name,
        poll: 1,
      );
      if (pollResult.isError()) {
        _builtFromIncidents = null;
        _builtFromTopics = null;
        return _failureState(pollResult.exceptionOrNull()?.message);
      }
      final msgs = pollResult.getOrNull() ?? [];
      final latest = msgs.isEmpty
          ? null
          : msgs.reduce((a, b) => a.time > b.time ? a : b);
      priorities[t.name] = latest?.priority ?? 3;
      if (msgs.any((m) {
        final isP4OrWarning =
            m.priority == 4 || (m.tags.contains('warning') && m.priority != 5);
        if (!isP4OrWarning) return false;
        if (m.incidentId != null) {
          return openIncidentIds.contains(m.incidentId);
        }
        final msgTime = DateTime.fromMillisecondsSinceEpoch(m.time * 1000);
        return now.difference(msgTime).inSeconds < 1800;
      })) {
        warningTopics.add(t.name);
      }
    }

    final result = resolveHomeFace(
      topics: topics,
      incidents: incidents,
      warningTopics: warningTopics,
      now: now,
    );

    final items = _buildTopicItems(result.rows, topics, priorities);

    // A newer build started while this one waited on the polls, so this list
    // is already out of date and the caller throws the state away. Leave the
    // lists the timer reads alone too, or its next tick draws this old list
    // over the newer one: an acknowledge answer that arrived after the close
    // painted the screen blue again.
    if (id != _buildId) return state;

    _lastIncidents = incidents;
    _lastTopics = topics;
    _lastWarningTopics = warningTopics;
    _lastPriorities = priorities;
    _syncTimer(result.needsTick);

    return state.copyWith(
      status: HomeStatus.success,
      topicItems: items,
      faceState: result.hero.faceState,
      word: result.hero.word,
      subText: result.hero.subText,
      severity: result.hero.severity,
      ringingIncidentId: result.hero.ringingIncidentId,
      clearRinging: result.hero.ringingIncidentId == null,
      clearError: true,
      isStale: false,
      lastKnownGoodAt: now,
      hasServer: true,
    );
  }

  List<HomeTopicItem> _buildTopicItems(
    List<HomeTopicRow> rows,
    List<Topic> topics,
    Map<String, int> priorities,
  ) {
    final topicByName = {for (final t in topics) t.name: t};
    return rows.map((r) {
      final t = topicByName[r.name];
      final priority = priorities[r.name] ?? 3;
      return HomeTopicItem(
        name: r.name,
        meta: r.meta,
        priority: _priority(priority),
        isQuiet: priority <= 2,
        faceState: r.faceState,
        isCrit: r.faceState == FaceState.alarmed && (t?.critical ?? false),
        isLive:
            r.faceState == FaceState.alarmed ||
            r.faceState == FaceState.worried,
        ringsThroughSilent: t?.critical ?? false,
      );
    }).toList();
  }
}

PriorityLevel _priority(int priority) => switch (priority) {
  5 => PriorityLevel.critical,
  4 => PriorityLevel.high,
  2 => PriorityLevel.low,
  1 => PriorityLevel.min,
  _ => PriorityLevel.defaultPriority,
};
