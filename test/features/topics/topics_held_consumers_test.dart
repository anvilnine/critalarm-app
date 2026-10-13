import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The mock server's topic list, answered when the test lets it. Until then the
/// server has not answered, as on a cold start.
class _GatedTopics implements TopicRepository {
  _GatedTopics(this._inner);

  final TopicRepository _inner;
  final gate = Completer<void>();
  int reads = 0;

  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    reads++;
    await gate.future;
    return _inner.getTopics();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Counts the per-topic message polls a build makes.
class _CountingIncidents extends InMemoryIncidentRepository {
  const _CountingIncidents(super._client, this.counter);

  final List<String> counter;

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) {
    counter.add(topic);
    return super.pollMessages(topic, poll: poll, since: since);
  }
}

final DateTime _created = DateTime.utc(2026);

/// Whole seconds, because the server's messages carry no more.
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
);

void main() {
  sqfliteFfiInit();

  final scope = heldScopeFor(
    serverUrl: 'https://api.example',
    accountId: 'a1',
  )!;
  late LocalStore store;
  late MockServer server;
  late MockApiClient api;
  late _CountingIncidents incidentRepo;
  final polled = <String>[];
  late IncidentsCubit incidents;
  late _GatedTopics gatedTopics;
  late TopicsCubit topics;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    server = MockServer()..reset();
    api = MockApiClient(server);
    polled.clear();
    incidentRepo = _CountingIncidents(api, polled);
    incidents = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    gatedTopics = _GatedTopics(InMemoryTopicRepository(api));
    topics = TopicsCubit(
      GetTopicsUsecase(gatedTopics),
      held: store.topics,
      heldScope: () async => scope,
      identityChanges: AccountIdentityChanges(),
    );
    // The same topics are on the server and on the phone.
    server.seedState(
      topics: [
        Topic(name: 'calm', createdAt: _created),
        Topic(name: 'ringing', critical: true, createdAt: _created),
      ],
      incidents: [
        Incident(
          id: 'i-ringing',
          topic: 'ringing',
          openedAt: _now.subtract(const Duration(minutes: 2)),
          updatedAt: _now.subtract(const Duration(minutes: 2)),
          messages: [
            Message(
              id: 'm-ringing',
              topic: 'ringing',
              time: _now.millisecondsSinceEpoch ~/ 1000 - 120,
              priority: 5,
              incidentId: 'i-ringing',
            ),
          ],
        ),
      ],
      messages: [
        Message(
          id: 'm-ringing',
          topic: 'ringing',
          time: _now.millisecondsSinceEpoch ~/ 1000 - 120,
          priority: 5,
          incidentId: 'i-ringing',
        ),
      ],
    );
    await store.topics.replaceAll(scope, [
      Topic(name: 'calm', createdAt: _created),
      Topic(name: 'ringing', critical: true, createdAt: _created),
    ]);
  });

  tearDown(() async {
    if (!gatedTopics.gate.isCompleted) gatedTopics.gate.complete();
    await topics.writesDone;
    await incidents.close();
    await topics.close();
    await store.close();
  });

  TopicDetailCubit detail() {
    final cubit = TopicDetailCubit(
      incidents,
      topics,
      UpdateTopicUsecase(InMemoryTopicRepository(api)),
      incidentRepo,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('the Topic screen with the stored list', () {
    test('opens with Critical delivery and the canvas already drawn', () async {
      await incidents.ensureLoaded();
      await topics.loadHeld();
      expect(topics.state.isKept, isTrue);

      final cubit = detail();
      final seed = cubit.seedFor('ringing')!;

      // No transitional state: the same seed the in-memory list gave.
      expect(seed.status, TopicDetailStatus.success);
      expect(seed.critical, isTrue);
      expect(seed.severity, SeverityMode.crit);
      expect(seed.faceState, FaceState.alarmed);
      expect(seed.openIncidentIds, ['i-ringing']);
      expect(cubit.seedFor('calm')!.critical, isFalse);
    });

    test('load puts the stored Critical state on the first frame', () async {
      await incidents.ensureLoaded();
      await topics.loadHeld();
      final cubit = detail();
      final states = <TopicDetailState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      final load = cubit.load('ringing');
      await pumpEventQueue();

      // The server has not answered the topic list yet.
      expect(gatedTopics.reads, 1);
      expect(cubit.state.status, TopicDetailStatus.success);
      expect(cubit.state.critical, isTrue);
      // The full build, which polls the topic's messages, waits for the
      // server's list instead of running twice.
      expect(polled.length, 0);

      gatedTopics.gate.complete();
      await load;

      expect(cubit.state.status, TopicDetailStatus.success);
      expect(cubit.state.critical, isTrue);
      expect(polled.length, 1);
      // Critical never read as off on the way.
      expect(states.every((s) => s.critical), isTrue);
    });

    test('with the incidents not loaded yet, the loading state still has '
        'Critical delivery from the stored list', () async {
      await topics.loadHeld();
      final cubit = detail();

      final load = cubit.load('ringing');
      await pumpEventQueue();

      expect(cubit.state.status, TopicDetailStatus.loading);
      expect(cubit.state.critical, isTrue);

      gatedTopics.gate.complete();
      await load;
      expect(cubit.state.status, TopicDetailStatus.success);
    });

    test(
      'a topic the stored list lacks starts as loading, as before',
      () async {
        await topics.loadHeld();
        final cubit = detail();

        final load = cubit.load('stranger');
        await pumpEventQueue();

        expect(cubit.state.status, TopicDetailStatus.loading);
        expect(cubit.state.critical, isFalse);
        gatedTopics.gate.complete();
        await load;
      },
    );
  });

  group('Home with the stored list', () {
    test("does not build the list twice: it waits for the server's", () async {
      await topics.loadHeld();
      final home = HomeCubit(incidents, topics, incidentRepo);
      addTearDown(home.close);

      final load = home.load();
      await pumpEventQueue();

      // Incidents answered, the topic list is only the phone's copy.
      expect(incidents.state.isReady, isTrue);
      expect(topics.state.isReady, isTrue);
      expect(home.state.status, HomeStatus.loading);
      expect(polled.length, 0);

      gatedTopics.gate.complete();
      await load;

      expect(home.state.status, HomeStatus.success);
      expect(home.state.topicItems.map((t) => t.name).toSet(), {
        'calm',
        'ringing',
      });
      expect(polled.length, 2);
    });

    test('a server that does not answer leaves the existing failure', () async {
      await topics.loadHeld();
      final failing = TopicsCubit(
        GetTopicsUsecase(_Failing()),
        held: store.topics,
        heldScope: () async => scope,
        identityChanges: AccountIdentityChanges(),
      );
      addTearDown(failing.close);
      await failing.loadHeld();
      final home = HomeCubit(incidents, failing, incidentRepo);
      addTearDown(home.close);

      await home.load();
      await pumpEventQueue();

      expect(failing.state.status, AppDataStatus.failure);
      expect(failing.state.topics, hasLength(2));
      expect(home.state.status, HomeStatus.failure);
    });
  });
}

class _Failing implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async =>
      const Failure.api(statusCode: 500).toFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
