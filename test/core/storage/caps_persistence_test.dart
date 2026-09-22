import 'dart:convert';

import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements PushTokenProvider {
  @override
  Future<String> getToken() async => 'apns';
  @override
  PushTokenKind get kind => PushTokenKind.apns;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

class _Api extends MockApiClient {
  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async => DeviceRegistrationResponse(
    accountId: 'acc',
    deviceToken: 'dv_token',
    tier: 'relay',
    caps: AccountCaps.fromJson({
      'devices': 5,
      'critical_topics': null,
      'p4_daily': 1000,
      'history_days': 90,
    }),
  );
}

void main() {
  // `history_incidents` was removed in 1.16.0 (api.md §4.2). A server that
  // still sends it is ignored, and its absence is no limit.
  test('null and absent caps are unlimited; history caps parse', () {
    for (final json in [
      <String, dynamic>{},
      <String, dynamic>{
        'devices': null,
        'critical_topics': null,
        'p4_daily': null,
        'history_incidents': null,
        'history_days': null,
      },
    ]) {
      final caps = AccountCaps.fromJson(json);
      expect([
        caps.devices,
        caps.criticalTopics,
        caps.p4Daily,
        caps.historyDays,
      ], everyElement(isNull));
      expect(AccountCaps.fromJson(caps.toJson()), caps);
    }
    final caps = AccountCaps.fromJson({
      'history_incidents': 20,
      'history_days': 7,
    });
    expect(caps.historyDays, 7);
  });

  for (final keychain in [false, true]) {
    test(
      'caps survive ${keychain ? 'Keychain' : 'preferences'} recreation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        const channel = MethodChannel('a7/identity');
        // One slot per Keychain service, because the identity lives in two
        // items now.
        final stored = <String, String>{};
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = (call.arguments as Map).cast<String, Object?>();
              final service = args['service']! as String;
              if (call.method == 'write') {
                stored[service] = args['value']! as String;
              }
              if (call.method == 'delete') stored.remove(service);
              return call.method == 'read' ? stored[service] : null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        DeviceIdentityStore store() => keychain
            ? KeychainDeviceIdentityStore(prefs, channel: channel)
            : DeviceIdentityStore(prefs);
        await RegisterDeviceUsecase(
          _Api(),
          store(),
          _Tokens(),
          platform: () => 'ios',
        )(appVersion: '1');
        final caps = (await store().readOrCreate()).caps;
        expect(caps.criticalTopics, isNull);
        expect(caps.historyDays, 90);
        expect(caps.devices, 5);
        expect(caps.p4Daily, 1000);
        await store().saveRegistration(
          deviceToken: 'dv_token',
          accountId: 'acc',
          tier: 'free',
          caps: AccountCaps.free,
        );
        expect((await store().readOrCreate()).caps, AccountCaps.free);
        if (keychain) {
          expect(
            (jsonDecode(stored[KeychainDeviceIdentityStore.deviceService]!)
                as Map<String, dynamic>)['caps'],
            AccountCaps.free.toJson(),
          );
        }
      },
    );
  }
}
