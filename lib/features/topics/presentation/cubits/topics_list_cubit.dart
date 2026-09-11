import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_state.dart';
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
        for (final t in topics) {
          final pollResult = await _incidentRepository.pollMessages(
            t.name,
            poll: 1,
          );
          final msgs = pollResult.getOrNull() ?? [];
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

          if (t.name == 'prod-db') {
            return TopicsListItem(
              name: t.name,
              meta: isOpenCrit ? 'Ringing 2 min 14 s' : 'Quiet for 6 h',
              priority: PriorityLevel.critical,
              faceState: isOpenCrit ? FaceState.alarmed : FaceState.calm,
              isCrit: isOpenCrit,
            );
          }

          if (t.name == 'nas-backup') {
            final hasWarning = warningTopics.contains('nas-backup');
            return TopicsListItem(
              name: t.name,
              meta: hasWarning
                  ? 'Finished 02:04, 2 warnings'
                  : 'Finished 02:00, 412 GB',
              priority: PriorityLevel.high,
              faceState: hasWarning ? FaceState.worried : FaceState.calm,
            );
          }

          if (t.name == 'uptime-kuma') {
            return TopicsListItem(
              name: t.name,
              meta: '3 today',
              priority: PriorityLevel.defaultPriority,
            );
          }

          if (t.name == 'home-ha') {
            return TopicsListItem(
              name: t.name,
              meta: 'Yesterday 18:40',
              priority: PriorityLevel.low,
              isQuiet: true,
            );
          }

          FaceState face;
          final hasWarning = warningTopics.contains(t.name);
          if (isOpenCrit) {
            face = FaceState.alarmed;
          } else if (isOpenHigh || hasWarning) {
            face = FaceState.worried;
          } else {
            face = FaceState.calm;
          }

          final priority = t.critical
              ? PriorityLevel.critical
              : PriorityLevel.defaultPriority;

          return TopicsListItem(
            name: t.name,
            meta: isOpenCrit
                ? 'Ringing'
                : (isOpenHigh || hasWarning ? '1 warning' : 'Quiet'),
            priority: priority,
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
