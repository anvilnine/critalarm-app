import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

void main() {
  group('NotificationPermissionsCubit', () {
    test('initial state has no step and cannot navigate', () async {
      final cubit = PermissionPhone.ios26().cubit();

      expect(cubit.state.step, NotificationPermissionStep.initial);
      expect(cubit.state.current, isNull);
      expect(cubit.state.currentIndex, -1);
      expect(cubit.state.shown, isEmpty);
      expect(cubit.state.canNavigate, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('the main button does nothing before a step is on screen', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit();

      await cubit.allowCurrentStep();

      expect(phone.notifications.requests, 0);
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    test(
      'granting notifications emits requesting, then the next step',
      () async {
        final phone = PermissionPhone.ios26();
        final cubit = phone.cubit();
        await cubit.refresh();
        final states = record(cubit);

        await cubit.allowCurrentStep();
        await pumpEventQueue();

        expect(states.map((state) => state.step), const [
          NotificationPermissionStep.requesting,
          NotificationPermissionStep.initial,
        ]);
        expect(states.first.current, PermissionSetupStep.iosNotifications);
        expect(states.last.current, PermissionSetupStep.iosAlarms);
        expect(states.last.granted, {PermissionSetupStep.iosNotifications});
        expect(states.last.currentIndex, 1);
        await cubit.close();
      },
    );

    test('refused notifications move on instead of a denied screen', () async {
      final phone = PermissionPhone.ios26()
        ..notifications.requestAnswer = NotificationPermissionStatus.denied;
      final cubit = phone.cubit();
      await cubit.refresh();

      await cubit.allowCurrentStep();

      expect(cubit.state.isDenied, isFalse);
      expect(cubit.state.current, PermissionSetupStep.iosAlarms);
      expect(cubit.state.granted, isEmpty);
      await cubit.close();
    });

    test('a failed notification request moves on too', () async {
      final phone = PermissionPhone.ios26()..notifications.requestFails = true;
      final cubit = phone.cubit();
      await cubit.refresh();

      await cubit.allowCurrentStep();

      expect(cubit.state.current, PermissionSetupStep.iosAlarms);
      expect(cubit.state.isRequesting, isFalse);
      await cubit.close();
    });

    test(
      'the alarm step asks AlarmKit, starts the activity, and finishes',
      () async {
        final phone = PermissionPhone.ios26()..grantNotifications();
        phone.alarm.answers['requestAuthorization'] = 'authorized';
        final cubit = phone.cubit();
        await cubit.refresh();

        await cubit.allowCurrentStep();

        expect(phone.alarm.callsTo('requestAuthorization'), hasLength(1));
        expect(
          phone.alarm.argsOnce('startLocalActivity')['incident_id'],
          NotificationPermissionsCubit.onboardingIncidentId,
        );
        expect(cubit.state.alarm, AlarmAuthorization.authorized);
        expect(cubit.state.liveActivityStarted, isTrue);
        expect(cubit.state.granted, contains(PermissionSetupStep.iosAlarms));
        expect(cubit.state.canNavigate, isTrue);
        await cubit.close();
      },
    );

    test('the explainer only moves on, and asks for nothing', () async {
      final phone = PermissionPhone.iosOld();
      final cubit = phone.cubit();
      await cubit.refresh();
      await cubit.allowCurrentStep();
      expect(
        cubit.state.current,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      );

      await cubit.allowCurrentStep();

      expect(cubit.state.canNavigate, isTrue);
      expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
      expect(phone.alarm.callsTo('startLocalActivity'), isEmpty);
      await cubit.close();
    });

    test('the battery step opens the battery screen and waits', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();
      await cubit.refresh();
      expect(cubit.state.current, PermissionSetupStep.androidBattery);

      await cubit.allowCurrentStep();

      expect(phone.device.opened, [DevicePermissionType.batteryOptimization]);
      expect(cubit.state.current, PermissionSetupStep.androidBattery);
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    test('"Not now" on the battery step finishes', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();
      await cubit.refresh();

      cubit.skipStep();

      expect(cubit.state.canNavigate, isTrue);
      expect(phone.device.opened, isEmpty);
      await cubit.close();
    });

    test('openSettings opens the notification settings', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit();

      await cubit.openSettings();

      expect(phone.notifications.settingsOpened, 1);
      await cubit.close();
    });

    test('navigationHandled clears canNavigate', () async {
      final cubit = PermissionPhone.ios26().cubit()..continueWithout();
      expect(cubit.state.canNavigate, isTrue);

      cubit.navigationHandled();

      expect(cubit.state.canNavigate, isFalse);
      expect(cubit.state.isGranted, isTrue);
      await cubit.close();
    });

    test(
      'a finished cubit does not finish again when the app comes back',
      () async {
        final phone = PermissionPhone.ios26(alarmStatus: 'authorized')
          ..grantNotifications();
        final cubit = phone.cubit();
        await cubit.refresh();
        cubit.navigationHandled();
        final states = record(cubit);

        await cubit.refresh();
        await pumpEventQueue();

        expect(states, isEmpty);
        expect(cubit.state.canNavigate, isFalse);
        await cubit.close();
      },
    );
  });

  group('the state', () {
    test('counts the step on screen from zero', () {
      const state = NotificationPermissionsState(
        steps: [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
          PermissionSetupStep.androidBattery,
        ],
        current: PermissionSetupStep.androidFullScreen,
      );

      expect(state.currentIndex, 1);
      expect(state.shown, {
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      });
    });

    test('two states with the same steps and grants are equal', () {
      // Built at run time, so equality is on the contents and not on two
      // names for one constant.
      NotificationPermissionsState build() => NotificationPermissionsState(
        steps: List.of(const [
          PermissionSetupStep.iosNotifications,
          PermissionSetupStep.iosAlarms,
        ]),
        current: PermissionSetupStep.iosAlarms,
        granted: Set.of(const {PermissionSetupStep.iosNotifications}),
      );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(
        build(),
        isNot(build().copyWith(current: PermissionSetupStep.iosNotifications)),
      );
    });
  });
}
