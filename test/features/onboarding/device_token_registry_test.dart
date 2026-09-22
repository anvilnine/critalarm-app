import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;
  @override
  Future<String> getToken() async => 'apns_test';
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

/// Fails the first [failTimes] calls to `registerDevice`, then behaves like
/// a normal [MockApiClient].
class _FlakyApiClient extends MockApiClient {
  _FlakyApiClient(super.server, this.failTimes);

  final int failTimes;
  int calls = 0;

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    calls++;
    if (calls <= failTimes) throw const SocketException('no route');
    return super.registerDevice(
      registration,
      relayUri: relayUri,
      accountJoinToken: accountJoinToken,
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DeviceTokenRegistry build(_FlakyApiClient api) => DeviceTokenRegistry(
    prefs: prefs,
    register: RegisterDeviceUsecase(
      api,
      DeviceIdentityStore(prefs),
      _Tokens(),
      platform: () => 'ios',
    ),
    tokens: _Tokens(),
    appVersion: '1',
    wait: (_) async {},
  );

  test('a first-call failure followed by success registers once', () async {
    final api = _FlakyApiClient(MockServer(), 2);
    final registry = build(api);

    final registered = await registry.syncToken(null);

    expect(registered, isTrue);
    expect(api.calls, 3);
    expect(registry.launchCallsPending, isFalse);
  });

  test('a resume after success does not call the API again', () async {
    final api = _FlakyApiClient(MockServer(), 0);
    final registry = build(api);

    expect(await registry.syncToken(null), isTrue);
    expect(api.calls, 1);

    await registry.retryIfPending();

    expect(api.calls, 1);
  });

  test('a run that never recovers leaves launchCallsPending true', () async {
    final api = _FlakyApiClient(MockServer(), 999);
    final registry = build(api);

    expect(await registry.syncToken(null), isFalse);
    expect(registry.launchCallsPending, isTrue);
  });
}
