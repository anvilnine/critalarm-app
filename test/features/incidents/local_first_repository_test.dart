import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _now = DateTime.utc(2026, 9, 22, 12);

DateTime _at(int daysAgo) => _now.subtract(Duration(days: daysAgo));

Incident _incident(String id, {required int daysAgo, String topic = 'prod'}) {
  final openedAt = _at(daysAgo);
  return Incident(
    id: id,
    topic: topic,
    state: IncidentStates.closed,
    openedAt: openedAt,
    lastMessageAt: openedAt,
  );
}

/// Wraps [MockApiClient] so a test can see what went on the wire and can make
/// the next call fail.
class _SpyApiClient extends MockApiClient {
  _SpyApiClient(super.server);

  final sinceSeen = <DateTime?>[];
  final messageSinceSeen = <String?>[];
  bool offline = false;

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) async {
    sinceSeen.add(since);
    if (offline) {
      throw const ApiException(statusCode: 503, message: 'server down');
    }
    return super.getIncidents(
      limit: limit,
      state: state,
      topic: topic,
      since: since,
    );
  }

  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async {
    messageSinceSeen.add(since);
    if (offline) {
      throw const ApiException(statusCode: 503, message: 'server down');
    }
    return super.pollMessages(topic, poll: poll, since: since);
  }
}

void main() {
  sqfliteFfiInit();

  late LocalStore store;
  late _SpyApiClient api;
  late InMemoryIncidentRepository repository;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    api = _SpyApiClient(MockServer());
    repository = InMemoryIncidentRepository(api, store: store);
  });

  tearDown(() async => store.close());

  test('an empty store asks without since', () async {
    await repository.getIncidents(limit: 200);

    expect(api.sinceSeen, [null]);
  });

  test('the next sync asks with the newest opened_at held', () async {
    await store.incidents.upsertAll([_incident('inc_1', daysAgo: 3)]);

    await repository.getIncidents(limit: 200);

    expect(api.sinceSeen, [_at(3)]);
  });

  test('a full refresh asks without since even with rows held', () async {
    await store.incidents.upsertAll([_incident('inc_1', daysAgo: 3)]);

    await repository.getIncidents(limit: 200, fullRefresh: true);

    expect(api.sinceSeen, [null]);
  });

  test('a failed call still answers with the local rows', () async {
    await store.incidents.upsertAll([
      _incident('inc_1', daysAgo: 3),
      _incident('inc_2', daysAgo: 9),
    ]);
    api.offline = true;

    final result = await repository.getIncidents(limit: 200);

    expect(result.isSuccess(), isTrue);
    expect(
      result.getOrNull()!.map((i) => i.id),
      ['inc_1', 'inc_2'],
    );
  });

  test('a failed call with an empty store is a failure', () async {
    api.offline = true;

    final result = await repository.getIncidents(limit: 200);

    expect(result.isError(), isTrue);
  });

  test('the answer holds rows the server no longer returns', () async {
    // The kind of row api.md §4.2 says a hosted server has already deleted.
    await store.incidents.upsertAll([_incident('inc_ancient', daysAgo: 400)]);
    api.server.seedCalm();

    final result = await repository.getIncidents(limit: 200);

    expect(
      result.getOrNull()!.map((i) => i.id),
      contains('inc_ancient'),
    );
  });

  test('syncing the same incident twice leaves one row', () async {
    api.server.seedCalm();

    await repository.getIncidents(limit: 200, fullRefresh: true);
    final first = await store.incidents.count();
    await repository.getIncidents(limit: 200, fullRefresh: true);

    expect(await store.incidents.count(), first);
  });

  group('messages', () {
    test('polls with the newest message id held', () async {
      await store.messages.upsertAll([
        const Message(id: 'msg_1', topic: 'prod', time: 100),
      ]);

      await repository.pollMessages('prod', poll: 1);

      expect(api.messageSinceSeen, ['msg_1']);
    });

    test('a failed poll still answers with the local rows', () async {
      await store.messages.upsertAll([
        const Message(id: 'msg_1', topic: 'prod', time: 100),
      ]);
      api.offline = true;

      final result = await repository.pollMessages('prod', poll: 1);

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!.single.id, 'msg_1');
    });
  });
}
