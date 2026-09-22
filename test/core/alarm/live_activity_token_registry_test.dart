import 'dart:io';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_alarm_host.dart';

/// Fails the first [failTimes] calls to `uploadActivityToken`, then behaves
/// like a normal [MockApiClient].
class _FlakyUploadApiClient extends MockApiClient {
  _FlakyUploadApiClient(super.server, {required this.failTimes});

  final int failTimes;
  int calls = 0;

  @override
  Future<void> uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? incidentId,
    String? activityId,
  }) async {
    calls++;
    if (calls <= failTimes) throw const SocketException('no route');
    return super.uploadActivityToken(
      deviceId: deviceId,
      deviceToken: deviceToken,
      kind: kind,
      token: token,
      incidentId: incidentId,
      activityId: activityId,
    );
  }
}

void main() {
  late FakeAlarmHost fake;
  late SharedPreferences prefs;
  late MockApiClient api;
  late DeviceIdentityStore identity;

  Future<LiveActivityTokenRegistry> build() async => LiveActivityTokenRegistry(
    prefs: prefs,
    api: api,
    identity: identity,
    host: fake.host,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'dev_test',
      'device_token': 'dv_test',
    });
    prefs = await SharedPreferences.getInstance();
    api = MockApiClient(MockServer());
    identity = DeviceIdentityStore(prefs);
    final registration = await api.registerDevice(
      const DeviceRegistration(
        deviceId: 'dev_test',
        platform: 'ios',
        pushToken: 'apns',
        appVersion: '1',
      ),
    );
    await identity.saveRegistration(
      deviceToken: registration.deviceToken!,
      accountId: registration.accountId,
      tier: registration.tier,
    );
    fake = FakeAlarmHost();
  });

  tearDown(() => fake.dispose());

  test('the push-to-start token goes up as la_start, no incident', () async {
    final registry = await build();
    final sent = await registry.upload(
      const ActivityToken(kind: ActivityTokenKind.pushToStart, token: 'aa11'),
    );

    expect(sent, isTrue);
    expect(api.activityTokens, [
      {
        'device_id': 'dev_test',
        'kind': 'la_start',
        'token': 'aa11',
        'incident_id': null,
      },
    ]);
  });

  test('a per-activity token goes up as la_update with its incident', () async {
    final registry = await build();
    await registry.upload(
      const ActivityToken(
        kind: ActivityTokenKind.update,
        activityId: 'activity_1',
        token: 'bb22',
        incidentId: 'inc_9a8b7c',
      ),
    );

    expect(api.activityTokens.single, {
      'device_id': 'dev_test',
      'kind': 'la_update',
      'token': 'bb22',
      'incident_id': 'inc_9a8b7c',
      'activity_id': 'activity_1',
    });
  });

  test('the same token twice only spends one request', () async {
    final registry = await build();
    const token = ActivityToken(
      kind: ActivityTokenKind.pushToStart,
      token: 'aa11',
    );

    expect(await registry.upload(token), isTrue);
    expect(await registry.upload(token), isFalse);
    expect(api.activityTokens, hasLength(1));
  });

  test('a rotated token of the same kind goes up again', () async {
    final registry = await build();
    await registry.upload(
      const ActivityToken(kind: ActivityTokenKind.pushToStart, token: 'aa11'),
    );
    await registry.upload(
      const ActivityToken(kind: ActivityTokenKind.pushToStart, token: 'cc33'),
    );

    expect(api.activityTokens.map((t) => t['token']), ['aa11', 'cc33']);
  });

  test('two cards each keep their own slot', () async {
    final registry = await build();
    await registry.upload(
      const ActivityToken(
        kind: ActivityTokenKind.update,
        activityId: 'activity_1',
        token: 'aa11',
        incidentId: 'inc_one',
      ),
    );
    await registry.upload(
      const ActivityToken(
        kind: ActivityTokenKind.update,
        activityId: 'activity_1',
        token: 'bb22',
        incidentId: 'inc_two',
      ),
    );

    expect(api.activityTokens, hasLength(2));
    expect(
      api.activityTokens.map((t) => t['incident_id']),
      ['inc_one', 'inc_two'],
    );
  });

  test('forgetting an incident lets its next card upload again', () async {
    final registry = await build();
    const token = ActivityToken(
      kind: ActivityTokenKind.update,
      activityId: 'activity_1',
      token: 'aa11',
      incidentId: 'inc_one',
    );

    await registry.upload(token);
    await registry.forget('inc_one');
    expect(await registry.upload(token), isTrue);
    expect(api.activityTokens, hasLength(2));
  });

  test('nothing is uploaded before the device is registered', () async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_test'});
    prefs = await SharedPreferences.getInstance();
    identity = DeviceIdentityStore(prefs);
    final registry = await build();

    expect(
      await registry.upload(
        const ActivityToken(kind: ActivityTokenKind.pushToStart, token: 'aa11'),
      ),
      isFalse,
    );
    expect(api.activityTokens, isEmpty);
  });

  test('a nil push-to-start token reads as not ready', () async {
    fake.answers['pushToStartReady'] = false;
    final registry = await build();
    await registry.start();

    expect(registry.pushToStartReady, isFalse);
    await registry.stop();
  });

  test('tokens captured before Dart was up are taken on start', () async {
    fake.answers['takePendingActivityTokens'] = <Object?>[
      {'kind': 'la_start', 'token': 'aa11'},
      {
        'kind': 'la_update',
        'token': 'bb22',
        'incident_id': 'inc_one',
        'activity_id': 'activity_1',
      },
    ];
    final registry = await build();
    await registry.start();

    expect(api.activityTokens.map((t) => t['kind']), ['la_start', 'la_update']);
    await registry.stop();
  });

  group('launch retry', () {
    test('retries an upload failure then succeeds', () async {
      final waited = <Duration>[];
      final flaky = _FlakyUploadApiClient(api.server, failTimes: 2);
      final registry = LiveActivityTokenRegistry(
        prefs: prefs,
        api: flaky,
        identity: identity,
        host: fake.host,
        wait: (d) async => waited.add(d),
      );

      final sent = await registry.upload(
        const ActivityToken(kind: ActivityTokenKind.pushToStart, token: 'aa11'),
      );

      expect(sent, isTrue);
      expect(flaky.calls, 3);
      expect(registry.launchCallsPending, isFalse);
      expect(waited, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('a resume after success does not call the API again', () async {
      final flaky = _FlakyUploadApiClient(api.server, failTimes: 0);
      final registry = LiveActivityTokenRegistry(
        prefs: prefs,
        api: flaky,
        identity: identity,
        host: fake.host,
        wait: (_) async {},
      );

      expect(
        await registry.upload(
          const ActivityToken(
            kind: ActivityTokenKind.pushToStart,
            token: 'aa11',
          ),
        ),
        isTrue,
      );
      expect(flaky.calls, 1);

      await registry.retryIfPending();

      expect(flaky.calls, 1);
    });
  });
}
