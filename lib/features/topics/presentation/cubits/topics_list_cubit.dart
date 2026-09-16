import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for TopicsListScreen.
///
/// Topics and incidents come from the app-level cubits. The per-topic message
/// poll is the only thing it still asks a repository for.
class TopicsListCubit extends Cubit<TopicsListState> {
  TopicsListCubit(
    this._incidents,
    this._topics,
    this._incidentRepository,
  ) : super(const TopicsListState());

  final IncidentsCubit _incidents;
  final TopicsCubit _topics;
  final IncidentRepository _incidentRepository;

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

  List<Incident>? _builtFromIncidents;
  List<Topic>? _builtFromTopics;

  int _buildId = 0;

  Future<void> load() async {
    _incidentsSub ??= _incidents.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
    _topicsSub ??= _topics.stream.listen(
      (_) => unawaited(_rebuildIfChanged()),
    );
    if (state.topics.isEmpty) {
      emit(state.copyWith(status: TopicsListStatus.loading));
    }
    await Future.wait([_incidents.ensureLoaded(), _topics.ensureLoaded()]);
    await _rebuildIfChanged();
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
      _builtFromIncidents = null;
      _builtFromTopics = null;
      emit(
        state.copyWith(
          status: TopicsListStatus.failure,
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
    final next = await _buildState(incidents.incidents, topics.topics);
    if (isClosed || id != _buildId) return;
    emit(next);
  }

  Future<TopicsListState> _buildState(
    List<Incident> incidents,
    List<Topic> topics,
  ) async {
    if (topics.isEmpty) {
      return state.copyWith(
        status: TopicsListStatus.success,
        topics: const [],
        clearError: true,
      );
    }

    final openIncidents = incidents.where((i) => i.state == 'open').toList();
    final openIncidentIds = openIncidents.map((i) => i.id).toSet();

    final warningTopics = <String>{};
    final priorities = <String, int>{};
    for (final t in topics) {
      final pollResult = await _incidentRepository.pollMessages(
        t.name,
        poll: 1,
      );
      if (pollResult.isError()) {
        return state.copyWith(
          status: TopicsListStatus.failure,
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

    final items = topics.map((t) {
      final isOpenCrit = openIncidents.any(
        (i) =>
            i.topic == t.name &&
            (t.critical || i.messages.any((m) => m.priority == 5)),
      );
      final isOpenHigh = openIncidents.any(
        (i) => i.topic == t.name && i.messages.any((m) => m.priority == 4),
      );

      FaceState face;
      final hasWarning = warningTopics.contains(t.name);
      if (isOpenCrit) {
        face = FaceState.alarmed;
      } else if (isOpenHigh || hasWarning) {
        face = FaceState.worried;
      } else {
        face = FaceState.calm;
      }

      final priority = _priority(priorities[t.name] ?? 3);

      return TopicsListItem(
        name: t.name,
        meta: isOpenCrit
            ? LocaleKeys.topics_list_meta_ringing.tr()
            : (isOpenHigh || hasWarning
                  ? LocaleKeys.topics_list_meta_warning.tr()
                  : LocaleKeys.topics_list_meta_quiet.tr()),
        priority: priority,
        isQuiet: (priorities[t.name] ?? 3) <= 2,
        faceState: face,
        isCrit: isOpenCrit,
      );
    }).toList();

    return state.copyWith(
      status: TopicsListStatus.success,
      topics: items,
      clearError: true,
    );
  }
}

PriorityLevel _priority(int priority) => switch (priority) {
  5 => PriorityLevel.critical,
  4 => PriorityLevel.high,
  2 => PriorityLevel.low,
  1 => PriorityLevel.min,
  _ => PriorityLevel.defaultPriority,
};
