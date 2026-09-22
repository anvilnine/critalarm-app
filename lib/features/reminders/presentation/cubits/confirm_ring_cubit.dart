import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/domain/ring_failure.dart';
import 'package:critalarm/features/reminders/presentation/cubits/confirm_ring_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The screen both "Ring me now" paths land on (idea 1's button and the
/// quick action). Nothing rings without the tap on this screen.
///
/// A success is stamped as `lastTestAt` by `TriggerTestAlarmUsecase`. A
/// 409, 401 or offline answer is shown here and stamped as a failed test.
/// The alarm itself arrives through the normal push path.
///
/// A topic with an open or acked incident is left out: the server would
/// not ring it again, so a test there looks like a silent pass.
class ConfirmRingCubit extends Cubit<ConfirmRingState> {
  ConfirmRingCubit({
    required Future<List<Topic>?> Function() readTopics,
    required Future<List<Incident>?> Function() readIncidents,
    required Future<AppResult<String>> Function(String topic) triggerTest,
    required ReminderStore store,
    required bool canTestNormalTopics,
    DateTime Function()? now,
    ReminderAnalytics? analytics,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readTopics = readTopics,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readIncidents = readIncidents,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _triggerTest = triggerTest,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _canTestNormalTopics = canTestNormalTopics,
       _now = now ?? DateTime.now,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _analytics = analytics,
       super(const ConfirmRingState());

  final Future<List<Topic>?> Function() _readTopics;
  final Future<List<Incident>?> Function() _readIncidents;
  final Future<AppResult<String>> Function(String topic) _triggerTest;
  final ReminderStore _store;
  final bool _canTestNormalTopics;
  final DateTime Function() _now;
  final ReminderAnalytics? _analytics;

  Future<void> load() async {
    final allTopics = await _readTopics();
    if (isClosed) return;
    if (allTopics == null) {
      emit(const ConfirmRingState(status: ConfirmRingStatus.loadFailed));
      return;
    }
    // Incidents that cannot be read hide nothing.
    final incidents = await _readIncidents() ?? const <Incident>[];
    if (isClosed) return;
    final busy = {
      for (final incident in incidents)
        if (incident.isOpen || incident.isAcked) incident.topic,
    };
    final topics = [
      for (final topic in allTopics)
        if (!busy.contains(topic.name)) topic,
    ];
    final tested = _store.readLastTestAt();
    final now = _now();

    RingTopicRow row(Topic topic) {
      final at = tested[topic.name];
      return RingTopicRow(
        name: topic.name,
        isCritical: topic.critical,
        daysSinceTest: at == null ? null : ReminderDates.daysBetween(at, now),
      );
    }

    // Tested longest ago first; never tested counts as the oldest.
    int byAge(RingTopicRow a, RingTopicRow b) =>
        (b.daysSinceTest ?? 1 << 30).compareTo(a.daysSinceTest ?? 1 << 30);

    final critical = [
      for (final topic in topics)
        if (topic.critical) row(topic),
    ]..sort(byAge);
    final normal = _canTestNormalTopics
        ? ([
            for (final topic in topics)
              if (!topic.critical) row(topic),
          ]..sort(byAge))
        : const <RingTopicRow>[];

    emit(
      ConfirmRingState(
        status: ConfirmRingStatus.ready,
        critical: critical,
        normal: normal,
        selected: critical.isNotEmpty
            ? critical.first.name
            : (normal.isNotEmpty ? normal.first.name : null),
      ),
    );
  }

  void select(String topic) {
    if (state.status == ConfirmRingStatus.sending) return;
    emit(
      state.copyWith(
        selected: topic,
        status: ConfirmRingStatus.ready,
        clearFailure: true,
      ),
    );
  }

  Future<void> send() async {
    final topic = state.selected;
    if (topic == null || state.status == ConfirmRingStatus.sending) return;
    emit(state.copyWith(status: ConfirmRingStatus.sending, clearFailure: true));

    final result = await _triggerTest(topic);
    final failure = result.exceptionOrNull();
    if (failure == null) {
      await _analytics?.testRingSent(result: 'ok');
      if (!isClosed) emit(state.copyWith(status: ConfirmRingStatus.sent));
      return;
    }
    final kind = RingFailures.classify(failure);
    if (kind.countsAsFailedTest) await _store.markTestFailed(_now());
    await _analytics?.testRingSent(
      result: switch (kind) {
        RingFailure.notCritical => 'not_critical',
        RingFailure.unauthorized => 'unauthorized',
        RingFailure.offline => 'offline',
        RingFailure.other => 'other',
      },
    );
    if (isClosed) return;
    emit(state.copyWith(status: ConfirmRingStatus.ready, failure: kind));
  }
}
