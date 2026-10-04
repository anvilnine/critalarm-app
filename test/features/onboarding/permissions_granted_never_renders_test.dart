import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/permission_setup_fakes.dart';

/// A step the phone has already granted is never put on screen: no state
/// names it as the current step, not even for one frame.
void main() {
  /// The step each state had on screen, in order, without repeats.
  List<PermissionSetupStep?> onScreen(
    List<NotificationPermissionsState> states,
  ) {
    final seen = <PermissionSetupStep?>[];
    for (final state in states) {
      if (seen.isEmpty || seen.last != state.current) seen.add(state.current);
    }
    return seen;
  }

  group('before the statuses are read', () {
    test('a new cubit has no step, so the screen draws no prompt', () async {
      final cubit = PermissionPhone.android().cubit();

      expect(cubit.state.current, isNull);
      expect(cubit.state.steps, isEmpty);
      await cubit.close();
    });

    test('the first state of a read still has no step', () async {
      final cubit = PermissionPhone.android().cubit();
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(states.first.isChecking, isTrue);
      expect(states.first.current, isNull);
      await cubit.close();
    });
  });

  group('every step granted', () {
    Future<void> finishesUnseen(PermissionPhone phone) async {
      final cubit = phone.cubit();
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(
        states.every((state) => state.current == null),
        isTrue,
        reason: 'no state may put a step on screen: ${onScreen(states)}',
      );
      expect(cubit.state.steps, isEmpty);
      expect(cubit.state.canNavigate, isTrue);
      expect(cubit.state.isGranted, isTrue);
      expect(phone.notifications.requests, 0);
      expect(phone.device.opened, isEmpty);
      expect(phone.alarm.callsTo('requestAuthorization'), isEmpty);
      await cubit.close();
    }

    test('iOS 26: finishes without a prompt state', () async {
      await finishesUnseen(
        PermissionPhone.ios26(alarmStatus: 'authorized')..grantNotifications(),
      );
    });

    test(
      'iOS 16 to 25: finishes, and the explainer does not show alone',
      () async {
        await finishesUnseen(PermissionPhone.iosOld()..grantNotifications());
      },
    );

    test('Android: finishes without a prompt state', () async {
      await finishesUnseen(
        PermissionPhone.android()
          ..grantNotifications()
          ..device.grant(DevicePermissionType.fullScreenIntent),
      );
    });

    test(
      'Android on a listed maker: finishes without a prompt state',
      () async {
        await finishesUnseen(
          PermissionPhone.android(maker: samsung)
            ..grantNotifications()
            ..device.grant(DevicePermissionType.fullScreenIntent)
            ..device.grant(DevicePermissionType.batteryOptimization),
        );
      },
    );
  });

  group('one step granted', () {
    test('Android: full-screen granted at install is never shown', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();
      final states = record(cubit);

      await cubit.refresh();
      cubit.skipStep();
      await pumpEventQueue();
      cubit.skipStep();
      await pumpEventQueue();

      expect(onScreen(states), const [
        null,
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidBattery,
      ]);
      expect(
        states.any(
          (state) =>
              state.current == PermissionSetupStep.androidFullScreen ||
              state.steps.contains(PermissionSetupStep.androidFullScreen),
        ),
        isFalse,
      );
      // Two steps are drawn, so two are counted.
      expect(cubit.state.steps, hasLength(2));
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('Android: the first step granted opens on the second', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      final cubit = phone.cubit();
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(onScreen(states), const [
        null,
        PermissionSetupStep.androidFullScreen,
      ]);
      expect(cubit.state.steps, const [PermissionSetupStep.androidFullScreen]);
      expect(cubit.state.currentIndex, 0);
      await cubit.close();
    });

    test('Android: only battery left opens on battery, alone', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(onScreen(states), const [
        null,
        PermissionSetupStep.androidBattery,
      ]);
      expect(cubit.state.steps, const [PermissionSetupStep.androidBattery]);
      await cubit.close();
    });

    test('iOS 26: notifications granted opens on alarms', () async {
      final phone = PermissionPhone.ios26()..grantNotifications();
      final cubit = phone.cubit();
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(onScreen(states), const [null, PermissionSetupStep.iosAlarms]);
      await cubit.close();
    });
  });

  group('granted while the screen is open', () {
    test(
      'a later step granted in Settings is passed over, its dot kept',
      () async {
        final phone = PermissionPhone.android(maker: samsung);
        final cubit = phone.cubit();
        final states = record(cubit);

        await cubit.refresh();
        expect(cubit.state.steps, hasLength(3));

        // The user leaves, turns the full-screen switch on, and comes back.
        phone.device.grant(DevicePermissionType.fullScreenIntent);
        await cubit.refresh();
        // Nothing on screen moved: same step, same three dots.
        expect(cubit.state.current, PermissionSetupStep.androidNotifications);
        expect(cubit.state.steps, hasLength(3));

        cubit.skipStep();
        await pumpEventQueue();

        expect(onScreen(states), const [
          null,
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidBattery,
        ]);
        expect(cubit.state.steps, hasLength(3));
        expect(cubit.state.currentIndex, 2);
        await cubit.close();
      },
    );

    test('an earlier step revoked in Settings is not gone back to', () async {
      // Notifications were granted when the screen opened, so the run
      // starts on the full-screen step with two dots.
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications();
      final cubit = phone.cubit();
      await cubit.refresh();
      const drawn = [
        PermissionSetupStep.androidFullScreen,
        PermissionSetupStep.androidBattery,
      ];
      expect(cubit.state.steps, drawn);

      // The user turns notifications off in Settings and comes back.
      phone.refuseNotifications();
      await cubit.refresh();

      // No dot is put in before the one they are on.
      expect(cubit.state.steps, drawn);
      expect(cubit.state.current, PermissionSetupStep.androidFullScreen);
      expect(cubit.state.currentIndex, 0);

      cubit
        ..skipStep()
        ..skipStep();
      expect(cubit.state.steps, drawn);
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test(
      'a step answered earlier and revoked since is not gone back to',
      () async {
        final phone = PermissionPhone.android(maker: samsung);
        final cubit = phone.cubit();
        await cubit.refresh();
        await cubit.allowCurrentStep();
        expect(cubit.state.current, PermissionSetupStep.androidFullScreen);

        phone.refuseNotifications();
        await cubit.refresh();

        expect(cubit.state.current, PermissionSetupStep.androidFullScreen);
        expect(cubit.state.steps, hasLength(3));
        expect(cubit.state.currentIndex, 1);
        await cubit.close();
      },
    );

    test('the step on screen granted in Settings moves on', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications();
      final cubit = phone.cubit();

      await cubit.refresh();
      expect(cubit.state.current, PermissionSetupStep.androidFullScreen);

      await cubit.allowCurrentStep();
      expect(phone.device.opened, [DevicePermissionType.fullScreenIntent]);
      // Still waiting: opening Settings is not an answer.
      expect(cubit.state.current, PermissionSetupStep.androidFullScreen);

      phone.device.grant(DevicePermissionType.fullScreenIntent);
      await cubit.refresh();

      expect(cubit.state.current, PermissionSetupStep.androidBattery);
      // The step that was on screen stays counted, so the dots do not jump.
      expect(cubit.state.steps, const [
        PermissionSetupStep.androidFullScreen,
        PermissionSetupStep.androidBattery,
      ]);
      expect(cubit.state.currentIndex, 1);
      await cubit.close();
    });

    test('the last step granted in Settings finishes', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit();

      await cubit.refresh();
      await cubit.allowCurrentStep();
      expect(phone.device.opened, [DevicePermissionType.batteryOptimization]);
      expect(cubit.state.canNavigate, isFalse);

      phone.device.grant(DevicePermissionType.batteryOptimization);
      await cubit.refresh();

      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('coming back with nothing changed stays on the step', () async {
      final phone = PermissionPhone.android(maker: samsung);
      final cubit = phone.cubit();

      await cubit.refresh();
      cubit.skipStep();
      await cubit.refresh();

      expect(cubit.state.current, PermissionSetupStep.androidFullScreen);
      expect(cubit.state.currentIndex, 1);
      expect(cubit.state.steps, hasLength(3));
      await cubit.close();
    });

    test('every read asks the phone again', () async {
      final phone = PermissionPhone.android();
      final cubit = phone.cubit();

      await cubit.refresh();
      await cubit.refresh();
      await cubit.refresh();

      expect(phone.notifications.checks, 3);
      expect(
        phone.device.checked
            .where((type) => type == DevicePermissionType.fullScreenIntent)
            .length,
        3,
      );
      await cubit.close();
    });
  });

  group('the developer replay', () {
    Future<void> showsAll(
      PermissionPhone phone,
      List<PermissionSetupStep> expected,
    ) async {
      final cubit = phone.cubit(replayForDemo: true);
      final states = record(cubit);

      await cubit.refresh();
      expect(cubit.state.steps, expected);
      expect(cubit.state.canNavigate, isFalse);
      for (var i = 1; i < expected.length; i++) {
        cubit.skipStep();
      }
      await pumpEventQueue();
      expect(cubit.state.canNavigate, isFalse);
      cubit.skipStep();
      await pumpEventQueue();

      expect(onScreen(states), [null, ...expected]);
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    }

    test('iOS 26: both steps, all granted', () async {
      await showsAll(
        PermissionPhone.ios26(alarmStatus: 'authorized')..grantNotifications(),
        const [
          PermissionSetupStep.iosNotifications,
          PermissionSetupStep.iosAlarms,
        ],
      );
    });

    test('iOS 16 to 25: notifications and the explainer', () async {
      await showsAll(PermissionPhone.iosOld()..grantNotifications(), const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      ]);
    });

    test('Android on a listed maker: all three, all granted', () async {
      await showsAll(
        PermissionPhone.android(maker: samsung)
          ..grantNotifications()
          ..device.grant(DevicePermissionType.fullScreenIntent)
          ..device.grant(DevicePermissionType.batteryOptimization),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
          PermissionSetupStep.androidBattery,
        ],
      );
    });

    test('Android on a Pixel: two, and never battery', () async {
      await showsAll(
        PermissionPhone.android()
          ..grantNotifications()
          ..device.grant(DevicePermissionType.fullScreenIntent),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
        ],
      );
    });

    test('coming back to the app does not move a replay on', () async {
      final phone = PermissionPhone.android()
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit(replayForDemo: true);

      await cubit.refresh();
      await cubit.refresh();

      expect(cubit.state.current, PermissionSetupStep.androidNotifications);
      await cubit.close();
    });
  });

  group('opened on its own', () {
    test(
      'iOS 16 to 25: the explainer is not a prompt, so it never shows',
      () async {
        final phone = PermissionPhone.iosOld();
        final cubit = phone.cubit(standalone: true);
        final states = record(cubit);

        await cubit.refresh();
        expect(cubit.state.steps, const [PermissionSetupStep.iosNotifications]);
        await cubit.allowCurrentStep();
        await pumpEventQueue();

        expect(onScreen(states), const [
          null,
          PermissionSetupStep.iosNotifications,
        ]);
        expect(cubit.state.canNavigate, isTrue);
        await cubit.close();
      },
    );

    test('Android on a listed maker: battery is left to Health', () async {
      final phone = PermissionPhone.android(maker: samsung);
      final cubit = phone.cubit(standalone: true);

      await cubit.refresh();

      expect(cubit.state.steps, const [
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      ]);
      await cubit.close();
    });

    test('Android: only battery missing closes at once, unseen', () async {
      final phone = PermissionPhone.android(maker: samsung)
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      final cubit = phone.cubit(standalone: true);
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(states.every((state) => state.current == null), isTrue);
      expect(cubit.state.canNavigate, isTrue);
      await cubit.close();
    });

    test('a granted step is not shown there either', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      final cubit = phone.cubit(standalone: true);
      final states = record(cubit);

      await cubit.refresh();
      await pumpEventQueue();

      expect(onScreen(states), const [
        null,
        PermissionSetupStep.androidFullScreen,
      ]);
      await cubit.close();
    });
  });
}
