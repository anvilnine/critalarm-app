import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

void main() {
  group('reading the setup permissions', () {
    test('iOS 26: both steps, each with its own status', () async {
      final phone = PermissionPhone.ios26()..grantNotifications();

      final snapshot = await phone.read();

      expect(snapshot.steps, const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosAlarms,
      ]);
      expect(snapshot.granted, {PermissionSetupStep.iosNotifications});
      expect(snapshot.alarm, AlarmAuthorization.notDetermined);
      expect(snapshot.everyGranted, isFalse);
    });

    test('iOS 26: AlarmKit authorized grants the alarm step', () async {
      final phone = PermissionPhone.ios26(alarmStatus: 'authorized')
        ..grantNotifications();

      final snapshot = await phone.read();

      expect(snapshot.everyGranted, isTrue);
    });

    test('iOS 26: a refused AlarmKit is not granted', () async {
      final phone = PermissionPhone.ios26(alarmStatus: 'denied')
        ..grantNotifications();

      final snapshot = await phone.read();

      expect(snapshot.alarm, AlarmAuthorization.denied);
      expect(snapshot.everyGranted, isFalse);
    });

    test('iOS 16 to 25: judged on notifications alone', () async {
      final phone = PermissionPhone.iosOld();
      expect((await phone.read()).everyGranted, isFalse);

      phone.grantNotifications();
      final snapshot = await phone.read();

      expect(snapshot.steps, const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      ]);
      expect(snapshot.everyGranted, isTrue);
    });

    test('iOS never reads the maker or an Android permission', () async {
      final phone = PermissionPhone.ios26();

      await phone.read();

      expect(phone.maker.reads, 0);
      expect(phone.device.checked, isEmpty);
    });

    test('Android: needs notifications and the full-screen alarm', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      expect((await phone.read()).everyGranted, isFalse);

      phone.device.grant(DevicePermissionType.fullScreenIntent);

      expect((await phone.read()).everyGranted, isTrue);
    });

    test('Android never asks the alarm channel', () async {
      final phone = PermissionPhone.android();

      final snapshot = await phone.read();

      expect(phone.alarm.calls, isEmpty);
      expect(snapshot.alarm, AlarmAuthorization.unsupported);
    });

    test('Android on a Pixel never reads the battery exemption', () async {
      final phone = PermissionPhone.android();

      final snapshot = await phone.read();

      expect(
        snapshot.steps,
        isNot(contains(PermissionSetupStep.androidBattery)),
      );
      expect(
        phone.device.checked,
        isNot(contains(DevicePermissionType.batteryOptimization)),
      );
    });

    test('Android on a listed maker: battery counts too', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications();
      phone.device.grant(DevicePermissionType.fullScreenIntent);

      final missing = await phone.read();
      expect(missing.steps.last, PermissionSetupStep.androidBattery);
      expect(missing.everyGranted, isFalse);

      phone.device.grant(DevicePermissionType.batteryOptimization);
      expect((await phone.read()).everyGranted, isTrue);
    });

    test('nothing is remembered between reads', () async {
      final phone = PermissionPhone.android();
      expect((await phone.read()).granted, isEmpty);

      // Granted behind the app's back, as a store can do at install.
      phone
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);

      expect((await phone.read()).granted, {
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      });
    });

    test('web: no steps, so nothing to grant and nothing read', () async {
      final phone = PermissionPhone(TargetPlatform.android, isWeb: true);

      final snapshot = await phone.read();

      expect(snapshot.steps, isEmpty);
      expect(snapshot.everyGranted, isTrue);
      expect(phone.notifications.checks, 0);
      expect(phone.maker.reads, 0);
    });

    test('an unknown maker is not a listed one', () async {
      final phone = PermissionPhone.android(maker: DeviceMaker.unknown);

      expect(
        (await phone.read()).steps,
        isNot(contains(PermissionSetupStep.androidBattery)),
      );
    });
  });
}
