import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
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

    final pollResult = await _incidentRepository.pollMessages(
      topicName,
      poll: 1,
    );
    if (incidentsResult.isError() || pollResult.isError()) {
      emit(
        state.copyWith(
          status: TopicDetailStatus.failure,
          errorMessage:
              incidentsResult.exceptionOrNull()?.message ??
              pollResult.exceptionOrNull()?.message,
        ),
      );
      return;
    }
    final polled = pollResult.getOrNull() ?? [];
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
            capReached: CapReached.fromFailure(failure),
          ),
        );
      },
    );
  }

  Future<void> toggleCriticalDelivery({required bool isCritical}) async {
    emit(state.copyWith(isUpdatingCritical: true, clearError: true));

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
            capReached: CapReached.fromFailure(failure),
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
}
