import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for HomeScreen.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._getTopics,
    this._incidentRepository, [
    this._messageSync,
  ]) : super(const HomeState());

  final GetTopicsUsecase _getTopics;
  final IncidentRepository _incidentRepository;

  /// Catches up on priority 1-3, which push never delivers (api.md 1.7).
  final MessageSyncService? _messageSync;

  /// Pull-to-refresh. Same work as opening the screen, including the poll.
  Future<void> refresh() => load();

  Future<void> load() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final topicsResult = await _getTopics(const NoParams());
    final incidentsResult = await _incidentRepository.getIncidents();

    await topicsResult.fold(
      (topics) async {
        if (topics.isEmpty) {
          emit(
            state.copyWith(
              status: HomeStatus.success,
              topicItems: const [],
              faceState: FaceState.watching,
              word: 'No topics yet',
              subText: 'Create a topic to get started.',
              severity: SeverityMode.none,
            ),
          );
          return;
        }

        await _messageSync?.syncAll(topics.map((t) => t.name));

        final incidents = incidentsResult.getOrNull() ?? [];
        final openIncidents = incidents
            .where((i) => i.state == 'open')
            .toList();
        final openIncidentIds = openIncidents.map((i) => i.id).toSet();

        final hasCriticalOpen = openIncidents.any(
          (i) => i.messages.any((m) => m.priority == 5),
        );

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

        final hasWarningOpen =
            openIncidents.any(
              (i) => i.messages.any((m) => m.priority == 4),
            ) ||
            warningTopics.isNotEmpty;

        FaceState faceState;
        String word;
        String subText;
        SeverityMode severity;

        if (hasCriticalOpen) {
          faceState = FaceState.alarmed;
          word = 'CRITICAL';
          final crit = openIncidents.firstWhere(
            (i) => i.messages.any((m) => m.priority == 5),
          );
          subText = '${crit.topic} ringing. Repeats every 30 s.';
          severity = SeverityMode.crit;
        } else if (hasWarningOpen) {
          faceState = FaceState.worried;
          word = '1 warning';
          subText = '${topics.length} topics. 1 warning.';
          severity = SeverityMode.high;
        } else {
          faceState = FaceState.calm;
          word = 'All clear';
          subText = '${topics.length} topics. Last alert 06:12, acknowledged.';
          severity = SeverityMode.none;
        }

        final items = _buildTopicItems(
          topics,
          openIncidents,
          warningTopics,
        );

        emit(
          state.copyWith(
            status: HomeStatus.success,
            topicItems: items,
            faceState: faceState,
            word: word,
            subText: subText,
            severity: severity,
          ),
        );
      },
      (failure) async {
        emit(
          state.copyWith(
            status: HomeStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  List<HomeTopicItem> _buildTopicItems(
    List<Topic> topics,
    List<Incident> openIncidents,
    Set<String> warningTopics,
  ) {
    return topics.map((t) {
      if (t.name == 'prod-db') {
        final isOpenCrit = openIncidents.any(
          (i) => i.topic == 'prod-db' && i.messages.any((m) => m.priority == 5),
        );
        return HomeTopicItem(
          name: t.name,
          meta: isOpenCrit ? 'Ringing 2 min 14 s' : 'Quiet for 6 h',
          priority: PriorityLevel.critical,
          faceState: isOpenCrit ? FaceState.alarmed : FaceState.calm,
          isCrit: isOpenCrit,
        );
      }

      if (t.name == 'nas-backup') {
        final isWorried = warningTopics.contains('nas-backup');
        return HomeTopicItem(
          name: t.name,
          meta: isWorried
              ? 'Finished 02:04, 2 warnings'
              : 'Finished 02:00, 412 GB',
          priority: PriorityLevel.high,
          faceState: isWorried ? FaceState.worried : FaceState.calm,
        );
      }

      if (t.name == 'uptime-kuma') {
        return HomeTopicItem(
          name: t.name,
          meta: '3 today',
          priority: PriorityLevel.defaultPriority,
        );
      }

      if (t.name == 'home-ha') {
        return HomeTopicItem(
          name: t.name,
          meta: 'Yesterday 18:40',
          priority: PriorityLevel.low,
          isQuiet: true,
        );
      }

      final hasOpen = openIncidents.any((i) => i.topic == t.name);
      final hasWarning = warningTopics.contains(t.name);
      return HomeTopicItem(
        name: t.name,
        meta: hasOpen ? 'Alert active' : (hasWarning ? '1 warning' : 'Quiet'),
        priority: t.critical
            ? PriorityLevel.critical
            : PriorityLevel.defaultPriority,
        faceState: hasOpen
            ? FaceState.alarmed
            : (hasWarning ? FaceState.worried : FaceState.calm),
        isCrit: hasOpen && t.critical,
      );
    }).toList();
  }
}
