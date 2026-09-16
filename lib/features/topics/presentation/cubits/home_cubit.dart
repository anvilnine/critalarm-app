import 'package:critalarm/core/notifications/app_badge.dart';
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
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state for HomeScreen.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._getTopics,
    this._incidentRepository, [
    this._messageSync,
    this._badge,
  ]) : super(const HomeState());

  final GetTopicsUsecase _getTopics;
  final IncidentRepository _incidentRepository;

  /// Catches up on priority 1-3, which push never delivers (api.md 1.7).
  final MessageSyncService? _messageSync;

  /// The app icon shows how many incidents are open. Optional so a test can
  /// build the cubit without a platform channel behind it.
  final AppBadge? _badge;

  /// Pull-to-refresh. Same work as opening the screen, including the poll.
  Future<void> refresh() => load();

  Future<void> load() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final topicsResult = await _getTopics(const NoParams());
    final incidentsResult = await _incidentRepository.getIncidents();

    if (incidentsResult.isError()) {
      emit(
        state.copyWith(
          status: HomeStatus.failure,
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
              status: HomeStatus.success,
              topicItems: const [],
              faceState: FaceState.watching,
              word: LocaleKeys.home_stage_word_no_topics.tr(),
              subText: LocaleKeys.home_stage_sub_no_topics.tr(),
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
        await _badge?.setCount(openIncidents.length);

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
            emit(
              state.copyWith(
                status: HomeStatus.failure,
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

        final hasWarningOpen =
            openIncidents.any(
              (i) => i.messages.any((m) => m.priority == 4),
            ) ||
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
                (newest, at) =>
                    newest == null || at.isAfter(newest) ? at : newest,
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

        emit(
          state.copyWith(
            status: HomeStatus.success,
            topicItems: items,
            faceState: faceState,
            word: word,
            subText: subText,
            severity: severity,
            ringingIncidentId: ringingIncidentId,
            clearRinging: ringingIncidentId == null,
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
