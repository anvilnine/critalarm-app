import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for TopicDetailScreen.
class TopicDetailCubit extends Cubit<TopicDetailState> {
  TopicDetailCubit(
    this._getTopic,
    this._updateTopic,
    this._incidentRepository, {
    this.alarm,
  }) : super(const TopicDetailState());

  final GetTopicUsecase _getTopic;
  final UpdateTopicUsecase _updateTopic;
  final IncidentRepository _incidentRepository;

  /// Null off iOS, where there is no AlarmKit and nothing to gate on.
  final AlarmHost? alarm;

  Future<void> load(String topicName) async {
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

    final topicResult = await _getTopic(topicName);
    final incidentsResult = await _incidentRepository.getIncidents(
      topic: topicName,
    );

    topicResult.fold(
      (topic) {
        final incidents = incidentsResult.getOrNull() ?? [];
        final openIncidents = incidents
            .where((i) => i.state == 'open')
            .toList();

        final hasCrit =
            topic.critical &&
            openIncidents.any((i) => i.messages.any((m) => m.priority == 5));
        final hasHigh =
            openIncidents.any(
              (i) => i.messages.any((m) => m.priority == 4),
            ) ||
            (topicName == 'nas-backup');

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

        final priorityLabel = topic.critical
            ? 'critical'
            : (topicName == 'nas-backup'
                  ? 'high'
                  : (topicName == 'uptime-kuma'
                        ? 'default'
                        : (topicName == 'home-ha' ? 'low' : 'default')));

        final messages = _resolveMessages(topicName, hasHigh: hasHigh);
        final count = messages.length > 2 ? messages.length : 61;
        final subText = LocaleKeys.topic_detail_stage_sub.tr(
          namedArgs: {
            'priority': priorityLabel,
            'count': count.toString(),
          },
        );

        emit(
          state.copyWith(
            status: TopicDetailStatus.success,
            topicName: topic.name,
            critical: topic.critical,
            severity: severity,
            faceState: face,
            word: word,
            subText: subText,
            messages: messages,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: TopicDetailStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> toggleCriticalDelivery({required bool isCritical}) async {
    emit(state.copyWith(isUpdatingCritical: true));

    final result = await _updateTopic(
      UpdateTopicParams(name: state.topicName, critical: isCritical),
    );

    result.fold(
      (updatedTopic) {
        emit(
          state.copyWith(
            isUpdatingCritical: false,
            critical: updatedTopic.critical,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            isUpdatingCritical: false,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> markAsRead() async {
    emit(state.copyWith(isMarkingAsRead: true));

    final incidentsResult = await _incidentRepository.getIncidents(
      topic: state.topicName,
    );
    final incidents = incidentsResult.getOrNull() ?? [];
    for (final inc in incidents) {
      if (inc.state == 'open') {
        await _incidentRepository.ackIncident(inc.id);
      }
    }

    final clearedMessages = state.messages
        .map((m) => m.copyWith(isHigh: false))
        .toList();

    emit(
      state.copyWith(
        isMarkingAsRead: false,
        severity: SeverityMode.none,
        faceState: FaceState.calm,
        word: LocaleKeys.topic_detail_stage_word_clear.tr(),
        messages: clearedMessages,
      ),
    );
  }

  List<TopicDetailMessageItem> _resolveMessages(
    String topicName, {
    required bool hasHigh,
  }) {
    if (topicName == 'nas-backup') {
      return [
        TopicDetailMessageItem(
          title: 'Backup finished with 2 warnings',
          timestamp: '02:04',
          body:
              'rsync: 2 files vanished during transfer. '
              '412 GB copied in 43 min.',
          source: 'cron@nas / high',
          isHigh: hasHigh,
        ),
        const TopicDetailMessageItem(
          title: 'Backup finished',
          timestamp: 'Wed 02:00',
          body: '409 GB copied in 41 min.',
          source: 'cron@nas / default',
        ),
      ];
    }

    return [
      TopicDetailMessageItem(
        title: '$topicName message',
        timestamp: '10:00',
        body: 'Status check reported healthy.',
        source: 'agent@$topicName / default',
      ),
    ];
  }
}
