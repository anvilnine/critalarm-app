import 'dart:convert';

import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A relay name is 43 characters of base64url (api.md §3.1).
const _relayName = 'Zm9vYmFyYmF6cXV4MTIzNDU2Nzg5MGFiY2RlZmdoaWo';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsApiSessionStore sessions;
  late DeviceIdentityStore identity;
  late MockServer server;
  late HttpApiClient client;
  late List<http.Request> requests;
  late String deviceToken;
  late String baseUrl;
  late InMemoryTopicRepository repository;

  /// When set, a subscription call with this method answers 500.
  String? failSubscriptionMethod;

  String hashOf(String source) =>
      sha256.convert(utf8.encode('$baseUrl/$source')).toString();

  bool isSubscriptionCall(http.Request r) =>
      r.url.path.contains('/subscriptions');

  String hashIn(http.Request r) => r.url.pathSegments.last == 'subscriptions'
      ? (jsonDecode(r.body) as Map<String, dynamic>)['topic_hash'] as String
      : r.url.pathSegments.last;

  List<String> subscriptionCalls() => [
    for (final r in requests.where(isSubscriptionCall))
      '${r.method} ${hashIn(r)}',
  ];

  InMemoryTopicRepository newRepository() => InMemoryTopicRepository(
    client,
    sessions: sessions,
    identity: identity,
    prefs: prefs,
  );

  /// A topic list, once the moves it started have finished.
  Future<AppResult<List<Topic>>> refresh([
    InMemoryTopicRepository? repo,
  ]) async {
    final target = repo ?? repository;
    final result = await target.getTopics();
    await target.movesSettled;
    return result;
  }

  /// A topic the server already holds, with the device subscribed by name the
  /// way an app from before this change left it.
  void seedMovedFromName({String? relayName = _relayName}) {
    server
      ..seedState(
        topics: [Topic(name: 'prod', relayName: relayName)],
      )
      ..subscribeTopic(
        deviceId: 'dev_phone',
        deviceToken: deviceToken,
        topicHash: hashOf('prod'),
      );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_phone'});
    prefs = await SharedPreferences.getInstance();
    sessions = SharedPrefsApiSessionStore(prefs);
    identity = DeviceIdentityStore(prefs);
    server = MockServer();
    requests = [];
    failSubscriptionMethod = null;
    client = HttpApiClient(
      MockClient((request) async {
        requests.add(request);
        if (isSubscriptionCall(request) &&
            request.method == failSubscriptionMethod) {
          return http.Response('{"error":"boom"}', 500);
        }
        return server.handleHttpRequest(request);
      }),
      sessions,
    );
    final info = await client.getServerInfo(Uri.parse('https://typed.example'));
    baseUrl = info.baseUrl;
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
    repository = newRepository();
    requests.clear();
  });

  group('hash source', () {
    test('a relay name wins over the name', () {
      expect(
        ServerInfoValidation.hashSourceFor(name: 'prod', relayName: _relayName),
        _relayName,
      );
    });

    test('no relay name, or an empty one, falls back to the name', () {
      expect(ServerInfoValidation.hashSourceFor(name: 'prod'), 'prod');
      expect(
        ServerInfoValidation.hashSourceFor(name: 'prod', relayName: ''),
        'prod',
      );
      expect(
        ServerInfoValidation.hashSourceFor(name: 'prod', relayName: '  '),
        'prod',
      );
    });
  });

  group('create', () {
    test(
      'a topic with a relay name subscribes sha256(base_url/relay_name)',
      () async {
        server.issueRelayNames = true;
        final result = await repository.createTopic(name: 'prod');
        final created = result.getOrNull()!;
        expect(created.relayName, isNotEmpty);
        expect(server.subscriptions['dev_phone'], {hashOf(created.relayName!)});
        expect(
          server.subscriptions['dev_phone'],
          isNot(contains(hashOf('prod'))),
        );
        // Never the plain hash for a new topic that has a relay name.
        expect(
          subscriptionCalls(),
          ['POST ${hashOf(created.relayName!)}'],
        );
      },
    );

    test(
      'a topic without a relay name subscribes sha256(base_url/name)',
      () async {
        await repository.createTopic(name: 'prod');
        expect(server.subscriptions['dev_phone'], {hashOf('prod')});
        expect(subscriptionCalls(), ['POST ${hashOf('prod')}']);
      },
    );

    test('a created topic is not moved on the next refresh', () async {
      server.issueRelayNames = true;
      await repository.createTopic(name: 'prod');
      requests.clear();
      await refresh();
      expect(subscriptionCalls(), isEmpty);
    });
  });

  group('move', () {
    test('adds the secret hash first, removes the plain hash second', () async {
      seedMovedFromName();
      final result = await refresh();
      expect(result.isSuccess(), isTrue);
      expect(subscriptionCalls(), [
        'POST ${hashOf(_relayName)}',
        'DELETE ${hashOf('prod')}',
      ]);
      expect(server.subscriptions['dev_phone'], {hashOf(_relayName)});
    });

    test(
      'a failed add keeps the plain subscription and retries next refresh',
      () async {
        seedMovedFromName();
        failSubscriptionMethod = 'POST';
        final first = await refresh();
        expect(first.isSuccess(), isTrue);
        expect(subscriptionCalls(), ['POST ${hashOf(_relayName)}']);
        expect(server.subscriptions['dev_phone'], {hashOf('prod')});

        failSubscriptionMethod = null;
        requests.clear();
        await refresh();
        expect(subscriptionCalls(), [
          'POST ${hashOf(_relayName)}',
          'DELETE ${hashOf('prod')}',
        ]);
        expect(server.subscriptions['dev_phone'], {hashOf(_relayName)});
      },
    );

    test(
      'a failed remove keeps both and retries the remove next refresh',
      () async {
        seedMovedFromName();
        failSubscriptionMethod = 'DELETE';
        await refresh();
        expect(server.subscriptions['dev_phone'], {
          hashOf('prod'),
          hashOf(_relayName),
        });

        failSubscriptionMethod = null;
        requests.clear();
        await refresh();
        expect(subscriptionCalls(), contains('DELETE ${hashOf('prod')}'));
        expect(server.subscriptions['dev_phone'], {hashOf(_relayName)});
      },
    );

    test('never leaves a topic with neither subscription', () async {
      seedMovedFromName();
      final seen = <Set<String>>[];
      client = HttpApiClient(
        MockClient((request) async {
          requests.add(request);
          final response = await server.handleHttpRequest(request);
          if (isSubscriptionCall(request)) {
            seen.add({...?server.subscriptions['dev_phone']});
          }
          return response;
        }),
        sessions,
      );
      repository = newRepository();
      await refresh();
      expect(seen, isNotEmpty);
      expect(seen.every((hashes) => hashes.isNotEmpty), isTrue);
    });

    test('runs once, then not again on the next refresh', () async {
      seedMovedFromName();
      await refresh();
      requests.clear();
      await refresh();
      expect(subscriptionCalls(), isEmpty);
    });

    test('the done mark survives a new repository on the same prefs', () async {
      seedMovedFromName();
      await refresh();
      requests.clear();
      await refresh(newRepository());
      expect(subscriptionCalls(), isEmpty);
    });

    test('the done mark is per server', () async {
      seedMovedFromName();
      await refresh();
      // Same topic name on another server is not moved by the mark above.
      final other = ApiSession(
        baseUri: Uri.parse('https://other.example'),
        relayUri: Uri.parse(server.serverInfo.relayUrl),
        mode: ServerMode.selfhosted,
        managementCredential: 'ad_management',
      );
      await sessions.write(other);
      requests.clear();
      await refresh();
      expect(
        subscriptionCalls().first,
        startsWith('POST'),
        reason: 'a different server starts its own move',
      );
    });

    test('a topic with no relay name is left alone', () async {
      seedMovedFromName(relayName: null);
      await refresh();
      await refresh();
      expect(subscriptionCalls(), isEmpty);
      expect(server.subscriptions['dev_phone'], {hashOf('prod')});
    });

    test('a device with no push token makes no relay call', () async {
      seedMovedFromName();
      await identity.clear();
      requests.clear();
      final result = await refresh();
      expect(result.isSuccess(), isTrue);
      expect(subscriptionCalls(), isEmpty);
    });
  });

  group('delete', () {
    test('halfway through a move removes both hashes', () async {
      seedMovedFromName();
      failSubscriptionMethod = 'DELETE';
      await refresh();
      expect(server.subscriptions['dev_phone'], hasLength(2));

      failSubscriptionMethod = null;
      requests.clear();
      final result = await repository.deleteTopic('prod');
      expect(result.isSuccess(), isTrue);
      expect(
        subscriptionCalls().toSet(),
        {'DELETE ${hashOf('prod')}', 'DELETE ${hashOf(_relayName)}'},
      );
      expect(server.subscriptions['dev_phone'], isEmpty);
    });

    test('after a finished move removes the secret hash', () async {
      seedMovedFromName();
      await refresh();
      final result = await repository.deleteTopic('prod');
      expect(result.isSuccess(), isTrue);
      expect(server.subscriptions['dev_phone'], isEmpty);
    });

    test('works on a fresh repository that never listed topics', () async {
      seedMovedFromName();
      await refresh();
      final result = await newRepository().deleteTopic('prod');
      expect(result.isSuccess(), isTrue);
      expect(server.subscriptions['dev_phone'], isEmpty);
    });

    test('a topic with no relay name removes the plain hash', () async {
      await repository.createTopic(name: 'prod');
      requests.clear();
      await repository.deleteTopic('prod');
      expect(subscriptionCalls(), ['DELETE ${hashOf('prod')}']);
      expect(server.subscriptions['dev_phone'], isEmpty);
    });
  });

  group('secret', () {
    test('the relay name is not in toString or in any printed line', () async {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = original);

      seedMovedFromName();
      final topic = (await refresh()).getOrNull()!.single;
      expect(topic.relayName, _relayName);
      expect(topic.toString(), isNot(contains(_relayName)));
      await repository.deleteTopic('prod');

      expect(printed.join('\n'), isNot(contains(_relayName)));
    });

    test(
      'a failure message built from a failed move does not carry it',
      () async {
        seedMovedFromName();
        failSubscriptionMethod = 'POST';
        final result = await refresh();
        expect('${result.getOrNull()}', isNot(contains(_relayName)));
      },
    );
  });
}
