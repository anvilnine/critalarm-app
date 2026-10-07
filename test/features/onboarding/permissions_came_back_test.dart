import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

/// A user who goes Back to the permissions from a later step sees every
/// permission of this phone with its answer. Nothing is asked for unless
/// they tap a row that is not allowed.
void main() {
  test('every permission is listed, the granted ones included', () async {
    final phone = PermissionPhone.android(maker: samsung)
      ..grantNotifications()
      ..device.grant(DevicePermissionType.fullScreenIntent);
    final cubit = phone.cubit(cameBack: true);

    await cubit.refresh();
    await pumpEventQueue();

    expect(cubit.state.available, [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      PermissionSetupStep.androidBattery,
    ]);
    expect(cubit.state.granted, {
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
    });
    // The list is the screen: no step is walked and nothing moves on.
    expect(cubit.state.current, isNull);
    expect(cubit.state.canNavigate, isFalse);

    // Nothing was asked for by itself.
    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 0);
    expect(phone.device.opened, isEmpty);
    expect(phone.device.appSettingsOpened, 0);
    await cubit.close();
  });

  test('with everything granted the list still shows and waits', () async {
    final phone = PermissionPhone.ios26(alarmStatus: 'authorized')
      ..grantNotifications();
    final cubit = phone.cubit(cameBack: true);

    await cubit.refresh();
    await pumpEventQueue();

    expect(cubit.state.available, isNotEmpty);
    expect(cubit.state.granted, cubit.state.available.toSet());
    expect(cubit.state.canNavigate, isFalse);

    // Continue is the one way on.
    cubit.continueWithout();
    expect(cubit.state.canNavigate, isTrue);
    await cubit.close();
  });

  test('tapping an allowed row asks for nothing', () async {
    final phone = PermissionPhone.android()..grantNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    await cubit.allowListed(PermissionSetupStep.androidNotifications);

    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 0);
    await cubit.close();
  });

  test('a refused prompt is not shown again', () async {
    final phone = PermissionPhone.android()..refuseNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    expect(
      cubit.state.promptSpent,
      contains(PermissionSetupStep.androidNotifications),
    );

    await cubit.allowListed(PermissionSetupStep.androidNotifications);

    // The switch is in Settings, so that is what opens. No prompt.
    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 1);
    await cubit.close();
  });

  test('a permission the user was never asked can still be asked', () async {
    // They tapped Not now the first time, so the system has not prompted.
    final phone = PermissionPhone.ios26();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();
    expect(cubit.state.promptSpent, isEmpty);

    await cubit.allowListed(PermissionSetupStep.iosNotifications);

    expect(phone.notifications.requests, 1);
    expect(
      cubit.state.granted,
      contains(PermissionSetupStep.iosNotifications),
    );
    // The list stays up with the new answer.
    expect(cubit.state.isRequesting, isFalse);
    expect(cubit.state.canNavigate, isFalse);
    await cubit.close();
  });

  test('a prompt refused from the list leaves Settings as the way', () async {
    final phone = PermissionPhone.ios26()
      ..notifications.requestAnswer = NotificationPermissionStatus.denied;
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    await cubit.allowListed(PermissionSetupStep.iosNotifications);
    await cubit.allowListed(PermissionSetupStep.iosNotifications);

    expect(phone.notifications.requests, 1);
    expect(phone.notifications.settingsOpened, 1);
    await cubit.close();
  });

  test('AlarmKit refused shows as refused and opens Settings', () async {
    final phone = PermissionPhone.ios26(alarmStatus: 'denied')
      ..grantNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    expect(cubit.state.promptSpent, contains(PermissionSetupStep.iosAlarms));
    expect(cubit.state.granted, isNot(contains(PermissionSetupStep.iosAlarms)));

    await cubit.allowListed(PermissionSetupStep.iosAlarms);

    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 1);
    await cubit.close();
  });

  test('the battery dialog is never raised from the list', () async {
    // The user said no to the dialog, or passed it over, the first time.
    final phone = PermissionPhone.android(maker: samsung)..grantNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    await cubit.allowListed(PermissionSetupStep.androidBattery);

    // The app's own page in Settings opens, not the system dialog.
    expect(phone.device.opened, isEmpty);
    expect(phone.device.appSettingsOpened, 1);

    // Coming back from Settings re-reads and still moves nowhere.
    await cubit.refresh();
    await pumpEventQueue();
    expect(cubit.state.canNavigate, isFalse);
    expect(phone.device.opened, isEmpty);
    await cubit.close();
  });

  test('the full-screen row opens its settings page', () async {
    final phone = PermissionPhone.android()..grantNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    await cubit.allowListed(PermissionSetupStep.androidFullScreen);

    expect(phone.device.opened, [DevicePermissionType.fullScreenIntent]);
    await cubit.close();
  });

  test('which rows open Settings and which can still ask', () {
    bool opensSettings(PermissionSetupStep step, {bool spent = false}) =>
        permissionAnswerOpensSettings(step, promptSpent: spent);

    expect(opensSettings(PermissionSetupStep.iosNotifications), isFalse);
    expect(
      opensSettings(PermissionSetupStep.iosNotifications, spent: true),
      isTrue,
    );
    expect(opensSettings(PermissionSetupStep.iosAlarms), isFalse);
    expect(opensSettings(PermissionSetupStep.iosAlarms, spent: true), isTrue);
    expect(opensSettings(PermissionSetupStep.androidNotifications), isFalse);
    expect(opensSettings(PermissionSetupStep.androidFullScreen), isTrue);
    expect(opensSettings(PermissionSetupStep.androidBattery), isTrue);
  });
}
