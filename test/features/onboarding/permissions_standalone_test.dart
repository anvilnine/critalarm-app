import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

/// Health opens the prompt screen on its own for a permission the user was
/// never asked. It asks only what can still be asked, then closes.
void main() {
  test('lands on the alarm step when only alarms were never asked', () async {
    final phone = PermissionPhone.ios26()..grantNotifications();
    final cubit = phone.cubit(standalone: true);

    await cubit.refresh();

    expect(cubit.state.current, PermissionSetupStep.iosAlarms);
    expect(cubit.state.steps, const [PermissionSetupStep.iosAlarms]);
    expect(cubit.state.canNavigate, isFalse);
    await cubit.close();
  });

  test(
    'closes after notifications when alarms cannot be asked again',
    () async {
      final phone = PermissionPhone.ios26(alarmStatus: 'denied');
      final cubit = phone.cubit(standalone: true);

      await cubit.refresh();
      expect(cubit.state.steps, const [PermissionSetupStep.iosNotifications]);
      await cubit.allowCurrentStep();

      expect(phone.notifications.requests, 1);
      expect(cubit.state.canNavigate, isTrue);
      expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
      await cubit.close();
    },
  );

  test('"Not now" closes when there is no alarm prompt left', () async {
    final phone = PermissionPhone.iosOld();
    final cubit = phone.cubit(standalone: true);

    await cubit.refresh();
    cubit.skipStep();

    expect(cubit.state.canNavigate, isTrue);
    await cubit.close();
  });

  test('closes at once, unseen, when nothing can be asked', () async {
    final phone = PermissionPhone.ios26(alarmStatus: 'denied')
      ..grantNotifications();
    final cubit = phone.cubit(standalone: true);
    final states = record(cubit);

    await cubit.refresh();
    await pumpEventQueue();

    expect(states.every((state) => state.current == null), isTrue);
    expect(cubit.state.canNavigate, isTrue);
    await cubit.close();
  });

  test('onboarding still shows the alarm step after a refusal', () async {
    final phone = PermissionPhone.ios26(alarmStatus: 'denied');
    final cubit = phone.cubit();

    await cubit.refresh();
    cubit.skipStep();

    expect(cubit.state.current, PermissionSetupStep.iosAlarms);
    expect(cubit.state.canNavigate, isFalse);
    await cubit.close();
  });

  test('onboarding shows the explainer, standalone does not', () async {
    final setup = PermissionPhone.iosOld().cubit();
    final alone = PermissionPhone.iosOld().cubit(standalone: true);

    await setup.refresh();
    await alone.refresh();

    expect(
      setup.state.steps,
      contains(PermissionSetupStep.iosTimeSensitiveExplainer),
    );
    expect(
      alone.state.steps,
      isNot(contains(PermissionSetupStep.iosTimeSensitiveExplainer)),
    );
    await setup.close();
    await alone.close();
  });
}
