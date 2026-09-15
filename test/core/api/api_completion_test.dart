import 'dart:convert';

import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsApiSessionStore sessions;
  late DeviceIdentityStore identity;
  late MockServer server;
  late HttpApiClient client;
  late List<http.Request> requests;
  late String deviceToken;
  late InMemoryTopicRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_phone'});
    final prefs = await SharedPreferences.getInstance();
    sessions = SharedPrefsApiSessionStore(prefs);
    identity = DeviceIdentityStore(prefs);
    server = MockServer();
    requests = [];
    client = HttpApiClient(
      MockClient((request) async {
        requests.add(request);
        return server.handleHttpRequest(request);
      }),
      sessions,
    );
    final info = await client.getServerInfo(Uri.parse('https://typed.example'));
    await sessions.write(
      ApiSession(
        baseUri: Uri.parse(info.baseUrl),
        relayUri: Uri.parse(info.relayUrl),
        mode: ServerMode.selfhosted,
        managementCredential: 'ad_management',
      ),
    );
    final registration = await client.registerDevice(
      const DeviceRegistration(
        deviceId: 'dev_phone',
        platform: 'ios',
        pushToken: 'apns_1',
        appVersion: '1',
      ),
    );
    deviceToken = registration.deviceToken!;
    await identity.saveRegistration(
      deviceToken: deviceToken,
      accountId: registration.accountId,
      tier: registration.tier,
      caps: registration.caps,
    );
    repository = InMemoryTopicRepository(
      client,
      sessions: sessions,
      identity: identity,
    );
    requests.clear();
  });

  test(
    'topic add/remove subscribe to info base_url hash on relay with dv bearer',
    () async {
      final result = await repository.createTopic(name: 'prod');
      expect(result.isSuccess(), isTrue);
      final hash = sha256
          .convert(utf8.encode('${server.serverInfo.baseUrl}/prod'))
          .toString();
      expect(
        hash,
        isNot(
          sha256.convert(utf8.encode('https://typed.example/prod')).toString(),
        ),
      );
      final post = requests.singleWhere(
        (r) => r.url.path.endsWith('/subscriptions'),
      );
      expect(post.method, 'POST');
      expect(
        post.url.toString(),
        '${server.serverInfo.relayUrl}/relay/v1/devices/dev_phone/subscriptions',
      );
      expect(post.headers['authorization'], 'Bearer $deviceToken');
      expect(jsonDecode(post.body), {'topic_hash': hash});
      await client.subscribeTopic(
        deviceId: 'dev_phone',
        deviceToken: deviceToken,
        topicHash: hash,
      );
      expect(server.subscriptions['dev_phone'], {hash});
      expect((await repository.deleteTopic('prod')).isSuccess(), isTrue);
      final delete = requests.singleWhere(
        (r) => r.method == 'DELETE' && r.url.path.contains('/subscriptions/'),
      );
      expect(
        delete.url.toString(),
        '${server.serverInfo.relayUrl}/relay/v1/devices/dev_phone/subscriptions/$hash',
      );
      expect(delete.headers['authorization'], 'Bearer $deviceToken');
      expect(server.subscriptions['dev_phone'], isEmpty);
    },
  );

  test(
    'subscribe cap survives repository boundary and failed creation is removed',
    () async {
      await repository.createTopic(name: 'one');
      await repository.createTopic(name: 'two');
      final result = await repository.createTopic(name: 'three');
      expect(
        result.exceptionOrNull(),
        isA<ApiFailure>()
            .having((f) => f.statusCode, 'status', 429)
            .having((f) => f.cap, 'cap', 'critical_topics'),
      );
      expect(server.getTopics().map((t) => t.name), ['one', 'two']);
    },
  );

  test(
    'duplicate topic is a named failure and retains the original subscription',
    () async {
      await repository.createTopic(name: 'prod');
      final result = await repository.createTopic(name: 'prod');
      expect(result.exceptionOrNull(), isA<TopicAlreadyExistsFailure>());
      expect(server.subscriptions['dev_phone'], hasLength(1));
    },
  );

  test(
    'poll uses ndjson, management auth and exclusive paging',
    () async {
      server.createTopic(name: 'logs');
      final first = server.publishMessage('logs', message: 'first');
      final second = server.publishMessage('logs', message: 'second');
      final messages = await client.pollMessages('logs', poll: 1, since: 'all');
      expect(messages.map((m) => m.id), [first.id, second.id]);
      expect(requests.last.headers['authorization'], 'Bearer ad_management');
      expect(requests.last.headers['accept'], 'application/x-ndjson');
      expect(
        requests.last.url.toString(),
        '${server.serverInfo.baseUrl}/logs/json?poll=1&since=all',
      );
      expect(
        (await client.pollMessages(
          'logs',
          poll: 1,
          since: first.id,
        )).map((m) => m.id),
        [second.id],
      );
      expect(requests.last.url.queryParameters['since'], first.id);
      expect(
        await client.pollMessages('logs', poll: 1, since: second.id),
        isEmpty,
      );
      expect(
        await client.pollMessages('logs', poll: 1, since: 'm_unknown'),
        isEmpty,
      );
      expect(await client.pollMessages('empty', poll: 1), isEmpty);
      for (final since in ['10m', '1757462400', 'm_id +/&']) {
        await client.pollMessages('logs', poll: 1, since: since);
        expect(requests.last.url.queryParameters['since'], since);
      }
      final session = (await sessions.read())!;
      await sessions.write(
        ApiSession(
          baseUri: session.baseUri,
          relayUri: session.relayUri,
          mode: ServerMode.hosted,
          managementCredential: deviceToken,
        ),
      );
      await client.pollMessages('logs', poll: 1);
      expect(requests.last.headers['authorization'], 'Bearer $deviceToken');
      expect(
        requests.any((r) => (r.headers['authorization'] ?? '').contains('tk_')),
        isFalse,
      );
    },
  );

  test(
    'send uses management route, defaults priority to 3, parses null incident',
    () async {
      await client.createTopic(name: 'prod');
      final result = await client.publishMessage('prod', message: 'hello');
      expect(result.id, startsWith('m_'));
      expect(result.incidentId, isNull);
      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, '/v1/topics/prod/send');
      expect(requests.last.headers['authorization'], 'Bearer ad_management');
      expect(jsonDecode(requests.last.body), {
        'message': 'hello',
        'priority': 3,
      });
      await client.updateTopic('prod', critical: true);
      final urgent = await client.publishMessage(
        'prod',
        message: 'down',
        title: 'DB',
        priority: 5,
        tags: ['warning'],
      );
      expect(urgent.incidentId, startsWith('inc_'));
      expect(jsonDecode(requests.last.body), {
        'message': 'down',
        'title': 'DB',
        'priority': 5,
        'tags': ['warning'],
      });
    },
  );

  test(
    'create shape and both token responses carry revocable token ids',
    () async {
      final topic = await client.createTopic(name: 'prod', critical: true);
      expect(jsonDecode(requests.last.body), {
        'name': 'prod',
        'critical': true,
      });
      expect(topic.tokenId, startsWith('tok_'));
      final token = await client.createTopicToken('prod');
      expect(token.token, startsWith('tk_'));
      expect(token.tokenId, startsWith('tok_'));
      await client.deleteTopicToken('prod', topic.tokenId!);
      expect(requests.last.url.path, '/v1/topics/prod/tokens/${topic.tokenId}');
    },
  );

  test('device patch body contains only push token and version', () async {
    final result = await client.refreshDevice(
      const DeviceRegistration(
        deviceId: 'dev_phone',
        platform: 'ios',
        pushToken: 'new',
        appVersion: '2',
      ),
      deviceToken,
    );
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.host, Uri.parse(server.serverInfo.relayUrl).host);
    expect(requests.last.headers['authorization'], 'Bearer $deviceToken');
    expect(jsonDecode(requests.last.body), {
      'push_token': 'new',
      'app_version': '2',
    });
    expect(result.deviceToken, isNull);
  });

  test(
    'la_update carries activity id; apns omits activity and incident',
    () async {
      await client.uploadActivityToken(
        deviceId: 'dev_phone',
        deviceToken: deviceToken,
        kind: 'la_update',
        token: 'update',
        activityId: 'activity_1',
        incidentId: 'inc_1',
      );
      expect(jsonDecode(requests.last.body), {
        'kind': 'la_update',
        'token': 'update',
        'activity_id': 'activity_1',
        'incident_id': 'inc_1',
      });
      await client.uploadActivityToken(
        deviceId: 'dev_phone',
        deviceToken: deviceToken,
        kind: 'apns',
        token: 'apns',
        activityId: 'ignored',
        incidentId: 'ignored',
      );
      expect(jsonDecode(requests.last.body), {'kind': 'apns', 'token': 'apns'});
      await expectLater(
        client.uploadActivityToken(
          deviceId: 'dev_phone',
          deviceToken: deviceToken,
          kind: 'la_update',
          token: 'update',
        ),
        throwsArgumentError,
      );
    },
  );
}
