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
            openIncidentIds: openIncidents.map((i) => i.id).toList(),
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

  /// Acknowledge every open incident on this topic, and stop the noise first.
  ///
  /// The phone goes quiet before any request is made. A slow server, a dead
  /// network or a refused ack must never leave the alarm ringing: the person
  /// pressed the button, so the sound is over whatever the server says next.
  Future<void> markAsRead() async {
    emit(state.copyWith(isMarkingAsRead: true));

    // Kill the sound first, by asking for the sound rather than for an id.
    // The server can ring an incident it already has as acknowledged, and then
    // no id the app holds matches what the speaker is doing.
    await _stopRinging();
    await _silence(state.openIncidentIds);

    final incidentsResult = await _incidentRepository.getIncidents(
      topic: state.topicName,
    );
    final incidents = incidentsResult.getOrNull() ?? [];
    final openIds = incidents
        .where((i) => i.state == 'open')
        .map((i) => i.id)
        .toList();

    // The list the server just gave can hold an incident that opened after the
    // screen loaded, so silence anything new before acking it.
    await _silence(
      openIds.where((id) => !state.openIncidentIds.contains(id)),
    );

    for (final id in openIds) {
      await _incidentRepository.ackIncident(id);
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
        openIncidentIds: const [],
      ),
    );
  }

  /// Stop whatever is ringing, whichever incident it belongs to.
  Future<void> _stopRinging() async {
    try {
      await alarm?.stopRinging();
    } on Object catch (_) {
      // Nothing to do. The ack below is what the server cares about.
    }
  }

  /// Stop the local alarm for each incident. Never throws: a platform channel
  /// that is missing or unhappy must not stop the acknowledge from going out.
  Future<void> _silence(Iterable<String> incidentIds) async {
    final host = alarm;
    if (host == null) return;
    for (final id in incidentIds) {
      try {
        await host.cancelAlarm(id);
      } on Object catch (_) {
        // Nothing to do. The ack below is what the server cares about.
      }
    }
  }
}
