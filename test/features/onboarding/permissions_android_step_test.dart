import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

void main() {
  group('Android step 2 is the full-screen alarm permission', () {
    test(
      'Android never gets the iOS 26 copy, whatever the alarm channel says',
      () {
        for (final auth in AlarmAuthorization.values) {
          expect(
            RingClaim.forPhone(
              auth,
              platform: TargetPlatform.android,
              isWeb: false,
            ),
            RingClaim.alarm,
          );
        }
      },
    );

    test('no Android run ever lands on an iOS step', () async {
      for (final maker in [pixel, samsung]) {
        final phone = PermissionPhone.android(maker: maker);
        final cubit = phone.cubit(replayForDemo: true);
        final states = record(cubit);

        await cubit.refresh();
        cubit
          ..skipStep()
          ..skipStep()
          ..skipStep();
        await pumpEventQueue();

        const ios = {
          PermissionSetupStep.iosNotifications,
          PermissionSetupStep.iosAlarms,
          PermissionSetupStep.iosTimeSensitiveExplainer,
        };
        expect(
          states.where((state) => ios.contains(state.current)),
          isEmpty,
        );
        expect(
          states.expand((state) => state.steps).toSet().intersection(ios),
          isEmpty,
        );
        await cubit.close();
      }
    });

    test(
      'with notifications granted it opens on the full-screen step',
      () async {
        final phone = PermissionPhone.android()..grantNotifications();
        final cubit = phone.cubit();

        await cubit.refresh();

        expect(cubit.state.current, PermissionSetupStep.androidFullScreen);
        expect(cubit.state.granted, {PermissionSetupStep.androidNotifications});
        expect(cubit.state.canNavigate, isFalse);
        expect(
          RingClaim.forPhone(
            cubit.state.alarm,
            platform: TargetPlatform.android,
            isWeb: false,
          ),
          RingClaim.alarm,
        );
        await cubit.close();
      },
    );

    test('both granted lets onboarding move on', () async {
      final phone = PermissionPhone.android()
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();

      await cubit.refresh();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('the button opens the full-screen settings page and waits', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      final cubit = phone.cubit();

      await cubit.refresh();
      await cubit.allowCurrentStep();

      expect(phone.device.opened, [DevicePermissionType.fullScreenIntent]);
      expect(cubit.state.canNavigate, isFalse);
      expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
      await cubit.close();
    });

    test('standalone closes at once when it is already granted', () async {
      final phone = PermissionPhone.android()
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit(standalone: true);

      await cubit.refresh();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('Not now on step 1 reaches step 2 on Android', () async {
      final phone = PermissionPhone.android();
      final cubit = phone.cubit();

      await cubit.refresh();
      cubit.skipStep();

      expect(cubit.state.current, PermissionSetupStep.androidFullScreen);
      expect(cubit.state.currentIndex, 1);
      expect(phone.notifications.requests, 0);
      await cubit.close();
    });
  });

  group('Android step 3 is battery, on the makers that need it', () {
    test('a Pixel finishes after the full-screen step', () async {
      final phone = PermissionPhone.android();
      final cubit = phone.cubit();

      await cubit.refresh();
      expect(cubit.state.steps, hasLength(2));
      cubit
        ..skipStep()
        ..skipStep();

      expect(cubit.state.canNavigate, isTrue);
      expect(
        phone.device.checked,
        isNot(contains(DevicePermissionType.batteryOptimization)),
      );
      await cubit.close();
    });

    test('a listed maker gets battery third', () async {
      final phone = PermissionPhone.android(maker: samsung);
      final cubit = phone.cubit();

      await cubit.refresh();
      expect(cubit.state.steps, hasLength(3));
      cubit
        ..skipStep()
        ..skipStep();

      expect(cubit.state.current, PermissionSetupStep.androidBattery);
      expect(cubit.state.currentIndex, 2);
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    test('a listed maker already exempt never sees it', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..device.grant(DevicePermissionType.batteryOptimization);
      final cubit = phone.cubit();

      await cubit.refresh();
      expect(cubit.state.steps, const [
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      ]);
      cubit
        ..skipStep()
        ..skipStep();

      expect(cubit.state.canNavigate, isTrue);
      expect(phone.device.opened, isEmpty);
      await cubit.close();
    });
  });
}
