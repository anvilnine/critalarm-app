import 'dart:io';

import 'package:critalarm/core/models/device_registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AccountCaps.free matches the free column in docs/api.md', () {
    final api = File('docs/api.md').readAsStringSync();
    int free(String cap) => int.parse(
      RegExp(
        '^\\| `$cap` \\| (\\d+) \\|',
        multiLine: true,
      ).firstMatch(api)!.group(1)!,
    );
    expect(AccountCaps.free.criticalTopics, free('critical_topics'));
    expect(AccountCaps.free.p4Daily, free('p4_daily'));
    expect(AccountCaps.free.historyDays, free('history_days'));
  });

  group('AccountCaps', () {
    // The `free` column of the cap table in docs/api.md §4.2.
    test('defaults match the contract cap table', () {
      const caps = AccountCaps.free;

      expect(caps.devices, 5);
      expect(caps.criticalTopics, 2);
      expect(caps.historyDays, 7);
      expect(caps.p4Daily, 50);
    });

    test('serializes and deserializes JSON roundtrip', () {
      const caps = AccountCaps(
        devices: 5,
        criticalTopics: 3,
        p4Daily: 100,
      );

      final json = caps.toJson();
      expect(json['devices'], 5);
      expect(json['critical_topics'], 3);
      expect(json['p4_daily'], 100);

      final deserialized = AccountCaps.fromJson(json);
      expect(deserialized.devices, 5);
      expect(deserialized.criticalTopics, 3);
      expect(deserialized.p4Daily, 100);
    });
  });

  group('DeviceRegistration', () {
    test('serializes and deserializes JSON roundtrip', () {
      const reg = DeviceRegistration(
        deviceId: 'dev_123',
        platform: 'ios',
        pushToken: 'push_token_abc',
        appVersion: '1.0.0',
      );

      final json = reg.toJson();
      expect(json['device_id'], 'dev_123');
      expect(json['platform'], 'ios');
      expect(json['push_token'], 'push_token_abc');
      expect(json['app_version'], '1.0.0');

      final deserialized = DeviceRegistration.fromJson(json);
      expect(deserialized.deviceId, 'dev_123');
      expect(deserialized.platform, 'ios');
      expect(deserialized.pushToken, 'push_token_abc');
      expect(deserialized.appVersion, '1.0.0');
    });
  });

  group('DeviceRegistrationResponse', () {
    test('serializes and deserializes JSON roundtrip', () {
      const response = DeviceRegistrationResponse(
        deviceToken: 'dv_token_xyz',
        accountId: 'acc_456',
        caps: AccountCaps(devices: 2, criticalTopics: 2, p4Daily: 100),
      );

      final json = response.toJson();
      expect(json['device_token'], 'dv_token_xyz');
      expect(json['account_id'], 'acc_456');
      expect(json['tier'], 'free');
      final capsJson = json['caps'] as Map<String, dynamic>;
      expect(capsJson['devices'], 2);

      final deserialized = DeviceRegistrationResponse.fromJson(json);
      expect(deserialized.deviceToken, 'dv_token_xyz');
      expect(deserialized.accountId, 'acc_456');
      expect(deserialized.tier, 'free');
      expect(deserialized.caps.devices, 2);
      expect(deserialized.caps.criticalTopics, 2);
      expect(deserialized.caps.p4Daily, 100);
    });
  });
}
