import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

void main() {
  group('a refused permission is never a wall', () {
    test('a denied alarm still lets the user through', () async {
      final phone = PermissionPhone.ios26()..grantNotifications();
      phone.alarm.answers['requestAuthorization'] = 'denied';
      final cubit = phone.cubit();
      await cubit.refresh();

      await cubit.allowCurrentStep();

      // AlarmKit never prompts twice, so blocking here would strand the
      // user for good, and Apple flags exactly that.
      expect(cubit.state.canNavigate, isTrue);
      expect(cubit.state.alarm, AlarmAuthorization.denied);
      expect(
        cubit.state.granted,
        isNot(contains(PermissionSetupStep.iosAlarms)),
      );
      await cubit.close();
    });

    test('continueWithout leaves the denied screen', () async {
      final cubit = PermissionPhone.ios26().cubit(
        initialStep: NotificationPermissionStep.denied,
      );
      expect(cubit.state.isDenied, isTrue);

      cubit.continueWithout();

      expect(cubit.state.isDenied, isFalse);
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('the denied screen stays through a read, with its way out', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit(initialStep: NotificationPermissionStep.denied);

      await cubit.refresh();

      expect(cubit.state.isDenied, isTrue);
      expect(cubit.state.isChecking, isFalse);
      expect(cubit.state.canNavigate, isFalse);
      cubit.continueWithout();
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('the denied screen closes itself once Settings fixed it', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit(initialStep: NotificationPermissionStep.denied);
      await cubit.refresh();

      phone
        ..grantNotifications()
        ..alarm.answers['authorizationStatus'] = 'authorized';
      await cubit.refresh();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('"Not now" works before the statuses are read', () async {
      final cubit = PermissionPhone.android().cubit()..continueWithout();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    for (final (name, build) in [
      ('iOS 26', PermissionPhone.ios26),
      ('iOS 16 to 25', PermissionPhone.iosOld),
      ('Android', PermissionPhone.android),
      (
        'Android on a listed maker',
        () => PermissionPhone.android(maker: samsung),
      ),
    ]) {
      test('$name: "Not now" all the way through finishes', () async {
        final phone = build();
        final cubit = phone.cubit();
        await cubit.refresh();
        final count = cubit.state.steps.length;

        for (var i = 0; i < count; i++) {
          expect(cubit.state.canNavigate, isFalse, reason: 'step $i');
          cubit.skipStep();
        }

        expect(cubit.state.canNavigate, isTrue);
        expect(phone.notifications.requests, 0);
        expect(phone.device.opened, isEmpty);
        expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
        await cubit.close();
      });

      test('$name: the main button all the way through finishes', () async {
        final phone = build()
          ..notifications.requestAnswer = NotificationPermissionStatus.denied;
        phone.alarm.answers['requestAuthorization'] = 'denied';
        final cubit = phone.cubit();
        await cubit.refresh();
        final count = cubit.state.steps.length;

        for (var i = 0; i < count; i++) {
          final step = cubit.state.current;
          await cubit.allowCurrentStep();
          // A settings page is not an answer. The user comes back having
          // turned nothing on, and "Not now" is still there.
          if (cubit.state.current == step && !cubit.state.canNavigate) {
            await cubit.refresh();
            expect(cubit.state.current, step);
            cubit.skipStep();
          }
        }

        expect(cubit.state.canNavigate, isTrue);
        await cubit.close();
      });
    }
  });

  group('no denied screen', () {
    test('refused notifications land on step two', () async {
      final phone = PermissionPhone.ios26()
        ..notifications.requestAnswer = NotificationPermissionStatus.denied;
      final cubit = phone.cubit();
      await cubit.refresh();

      await cubit.allowCurrentStep();

      expect(cubit.state.isDenied, isFalse);
      expect(cubit.state.currentIndex, 1);
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    test('not now on step one goes to step two without asking', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit();
      await cubit.refresh();

      cubit.skipStep();

      expect(cubit.state.current, PermissionSetupStep.iosAlarms);
      expect(phone.notifications.requests, 0);
      await cubit.close();
    });

    test('not now on step two finishes', () async {
      final phone = PermissionPhone.ios26();
      final cubit = phone.cubit();
      await cubit.refresh();

      cubit
        ..skipStep()
        ..skipStep();

      expect(cubit.state.canNavigate, isTrue);
      expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
      await cubit.close();
    });

    test('coming back to the app does not send the user back a step', () async {
      final phone = PermissionPhone.ios26()
        ..notifications.status = NotificationPermissionStatus.denied;
      final cubit = phone.cubit();
      await cubit.refresh();
      cubit.skipStep();

      await cubit.refresh();

      expect(cubit.state.current, PermissionSetupStep.iosAlarms);
      expect(cubit.state.currentIndex, 1);
      await cubit.close();
    });

    test('coming back mid request leaves the request alone', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      final cubit = phone.cubit();
      await cubit.refresh();
      cubit.emit(
        cubit.state.copyWith(step: NotificationPermissionStep.requesting),
      );
      final states = record(cubit);
      final checks = phone.notifications.checks;

      await cubit.refresh();
      await pumpEventQueue();

      expect(states, isEmpty);
      expect(phone.notifications.checks, checks);
      await cubit.close();
    });
  });

  group('unsupported is not a grant', () {
    test('an iPhone with no alarm permission still has two steps', () async {
      final phone = PermissionPhone.iosOld();
      final cubit = phone.cubit();

      await cubit.refresh();

      expect(cubit.state.alarm, AlarmAuthorization.unsupported);
      expect(cubit.state.steps, const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      ]);
      expect(
        cubit.state.granted,
        isNot(contains(PermissionSetupStep.iosTimeSensitiveExplainer)),
      );
      await cubit.close();
    });
  });

  group('a granted step is not shown again', () {
    test('everything already granted goes straight through', () async {
      final phone = PermissionPhone.ios26(alarmStatus: 'authorized')
        ..grantNotifications();
      final cubit = phone.cubit();

      await cubit.refresh();

      expect(cubit.state.canNavigate, isTrue);
      expect(phone.notifications.requests, 0);
      await cubit.close();
    });

    test(
      'notifications granted but not alarms lands on the alarm step',
      () async {
        final phone = PermissionPhone.ios26()..grantNotifications();
        final cubit = phone.cubit();

        await cubit.refresh();

        expect(cubit.state.current, PermissionSetupStep.iosAlarms);
        expect(cubit.state.canNavigate, isFalse);
        await cubit.close();
      },
    );

    test('the developer replay shows every step anyway', () async {
      final phone = PermissionPhone.ios26(alarmStatus: 'authorized')
        ..grantNotifications();
      final cubit = phone.cubit(replayForDemo: true);

      await cubit.refresh();

      expect(cubit.state.current, PermissionSetupStep.iosNotifications);
      expect(cubit.state.steps, hasLength(2));
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    test('Android: a granted full-screen alarm is not shown again', () async {
      final phone = PermissionPhone.android()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();

      await cubit.refresh();
      cubit.skipStep();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });
  });
}
