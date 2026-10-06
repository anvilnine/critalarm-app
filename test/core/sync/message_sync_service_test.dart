import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingApi implements ApiClient {
  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async => throw Exception('offline');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MockServer server;
  late MockApiClient api;
  late MessageSyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = MockServer();
    api = MockApiClient(server);
    sync = MessageSyncService(prefs, api);
    server.createTopic(name: 'prod');
  });

  test('the first poll has no cursor and returns priority 1-3', () async {
    server
      ..publishMessage('prod', message: 'low', priority: 1)
      ..publishMessage('prod', message: 'default');

    final fresh = await sync.syncTopic('prod');

    expect(fresh.map((m) => m.message), ['low', 'default']);
  });

  test('priority 4 and 5 are left to push', () async {
    server
      ..publishMessage('prod', message: 'quiet', priority: 2)
      ..publishMessage('prod', message: 'urgent', priority: 4)
      ..publishMessage('prod', message: 'critical', priority: 5);

    final fresh = await sync.syncTopic('prod');

    expect(fresh.map((m) => m.message), ['quiet']);
  });

  test('the cursor moves on, so a second poll returns nothing new', () async {
    server.publishMessage('prod', message: 'first');
    await sync.syncTopic('prod');
    expect(sync.lastMessageId('prod'), isNotNull);

    expect(await sync.syncTopic('prod'), isEmpty);

    server.publishMessage('prod', message: 'second');
    final fresh = await sync.syncTopic('prod');
    expect(fresh.map((m) => m.message), ['second']);
  });

  test('the cursor passes the newest message, push or poll', () async {
    server
      ..publishMessage('prod', message: 'quiet', priority: 2)
      ..publishMessage('prod', message: 'urgent', priority: 4);
    await sync.syncTopic('prod');

    // The priority 4 row was the last one returned, so it is the new cursor
    // and is not walked over again.
    expect(await sync.syncTopic('prod'), isEmpty);
  });

  test('resetting the cursor goes back to the server default', () async {
    server.publishMessage('prod', message: 'first');
    await sync.syncTopic('prod');
    await sync.resetCursor('prod');

    expect(sync.lastMessageId('prod'), isNull);
    expect(await sync.syncTopic('prod'), hasLength(1));
  });

  test('every topic is polled, and one failing does not stop the rest',
      () async {
    server
      ..createTopic(name: 'staging')
      ..publishMessage('prod', message: 'prod message')
      ..publishMessage('staging', message: 'staging message', priority: 2);

    final result = await sync.syncAll(['prod', 'staging', 'missing']);

    expect(result.keys, containsAll(['prod', 'staging']));
    expect(result['prod']!.single.message, 'prod message');
    expect(result['staging']!.single.message, 'staging message');
  });

  test('a topic that throws is skipped and keeps its cursor', () async {
    final offline = MessageSyncService(prefs, _FailingApi());
    expect(await offline.syncAll(['prod']), isEmpty);
    expect(offline.lastMessageId('prod'), isNull);
  });
}
