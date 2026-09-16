import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out a list read the test finishes by hand, so one can still be in the
/// air while the user changes something.
class _ScriptedTopics implements TopicRepository {
  final pending = <Completer<AppResult<List<Topic>>>>[];
  final deletes = <Completer<AppResult<Unit>>>[];
  final deleted = <String>[];

  @override
  Future<AppResult<List<Topic>>> getTopics() {
    final completer = Completer<AppResult<List<Topic>>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<AppResult<Unit>> deleteTopic(String name) {
    deleted.add(name);
    final completer = Completer<AppResult<Unit>>();
    deletes.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Topic _topic({bool critical = false}) =>
    Topic(name: 'prod-db', critical: critical);

void main() {
  group('the stale-write guard', () {
    test(
      'a list read asked for before the switch was flipped is dropped',
      () async {
        final scripted = _ScriptedTopics();
        var clock = DateTime(2026, 9, 17, 9);
        final cubit = TopicsCubit(GetTopicsUsecase(scripted), now: () => clock);
        addTearDown(cubit.close);

        final first = cubit.ensureLoaded();
        scripted.pending[0].complete([_topic()].toSuccess());
        await first;
        expect(cubit.state.topics.single.critical, isFalse);

        // A slow list read goes out, then the user switches critical delivery
        // on and the server confirms it.
        clock = DateTime(2026, 9, 17, 9, 0, 1);
        final slow = cubit.refresh();
        clock = DateTime(2026, 9, 17, 9, 0, 2);
        cubit.applyTopic(_topic(critical: true));

        // The slow answer still has the switch off. It is older than the
        // change, so it must not put the toggle back.
        scripted.pending[1].complete([_topic()].toSuccess());
        await slow;

        expect(cubit.state.topics.single.critical, isTrue);
        expect(cubit.state.isRefreshing, isFalse);
      },
    );

    test(
      'a list read asked for after the switch was flipped is kept',
      () async {
        final scripted = _ScriptedTopics();
        var clock = DateTime(2026, 9, 17, 9);
        final cubit = TopicsCubit(GetTopicsUsecase(scripted), now: () => clock);
        addTearDown(cubit.close);

        final first = cubit.ensureLoaded();
        scripted.pending[0].complete([_topic()].toSuccess());
        await first;

        cubit.applyTopic(_topic(critical: true));
        clock = DateTime(2026, 9, 17, 9, 0, 5);
        final second = cubit.refresh();
        scripted.pending[1].complete(
          [
            const Topic(name: 'nas-backup'),
          ].toSuccess(),
        );
        await second;

        expect(cubit.state.topics.single.name, 'nas-backup');
      },
    );
  });

  group('deleting a topic', () {
    Future<TopicsCubit> loaded(
      _ScriptedTopics scripted, {
      IncidentsCubit? incidents,
    }) async {
      final cubit = TopicsCubit(
        GetTopicsUsecase(scripted),
        deleteTopic: DeleteTopicUsecase(scripted),
        incidents: incidents,
      );
      final first = cubit.ensureLoaded();
      scripted.pending[0].complete(
        [
          const Topic(name: 'nas-backup'),
          const Topic(name: 'prod-db'),
          const Topic(name: 'web-front'),
        ].toSuccess(),
      );
      await first;
      return cubit;
    }

    test('the list drops the topic before the server answers', () async {
      final scripted = _ScriptedTopics();
      final cubit = await loaded(scripted);
      addTearDown(cubit.close);

      final delete = cubit.deleteTopic('prod-db');
      await pumpEventQueue();

      expect(
        cubit.state.topics.map((t) => t.name),
        ['nas-backup', 'web-front'],
        reason: 'the request is still in the air',
      );
      expect(scripted.deleted, ['prod-db']);

      scripted.deletes[0].complete(unit.toSuccess());
      expect(await delete, isNull);
      expect(cubit.state.topics.map((t) => t.name), [
        'nas-backup',
        'web-front',
      ]);
    });

    test('a refused delete puts the topic back where it was', () async {
      final scripted = _ScriptedTopics();
      final cubit = await loaded(scripted);
      addTearDown(cubit.close);

      final delete = cubit.deleteTopic('prod-db');
      await pumpEventQueue();
      scripted.deletes[0].complete(
        const Failure.api(statusCode: 500).toFailure(),
      );

      expect(await delete, isNotNull);
      expect(cubit.state.topics.map((t) => t.name), [
        'nas-backup',
        'prod-db',
        'web-front',
      ]);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('a topic the list never held is a no-op', () async {
      final scripted = _ScriptedTopics();
      final cubit = await loaded(scripted);
      addTearDown(cubit.close);

      final delete = cubit.deleteTopic('gone-already');
      await pumpEventQueue();
      scripted.deletes[0].complete(unit.toSuccess());

      expect(await delete, isNull);
      expect(cubit.state.topics, hasLength(3));
    });

    test("the topic's incidents leave the shared list with it", () async {
      final server = MockServer()..seedAlarmed();
      final api = MockApiClient(server);
      final incidents = IncidentsCubit(
        GetIncidentsUsecase(InMemoryIncidentRepository(api)),
      );
      addTearDown(incidents.close);
      await incidents.ensureLoaded();

      final topic = incidents.state.incidents.first.topic;
      expect(
        incidents.state.incidents.where((i) => i.topic == topic),
        isNotEmpty,
      );

      final scripted = _ScriptedTopics();
      final cubit = TopicsCubit(
        GetTopicsUsecase(scripted),
        deleteTopic: DeleteTopicUsecase(scripted),
        incidents: incidents,
      );
      addTearDown(cubit.close);
      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([Topic(name: topic)].toSuccess());
      await first;

      final delete = cubit.deleteTopic(topic);
      await pumpEventQueue();
      scripted.deletes[0].complete(unit.toSuccess());
      await delete;

      expect(incidents.state.incidents.where((i) => i.topic == topic), isEmpty);
    });

    test('a refused delete leaves the incidents alone', () async {
      final server = MockServer()..seedAlarmed();
      final api = MockApiClient(server);
      final incidents = IncidentsCubit(
        GetIncidentsUsecase(InMemoryIncidentRepository(api)),
      );
      addTearDown(incidents.close);
      await incidents.ensureLoaded();

      final topic = incidents.state.incidents.first.topic;
      final before = incidents.state.incidents.length;

      final scripted = _ScriptedTopics();
      final cubit = TopicsCubit(
        GetTopicsUsecase(scripted),
        deleteTopic: DeleteTopicUsecase(scripted),
        incidents: incidents,
      );
      addTearDown(cubit.close);
      final first = cubit.ensureLoaded();
      scripted.pending[0].complete([Topic(name: topic)].toSuccess());
      await first;

      final delete = cubit.deleteTopic(topic);
      await pumpEventQueue();
      scripted.deletes[0].complete(
        const Failure.api(statusCode: 500).toFailure(),
      );
      await delete;

      expect(incidents.state.incidents, hasLength(before));
    });
  });
}
