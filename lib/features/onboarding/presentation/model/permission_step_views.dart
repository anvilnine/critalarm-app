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
PermissionStepView permissionStepViewFor(
  PermissionSetupStep step, {
  required RingClaim claim,
}) => switch (step) {
  PermissionSetupStep.iosNotifications => iosNotificationsStepView(),
  PermissionSetupStep.iosAlarms => iosAlarmsStepView(claim),
  PermissionSetupStep.iosTimeSensitiveExplainer => iosTimeSensitiveStepView(),
  PermissionSetupStep.androidNotifications => androidNotificationsStepView(),
  PermissionSetupStep.androidFullScreen => androidFullScreenStepView(),
  PermissionSetupStep.androidBattery => androidBatteryStepView(),
};
