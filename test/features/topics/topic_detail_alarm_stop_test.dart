import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';

/// Wraps a real repository and makes every ack fail, so a test can check the
/// phone still goes quiet when the server will not take the acknowledge.
class _AckAlwaysFails implements IncidentRepository {
  _AckAlwaysFails(this._inner);

  final IncidentRepository _inner;

  @override
  Future<AppResult<Incident>> ackIncident(String id) async => const Failure.api(
    statusCode: 500,
    message: 'the server refused it',
  ).toFailure();

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) => _inner.getIncidents(limit: limit, state: state, topic: topic);

  @override
  Future<AppResult<Incident>> getIncident(String id) => _inner.getIncident(id);

  @override
  Future<AppResult<Incident>> closeIncident(String id) =>
      _inner.closeIncident(id);

  @override
  Future<AppResult<String>> triggerTest({required String topic}) =>
      _inner.triggerTest(topic: topic);

  @override
  Future<AppResult<SendResult>> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) => _inner.publishMessage(
    topic,
    message: message,
    title: title,
    priority: priority,
    tags: tags,
  );

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) => _inner.pollMessages(topic, poll: poll, since: since);
}

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late IncidentRepository incidentRepo;
  late UpdateTopicUsecase updateTopicUsecase;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;
  late FakeAlarmHost alarm;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    final topicRepo = InMemoryTopicRepository(apiClient);
    updateTopicUsecase = UpdateTopicUsecase(topicRepo);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(GetTopicsUsecase(topicRepo));
    alarm = FakeAlarmHost();
  });

  tearDown(() async {
    alarm.dispose();
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  group('acknowledging stops the ring', () {
    test('load remembers which incidents are open', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
        alarm: alarm.host,
      );

      await cubit.load('prod-db');

      expect(cubit.state.openIncidentIds, isNotEmpty);
    });

    test('markAsRead cancels the alarm for every open incident', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
        alarm: alarm.host,
      );
      await cubit.load('prod-db');
      final open = cubit.state.openIncidentIds;
      expect(open, isNotEmpty, reason: 'the seed must have an open incident');

      await cubit.markAsRead();

      final cancelled = alarm
          .argsTo('cancelAlarm')
          .map((a) => a['incident_id'])
          .toSet();
      for (final id in open) {
        expect(cancelled, contains(id));
      }
    });

    test('the alarm is cancelled before the acknowledge goes out', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
        alarm: alarm.host,
      );
      await cubit.load('prod-db');
      alarm.calls.clear();

      await cubit.markAsRead();

      // The very first native call markAsRead makes must be the silencing
      // one, and it must name its incident. Asking for "whatever is ringing"
      // silenced an unacknowledged incident on another topic.
      expect(alarm.calls.first.method, 'cancelAlarm');
    });

    test('a refused acknowledge still leaves the phone quiet', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        _AckAlwaysFails(incidentRepo),
        alarm: alarm.host,
      );
      await cubit.load('prod-db');
      final open = cubit.state.openIncidentIds;
      alarm.calls.clear();

      await cubit.markAsRead();

      final cancelled = alarm
          .argsTo('cancelAlarm')
          .map((a) => a['incident_id'])
          .toSet();
      for (final id in open) {
        expect(cancelled, contains(id));
      }
    });

    test('no incident on the state means no alarm is touched', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
        alarm: alarm.host,
      );
      alarm.calls.clear();

      // No load(), so the cubit knows of no incident at all. It must not reach
      // for the un-scoped stop: Android runs one alarm service for the whole
      // app, so that silenced whatever was ringing, on any topic, unacked.
      await cubit.markAsRead();

      expect(alarm.callsTo('stopRinging'), isEmpty);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
    });

    test('markAsRead never reaches for the un-scoped stop', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
        alarm: alarm.host,
      );
      await cubit.load('prod-db');
      alarm.calls.clear();

      await cubit.markAsRead();

      expect(alarm.callsTo('stopRinging'), isEmpty);
    });

    test('a missing alarm host does not stop the acknowledge', () async {
      server.seedAlarmed();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      );
      await cubit.load('prod-db');

      await expectLater(cubit.markAsRead(), completes);
      expect(cubit.state.isMarkingAsRead, isFalse);
    });
  });
}
