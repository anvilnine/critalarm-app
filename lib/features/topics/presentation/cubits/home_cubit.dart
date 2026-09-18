import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
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
  ]) : super(const HomeState());

  final IncidentsCubit _incidents;
  final TopicsCubit _topics;

  /// Still here for the per-topic message poll, which is the one thing on this
  /// screen that is neither an incident nor a topic.
  final IncidentRepository _incidentRepository;

  /// Catches up on priority 1-3, which push never delivers (api.md 1.7).
  final MessageSyncService? _messageSync;

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

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
    await _incidentsSub?.cancel();
    await _topicsSub?.cancel();
    return super.close();
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
      emit(state.copyWith(status: HomeStatus.failure, errorMessage: failure));
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
    final next = await _buildState(incidents.incidents, topics.topics);
    if (isClosed || id != _buildId) return;
    emit(next);
  }

  Future<HomeState> _buildState(
    List<Incident> incidents,
    List<Topic> topics,
  ) async {
    if (topics.isEmpty) {
      return state.copyWith(
        status: HomeStatus.success,
        topicItems: const [],
        faceState: FaceState.watching,
        word: LocaleKeys.home_stage_word_no_topics.tr(),
        subText: LocaleKeys.home_stage_sub_no_topics.tr(),
        severity: SeverityMode.none,
        clearRinging: true,
        clearError: true,
      );
    }

    await _messageSync?.syncAll(topics.map((t) => t.name));

    final openIncidents = incidents.where((i) => i.state == 'open').toList();
    final openIncidentIds = openIncidents.map((i) => i.id).toSet();

    final hasCriticalOpen = openIncidents.any(
      (i) => i.messages.any((m) => m.priority == 5),
    );

    final warningTopics = <String>{};
    final priorities = <String, int>{};
    for (final t in topics) {
      final pollResult = await _incidentRepository.pollMessages(
        t.name,
        poll: 1,
      );
      if (pollResult.isError()) {
        return state.copyWith(
          status: HomeStatus.failure,
          errorMessage: pollResult.exceptionOrNull()?.message,
        );
      }
      final msgs = pollResult.getOrNull() ?? [];
      final latest = msgs.isEmpty
          ? null
          : msgs.reduce((a, b) => a.time > b.time ? a : b);
      priorities[t.name] = latest?.priority ?? 3;
      if (msgs.any(
        (m) =>
            m.priority == 4 ||
            (m.tags.contains('warning') &&
                m.priority != 5 &&
                (m.incidentId == null ||
                    openIncidentIds.contains(m.incidentId))),
      )) {
        warningTopics.add(t.name);
      }
    }

    final hasWarningOpen =
        openIncidents.any((i) => i.messages.any((m) => m.priority == 4)) ||
        warningTopics.isNotEmpty;

    FaceState faceState;
    String word;
    String subText;
    SeverityMode severity;
    String? ringingIncidentId;

    if (hasCriticalOpen) {
      faceState = FaceState.alarmed;
      word = LocaleKeys.home_stage_word_critical.tr();
      final crit = openIncidents.firstWhere(
        (i) => i.messages.any((m) => m.priority == 5),
      );
      subText = LocaleKeys.home_stage_sub_critical.tr(
        namedArgs: {'topic': crit.topic},
      );
      severity = SeverityMode.crit;
      ringingIncidentId = crit.id;
    } else if (hasWarningOpen) {
      faceState = FaceState.worried;
      final warningCount = warningTopics.length;
      word = LocaleKeys.home_stage_word_warning.plural(warningCount);
      subText = LocaleKeys.home_stage_sub_warning.plural(
        warningCount,
        namedArgs: {
          'count': topics.length.toString(),
          'warnings': warningCount.toString(),
        },
      );
      severity = SeverityMode.high;
    } else {
      faceState = FaceState.calm;
      word = LocaleKeys.home_stage_word_clear.tr();
      // "Last alert 06:12, acknowledged." used to be baked into the
      // string, so every calm user was told about an alert at 06:12 that
      // never happened. Use the real one, or say nothing about it.
      final lastAck = incidents
          .map((i) => i.ackedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (newest, at) => newest == null || at.isAfter(newest) ? at : newest,
          );
      subText = lastAck == null
          ? LocaleKeys.home_stage_sub_clear.plural(topics.length)
          : LocaleKeys.home_stage_sub_clear_last.plural(
              topics.length,
              namedArgs: {
                'count': topics.length.toString(),
                'time': DateFormat.Hm().format(lastAck.toLocal()),
              },
            );
      severity = SeverityMode.none;
    }

    final items = _buildTopicItems(
      topics,
      openIncidents,
      warningTopics,
      priorities,
    );

    return state.copyWith(
      status: HomeStatus.success,
      topicItems: items,
      faceState: faceState,
      word: word,
      subText: subText,
      severity: severity,
      ringingIncidentId: ringingIncidentId,
      clearRinging: ringingIncidentId == null,
      clearError: true,
    );
  }

  List<HomeTopicItem> _buildTopicItems(
    List<Topic> topics,
    List<Incident> openIncidents,
    Set<String> warningTopics,
    Map<String, int> priorities,
  ) {
    return topics.map((t) {
      final hasOpen = openIncidents.any((i) => i.topic == t.name);
      final hasWarning = warningTopics.contains(t.name);
      return HomeTopicItem(
        name: t.name,
        meta: hasOpen
            ? LocaleKeys.home_meta_alert_active.tr()
            : (hasWarning
                  ? LocaleKeys.home_meta_warning.tr()
                  : LocaleKeys.home_meta_quiet.tr()),
        priority: _priority(priorities[t.name] ?? 3),
        isQuiet: (priorities[t.name] ?? 3) <= 2,
        faceState: hasOpen
            ? FaceState.alarmed
            : (hasWarning ? FaceState.worried : FaceState.calm),
        isCrit: hasOpen && t.critical,
        isLive: hasOpen || hasWarning,
        ringsThroughSilent: t.critical,
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
