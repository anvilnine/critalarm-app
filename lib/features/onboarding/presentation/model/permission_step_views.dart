import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/features/onboarding/presentation/model/android_permission_step_views.dart';
import 'package:critalarm/features/onboarding/presentation/model/ios_permission_step_views.dart';
import 'package:critalarm/features/onboarding/presentation/model/permission_step_view.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';

/// What the screen draws for [step].
///
/// Every step names its own view, so adding a step fails to compile here
/// until it has one. iOS steps are built in the iOS file from iOS strings,
/// Android steps in the Android file from Android strings.
///
/// [promptSpent] says the system will not show this step's prompt again, so
/// the view sends the user to Settings. [notificationsGranted] is whether a
/// page can reach the phone at all: without it no step promises a ring.
PermissionStepView permissionStepViewFor(
  PermissionSetupStep step, {
  required RingClaim claim,
  required bool promptSpent,
  required bool notificationsGranted,
}) => switch (step) {
  PermissionSetupStep.iosNotifications =>
    promptSpent
        ? iosNotificationsSettingsStepView()
        : iosNotificationsStepView(),
  PermissionSetupStep.iosAlarms => iosAlarmsStepView(claim),
  PermissionSetupStep.iosTimeSensitiveExplainer => iosTimeSensitiveStepView(),
  PermissionSetupStep.androidNotifications =>
    promptSpent
        ? androidNotificationsSettingsStepView()
        : androidNotificationsStepView(),
  PermissionSetupStep.androidFullScreen => androidFullScreenStepView(
    claim,
    notificationsGranted: notificationsGranted,
  ),
  PermissionSetupStep.androidBattery => androidBatteryStepView(),
};
