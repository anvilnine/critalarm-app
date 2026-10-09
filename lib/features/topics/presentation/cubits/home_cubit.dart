import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/home_card/home_facts.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/topic_inbox.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
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
    this._listPrefs,
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

  /// Pin, mute and read marks, kept on this phone. Null in tests that do not
  /// care, which leaves every row unpinned, unmuted and read.
  final TopicListPrefsRepository? _listPrefs;

  /// How often the state is worked out again from the lists already held, so
  /// an acknowledged alarm's countdown or a close that only lasts a while
  /// ends without a reload. A test passes something short so it does not have
  /// to wait.
  final Duration tick;

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

  Timer? _timer;
  List<Incident>? _lastIncidents;
  List<Topic>? _lastTopics;
  Set<String>? _lastWarningTopics;

  /// Epoch seconds of every message the last build saw, per topic, for the
  /// unread count. Kept so a pin or a read mark redraws without a poll.
  Map<String, List<int>>? _lastMessageTimes;
  Map<String, String>? _lastPreviews;

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
      _timer ??= Timer.periodic(tick, (_) => _repaint());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Works the screen out again from the lists already held, without a poll.
  /// [rowsOnly] leaves the facts alone, for a pin or a read mark: those change
  /// the rows and nothing else, and must not paint over a failure.
  void _repaint({bool rowsOnly = false}) {
    if (isClosed) return;
    final incidents = _lastIncidents;
    final topics = _lastTopics;
    final warningTopics = _lastWarningTopics;
    if (incidents == null || topics == null || warningTopics == null) {
      return;
    }
    final now = _now();
    final items = _buildTopicItems(
      topics,
      _lastMessageTimes ?? const {},
      _lastPreviews ?? const {},
      incidents: incidents,
      warningTopics: warningTopics,
      now: now,
    );
    if (rowsOnly) {
      // Only over a list that loaded. A failure keeps the rows it chose to
      // show, and a pin must not bring back rows it dropped.
      if (state.status != HomeStatus.success || state.isStale) return;
      emit(state.copyWith(topicItems: items));
      return;
    }
    final facts = homeFactsFrom(
      topics: topics,
      incidents: incidents,
      warningTopics: warningTopics,
      messageTimes: _lastMessageTimes ?? const {},
      now: now,
    );
    emit(
      state.copyWith(
        ringingIncidentId: facts.ringing?.incidentId,
        clearRinging: facts.ringing == null,
        topicItems: items,
        facts: facts,
      ),
    );
    _syncTimer(_needsTick(facts));
  }

  /// Whether something on screen ends with the clock alone: an acknowledged
  /// alarm's desk timer, or the moment after a close.
  static bool _needsTick(HomeFacts facts) =>
      facts.acknowledged != null || facts.handled != null;

  /// Pins [topic] to the top of the list, or unpins it.
  Future<void> togglePin(String topic) async {
    final prefs = _listPrefs;
    if (prefs == null) return;
    await prefs.setPinned(topic, pinned: !prefs.pinned().contains(topic));
    _repaint(rowsOnly: true);
  }

  /// Mutes [topic] on this phone, or unmutes it. Muting greys the row and
  /// moves it below the rest. Pushes and alarms are untouched.
  Future<void> toggleMute(String topic) async {
    final prefs = _listPrefs;
    if (prefs == null) return;
    await prefs.setMuted(topic, muted: !prefs.muted().contains(topic));
    _repaint(rowsOnly: true);
  }

  /// Marks every message on [topic] read. Stamped at the newest message the
  /// list holds when that is later than the phone's clock, so a phone running
  /// a little behind the server does not leave the newest one unread.
  Future<void> markRead(String topic) async {
    final prefs = _listPrefs;
    if (prefs == null) return;
    await prefs.markRead(topic, _readStamp(topic));
    _repaint(rowsOnly: true);
  }

  DateTime _readStamp(String topic) {
    final now = _now();
    final times = _lastMessageTimes?[topic] ?? const <int>[];
    if (times.isEmpty) return now;
    final newest = DateTime.fromMillisecondsSinceEpoch(
      times.reduce((a, b) => a > b ? a : b) * 1000,
    );
    return newest.isAfter(now) ? newest : now;
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
  /// a setup problem, not an alarm, and the status card carries the message.
  ///
  /// A server is set up but did not answer: the rows are still the user's,
  /// only old. Keep them, mark them old, and say when they were last true.
  Future<HomeState> _failureState(String? message) async {
    if (!await _hasServer()) {
      return state.copyWith(
        status: HomeStatus.failure,
        errorMessage: message,
        topicItems: const [],
        clearRinging: true,
        isStale: false,
        clearLastKnownGood: true,
        hasServer: false,
        facts: HomeFacts.none,
      );
    }

    final seenAt = state.lastKnownGoodAt;
    return state.copyWith(
      status: HomeStatus.failure,
      errorMessage: message,
      clearRinging: true,
      isStale: seenAt != null,
      hasServer: true,
      // An old copy says nothing about what is live now.
      facts: state.facts.withoutLive(),
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
      _lastMessageTimes = const {};
      _lastPreviews = const {};
      _syncTimer(false);
      final now = _now();
      return state.copyWith(
        status: HomeStatus.success,
        topicItems: const [],
        clearRinging: true,
        clearError: true,
        isStale: false,
        lastKnownGoodAt: now,
        hasServer: true,
        facts: homeFactsFrom(
          topics: topics,
          incidents: incidents,
          warningTopics: const {},
          messageTimes: const {},
          now: now,
        ),
      );
    }

    await _messageSync?.syncAll(topics.map((t) => t.name));

    final now = _now();
    final openIncidentIds = incidents
        .where((i) => i.state == 'open')
        .map((i) => i.id)
        .toSet();

    final warningTopics = <String>{};
    final messageTimes = <String, List<int>>{};
    final previews = <String, String>{};
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
      messageTimes[t.name] = [for (final m in msgs) m.time];
      if (latest != null) previews[t.name] = topicPreview(latest);
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

    final items = _buildTopicItems(
      topics,
      messageTimes,
      previews,
      incidents: incidents,
      warningTopics: warningTopics,
      now: now,
    );

    // A newer build started while this one waited on the polls, so this list
    // is already out of date and the caller throws the state away. Leave the
    // lists the timer reads alone too, or its next tick draws this old list
    // over the newer one: an acknowledge answer that arrived after the close
    // painted the screen blue again.
    if (id != _buildId) return state;

    // A topic this phone has never marked starts out read, so the first list
    // after an update does not put a badge on everything. From here on only
    // what arrives later counts. Only the newest build writes, and the rows
    // above already count an unmarked topic as read, so they stay right.
    final prefs = _listPrefs;
    if (prefs != null) {
      for (final t in topics) {
        if (prefs.lastReadAt(t.name) == null) await prefs.markRead(t.name, now);
      }
    }

    _lastIncidents = incidents;
    _lastTopics = topics;
    _lastWarningTopics = warningTopics;
    _lastMessageTimes = messageTimes;
    _lastPreviews = previews;

    final facts = homeFactsFrom(
      topics: topics,
      incidents: incidents,
      warningTopics: warningTopics,
      messageTimes: messageTimes,
      now: now,
    );
    _syncTimer(_needsTick(facts));

    return state.copyWith(
      status: HomeStatus.success,
      topicItems: items,
      ringingIncidentId: facts.ringing?.incidentId,
      clearRinging: facts.ringing == null,
      clearError: true,
      isStale: false,
      lastKnownGoodAt: now,
      hasServer: true,
      facts: facts,
    );
  }

  List<HomeTopicItem> _buildTopicItems(
    List<Topic> topics,
    Map<String, List<int>> messageTimes,
    Map<String, String> previews, {
    required List<Incident> incidents,
    required Set<String> warningTopics,
    required DateTime now,
  }) {
    final pinned = _listPrefs?.pinned() ?? const <String>{};
    final muted = _listPrefs?.muted() ?? const <String>{};
    final items = topics.map((t) {
      final isMuted = muted.contains(t.name);
      final times = messageTimes[t.name] ?? const <int>[];
      return HomeTopicItem(
        name: t.name,
        ringsThroughSilent: t.critical,
        preview: previews[t.name],
        // A muted topic shows no count. Its messages still count as read or
        // unread underneath, so unmuting brings the number back.
        unreadCount: isMuted
            ? 0
            : unreadCount(
                times,
                _listPrefs?.lastReadAt(t.name),
              ),
        isPinned: pinned.contains(t.name),
        isMuted: isMuted,
        lastMessageAt: times.isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                times.reduce((a, b) => a > b ? a : b) * 1000,
              ),
        rowKind: rowKindFor(
          topic: t.name,
          incidents: incidents,
          warningTopics: warningTopics,
          now: now,
          deskTimerS: t.deskTimerS,
        ),
      );
    }).toList();

    final byName = {for (final i in items) i.name: i};
    final order = orderInbox([
      for (final i in items)
        InboxEntry(
          name: i.name,
          kind: i.rowKind,
          pinned: i.isPinned,
          muted: i.isMuted,
          unreadCount: i.unreadCount,
          lastMessageAt: i.lastMessageAt,
        ),
    ]);
    return [for (final name in order) byName[name]!];
  }
}
