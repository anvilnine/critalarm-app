import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

/// A user who goes Back to the permissions from a later step sees every
/// step again, and is never asked twice for one they already answered.
void main() {
  test('an allowed step shows again and its button only moves on', () async {
    final phone = PermissionPhone.android()
      ..grantNotifications()
      ..device.grant(DevicePermissionType.fullScreenIntent);
    final cubit = phone.cubit(cameBack: true);

    await cubit.refresh();
    await pumpEventQueue();

    // Going forward this screen would have finished unseen.
    expect(cubit.state.current, PermissionSetupStep.androidNotifications);
    expect(cubit.state.canNavigate, isFalse);
    expect(
      cubit.state.granted,
      contains(PermissionSetupStep.androidNotifications),
    );

    await cubit.allowCurrentStep();
    expect(cubit.state.current, PermissionSetupStep.androidFullScreen);

    await cubit.allowCurrentStep();
    expect(cubit.state.canNavigate, isTrue);

    // Nothing was asked for on the way.
    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 0);
    expect(phone.device.opened, isEmpty);
    await cubit.close();
  });

  test('a refused prompt is not shown again', () async {
    final phone = PermissionPhone.android()..refuseNotifications();
    final cubit = phone.cubit(cameBack: true);
    await cubit.refresh();
    await pumpEventQueue();

    expect(cubit.state.current, PermissionSetupStep.androidNotifications);
    expect(
      cubit.state.promptSpent,
      contains(PermissionSetupStep.androidNotifications),
    );

    await cubit.allowCurrentStep();

    // The switch is in Settings, so that is what opens. No prompt.
    expect(phone.notifications.requests, 0);
    expect(phone.notifications.settingsOpened, 1);
    await cubit.close();
  });

  test('a step the user was never asked can still be asked', () async {
    // They tapped Not now the first time, so the system has not prompted.
    final phone = PermissionPhone.ios26();
    final cubit = phone.cubit(cameBack: true);

    await cubit.refresh();
    await pumpEventQueue();
    expect(cubit.state.current, PermissionSetupStep.iosNotifications);
    expect(cubit.state.promptSpent, isEmpty);

    await cubit.allowCurrentStep();

    expect(phone.notifications.requests, 1);
    await cubit.close();
  });

  test('AlarmKit refused shows as refused and asks for nothing', () async {
    final phone = PermissionPhone.ios26(alarmStatus: 'denied')
      ..grantNotifications();
    final cubit = phone.cubit(cameBack: true);

    await cubit.refresh();
    await pumpEventQueue();
    await cubit.allowCurrentStep();

    expect(cubit.state.current, PermissionSetupStep.iosAlarms);
    expect(cubit.state.promptSpent, contains(PermissionSetupStep.iosAlarms));
    expect(phone.notifications.requests, 0);
    await cubit.close();
  });
}
