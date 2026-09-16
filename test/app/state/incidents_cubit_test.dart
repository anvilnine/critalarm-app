import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real repository with a counter on the list read, so a test can prove a
/// screen did not go back to the server.
class _CountingIncidents implements IncidentRepository {
  _CountingIncidents(this._inner);

  final IncidentRepository _inner;
  int listReads = 0;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    int? limit,
    String? state,
    String? topic,
  }) {
    listReads++;
    return _inner.getIncidents(limit: limit, state: state, topic: topic);
  }

  @override
  Future<AppResult<Incident>> getIncident(String id) => _inner.getIncident(id);

  @override
  Future<AppResult<Incident>> ackIncident(String id) => _inner.ackIncident(id);

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

/// Hands out a list read the test finishes by hand, so two of them can be in
/// the air at once and finish in the wrong order.
class _ScriptedIncidents implements IncidentRepository {
  final pending = <Completer<AppResult<List<Incident>>>>[];

  /// What each list read put on the wire, so a test can pin the contract.
  final limits = <int?>[];

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    int? limit,
    String? state,
    String? topic,
  }) {
    limits.add(limit);
    final completer = Completer<AppResult<List<Incident>>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Incident _incident(String id, {String state = 'open'}) => Incident(
  id: id,
  topic: 'prod-db',
  state: state,
  openedAt: DateTime.utc(2026, 9, 16, 8),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shared list is what everyone reads', () {
    test('a second screen opening does not fetch the list again', () async {
      final server = MockServer()..seedCalm();
      final api = MockApiClient(server);
      final repository = _CountingIncidents(InMemoryIncidentRepository(api));
      final incidents = IncidentsCubit(GetIncidentsUsecase(repository));
      final topics = TopicsCubit(
        GetTopicsUsecase(InMemoryTopicRepository(api)),
      );
      addTearDown(incidents.close);
      addTearDown(topics.close);

      final home = HomeCubit(incidents, topics, repository);
      addTearDown(home.close);
      await home.load();
      expect(repository.listReads, 1);

      final history = HistoryCubit(incidents);
      addTearDown(history.close);
      await history.load();

      expect(
        repository.listReads,
        1,
        reason: 'History read what Home already loaded',
      );
    });

    test(
      'acknowledging lands in the shared list, and a second reader sees it '
      'without asking the server again',
      () async {
        final server = MockServer()..seedAlarmed();
        final repository = _CountingIncidents(
          InMemoryIncidentRepository(MockApiClient(server)),
        );
        final incidents = IncidentsCubit(GetIncidentsUsecase(repository));
        addTearDown(incidents.close);

        final history = HistoryCubit(incidents);
        addTearDown(history.close);
        await history.load();
        expect(history.state.days, isNotEmpty);

        final openId = incidents.state.openIncidents.first.id;
        final alarm = CriticalAlarmCubit(
          GetIncidentUsecase(repository),
          GetIncidentsUsecase(repository),
          AcknowledgeIncidentUsecase(repository),
          CloseIncidentUsecase(repository),
          incidents,
        );
        addTearDown(alarm.close);
        await alarm.load(incidentId: openId);

        final readsBeforeAck = repository.listReads;
        await alarm.acknowledge();
        await pumpEventQueue();

        expect(
          incidents.state.incidents.firstWhere((i) => i.id == openId).isAcked,
          isTrue,
          reason: 'the acknowledge belongs to the shared list',
        );
        expect(
          history.state.entries
              .firstWhere((e) => e.id == openId)
              .state
              .name,
          'acked',
          reason: 'History follows without being reopened',
        );
        expect(
          repository.listReads,
          readsBeforeAck,
          reason: 'nobody fetched the list again to find that out',
        );
      },
    );
  });

  group('the shared list read', () {
    test('carries the limit api.md writes into the call', () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await first;
      final second = cubit.refresh();
      scripted.pending[1].complete([_incident('inc_1')].toSuccess());
      await second;

      // api.md §3.2 has limit as part of the call, not an optional extra, and
      // one list now serves every screen that used to ask for its own.
      expect(scripted.limits, [200, 200]);
      expect(IncidentsCubit.listLimit, 200);
    });
  });

  group('the stale-write guard', () {
    test('an answer asked for before the newest update is dropped', () async {
      final scripted = _ScriptedIncidents();
      var clock = DateTime(2026, 9, 16, 10);
      final cubit = IncidentsCubit(
        GetIncidentsUsecase(scripted),
        now: () => clock,
      );
      addTearDown(cubit.close);

      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await first;
      expect(cubit.state.incidents.single.isOpen, isTrue);

      // A slow list read goes out, then the acknowledge comes back before it.
      clock = DateTime(2026, 9, 16, 10, 0, 1);
      final slow = cubit.refresh();
      clock = DateTime(2026, 9, 16, 10, 0, 2);
      cubit.applyIncident(_incident('inc_1', state: 'acked'));

      // The slow answer still says the incident is open. It is older than the
      // acknowledge, so it must not undo it.
      scripted.pending[1].complete([_incident('inc_1')].toSuccess());
      await slow;

      expect(cubit.state.incidents.single.isAcked, isTrue);
      expect(cubit.state.isRefreshing, isFalse);
    });

    test('an answer asked for after the newest update is kept', () async {
      final scripted = _ScriptedIncidents();
      var clock = DateTime(2026, 9, 16, 10);
      final cubit = IncidentsCubit(
        GetIncidentsUsecase(scripted),
        now: () => clock,
      );
      addTearDown(cubit.close);

      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await first;

      cubit.applyIncident(_incident('inc_1', state: 'acked'));
      clock = DateTime(2026, 9, 16, 10, 0, 5);
      final second = cubit.refresh();
      scripted.pending[1].complete([_incident('inc_2')].toSuccess());
      await second;

      expect(cubit.state.incidents.single.id, 'inc_2');
    });
  });

  group('a refresh does not blank what is on screen', () {
    test('the list stays in the state for the whole refresh', () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await first;

      final seen = <IncidentsState>[];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);

      final second = cubit.refresh();
      await pumpEventQueue();
      expect(cubit.state.isRefreshing, isTrue);
      expect(cubit.state.incidents, isNotEmpty);

      scripted.pending[1].complete([_incident('inc_1')].toSuccess());
      await second;
      await pumpEventQueue();

      expect(
        seen.every((s) => s.incidents.isNotEmpty),
        isTrue,
        reason: 'no state in a refresh is one a screen would draw as empty',
      );
    });

    test('History keeps its days through a refresh', () async {
      final server = MockServer()..seedAlarmed();
      final incidents = IncidentsCubit(
        GetIncidentsUsecase(
          InMemoryIncidentRepository(MockApiClient(server)),
        ),
      );
      addTearDown(incidents.close);
      final history = HistoryCubit(incidents);
      addTearDown(history.close);

      await history.load();
      expect(history.state.days, isNotEmpty);

      final seen = <HistoryState>[];
      final sub = history.stream.listen(seen.add);
      addTearDown(sub.cancel);

      await history.refresh();
      await pumpEventQueue();

      expect(
        seen.every((s) => !(s.isLoading && s.days.isEmpty)),
        isTrue,
        reason: 'the screen draws a spinner on exactly that pair',
      );
    });
  });

  group('the badge follows the incident state', () {
    const channel = MethodChannel(PushHost.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late PushHost host;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      host = PushHost();
    });

    tearDown(() async {
      await host.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });

    List<MethodCall> badgeCalls() =>
        calls.where((c) => c.method == 'setBadgeCount').toList();

    test('a fetch and an acknowledge both move the number', () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(
        GetIncidentsUsecase(scripted),
        badge: AppBadge(host),
      );
      addTearDown(cubit.close);

      final first = cubit.ensureLoaded();
      scripted.pending[0].complete(
        [_incident('inc_1'), _incident('inc_2')].toSuccess(),
      );
      await first;
      await pumpEventQueue();
      expect(badgeCalls().last.arguments, {'count': 2});

      cubit.applyIncident(_incident('inc_1', state: 'acked'));
      await pumpEventQueue();
      expect(badgeCalls().last.arguments, {'count': 1});
    });
  });
}
