import 'dart:async';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the calls the registry makes against the relay (api.md 4.2).
class _RecordingApi implements ApiClient {
  final registrations = <DeviceRegistration>[];
  final refreshes = <(DeviceRegistration, String)>[];
  bool fail = false;

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
  }) async {
    if (fail) throw Exception('relay unreachable');
    registrations.add(registration);
    return const DeviceRegistrationResponse(
      accountId: 'acc_1',
      caps: AccountCaps(),
      deviceToken: 'dv_1',
    );
  }

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) async {
    if (fail) throw Exception('relay unreachable');
    refreshes.add((registration, deviceToken));
    return const DeviceRegistrationResponse(
      accountId: 'acc_1',
      caps: AccountCaps(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTokens implements PushTokenProvider {
  _FakeTokens(this.token, {this.kind = PushTokenKind.fcm});

  String token;
  final _rotations = StreamController<String>.broadcast();

  @override
  final PushTokenKind kind;

  @override
  Future<String> getToken() async => token;

  @override
  Stream<String> get tokenRefreshes => _rotations.stream;

  void rotate(String next) {
    token = next;
    _rotations.add(next);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _RecordingApi api;
  late _FakeTokens tokens;

  DeviceTokenRegistry build({String platform = 'android'}) =>
      DeviceTokenRegistry(
        prefs: prefs,
        register: RegisterDeviceUsecase(
          api,
          DeviceIdentityStore(prefs),
          tokens,
          platform: () => platform,
        ),
        tokens: tokens,
        appVersion: '0.1.0',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = _RecordingApi();
    tokens = _FakeTokens('fcm-token-1');
  });

  test('launch POSTs the device with its platform kind', () async {
    await build().syncToken(null);

    expect(api.registrations, hasLength(1));
    final sent = api.registrations.single;
    expect(sent.platform, 'android');
    expect(sent.pushToken, 'fcm-token-1');
    expect(sent.appVersion, '0.1.0');
    expect(sent.deviceId, startsWith('dev_'));
    expect(prefs.getString('device_token'), 'dv_1');
  });

  test('ios sends ios as the platform kind', () async {
    await build(platform: 'ios').syncToken(null);
    expect(api.registrations.single.platform, 'ios');
  });

  test('an apns token is recorded as an apns token', () async {
    tokens = _FakeTokens('apns-token-1', kind: PushTokenKind.apns);
    await build(platform: 'ios').syncToken(null);

    expect(api.registrations.single.pushToken, 'apns-token-1');
    expect(prefs.getString(DeviceTokenRegistry.lastKindKey), 'apns');
  });

  test('the same string from a different service registers again', () async {
    await build().syncToken(null);
    expect(api.registrations, hasLength(1));

    tokens = _FakeTokens('fcm-token-1', kind: PushTokenKind.apns);
    expect(await build(platform: 'ios').syncToken(null), isTrue);
    expect(api.refreshes, hasLength(1));
    expect(prefs.getString(DeviceTokenRegistry.lastKindKey), 'apns');
  });

  test('a second launch with the same token makes no call', () async {
    final registry = build();
    expect(await registry.syncToken(null), isTrue);
    expect(await registry.syncToken(null), isFalse);
    expect(api.registrations, hasLength(1));
    expect(api.refreshes, isEmpty);
  });

  test('a rotated token PATCHes the known device', () async {
    final registry = build();
    await registry.start();
    expect(api.registrations, hasLength(1));

    await registry.syncToken('fcm-token-2');

    expect(api.refreshes, hasLength(1));
    final (sent, deviceToken) = api.refreshes.single;
    expect(sent.pushToken, 'fcm-token-2');
    expect(sent.platform, 'android');
    expect(deviceToken, 'dv_1');
    await registry.stop();
  });

  test('a rotation on the stream registers on its own', () async {
    final registry = build();
    await registry.start();
    tokens.rotate('fcm-token-3');
    await Future<void>.delayed(Duration.zero);

    expect(api.refreshes.single.$1.pushToken, 'fcm-token-3');
    await registry.stop();
  });

  test('a token left by the native handler is picked up on launch', () async {
    await prefs.setString(
      DeviceTokenRegistry.pendingNativeTokenKey,
      'fcm-token-from-native',
    );
    await build().syncToken(null);

    expect(api.registrations.single.pushToken, 'fcm-token-from-native');
    expect(prefs.getString(DeviceTokenRegistry.pendingNativeTokenKey), isNull);
  });

  test('a failed call is not recorded, so the next launch retries', () async {
    api.fail = true;
    final registry = build();
    expect(await registry.syncToken(null), isFalse);
    expect(prefs.getString(DeviceTokenRegistry.lastTokenKey), isNull);

    api.fail = false;
    expect(await registry.syncToken(null), isTrue);
    expect(api.registrations, hasLength(1));
  });

  test('a new app version re-registers on the same token', () async {
    await build().syncToken(null);
    final upgraded = DeviceTokenRegistry(
      prefs: prefs,
      register: RegisterDeviceUsecase(
        api,
        DeviceIdentityStore(prefs),
        tokens,
        platform: () => 'android',
      ),
      tokens: tokens,
      appVersion: '0.2.0',
    );

    expect(await upgraded.syncToken(null), isTrue);
    expect(api.refreshes.single.$1.appVersion, '0.2.0');
  });
}
