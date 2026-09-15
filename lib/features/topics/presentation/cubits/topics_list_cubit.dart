import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for TopicsListScreen.
class TopicsListCubit extends Cubit<TopicsListState> {
  TopicsListCubit(
    this._getTopics,
    this._incidentRepository,
  ) : super(const TopicsListState());

  final GetTopicsUsecase _getTopics;
  final IncidentRepository _incidentRepository;

  Future<void> load() async {
    emit(state.copyWith(status: TopicsListStatus.loading));

    final topicsResult = await _getTopics(const NoParams());
    final incidentsResult = await _incidentRepository.getIncidents();

    if (incidentsResult.isError()) {
      emit(
        state.copyWith(
          status: TopicsListStatus.failure,
          errorMessage: incidentsResult.exceptionOrNull()?.message,
        ),
      );
      return;
    }
    await topicsResult.fold(
      (topics) async {
        if (topics.isEmpty) {
          emit(
            state.copyWith(
              status: TopicsListStatus.success,
              topics: const [],
            ),
          );
          return;
        }

        final incidents = incidentsResult.getOrNull() ?? [];
        final openIncidents = incidents
            .where((i) => i.state == 'open')
            .toList();
        final openIncidentIds = openIncidents.map((i) => i.id).toSet();

        final warningTopics = <String>{};
        final priorities = <String, int>{};
        for (final t in topics) {
          final pollResult = await _incidentRepository.pollMessages(
            t.name,
            poll: 1,
          );
          if (pollResult.isError()) {
            emit(
              state.copyWith(
                status: TopicsListStatus.failure,
                errorMessage: pollResult.exceptionOrNull()?.message,
              ),
            );
            return;
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

        emit(
          state.copyWith(
            status: TopicsListStatus.success,
            topics: items,
          ),
        );
      },
      (failure) async {
        emit(
          state.copyWith(
            status: TopicsListStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
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
