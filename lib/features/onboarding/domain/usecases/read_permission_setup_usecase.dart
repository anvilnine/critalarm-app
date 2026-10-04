import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:flutter/foundation.dart';

/// The setup permission steps of this phone and which are granted right now.
@immutable
class PermissionSetupSnapshot {
  const PermissionSetupSnapshot({
    required this.steps,
    required this.granted,
    this.alarm = AlarmAuthorization.unsupported,
    this.promptSpent = const {},
  });

  /// Every step this phone has, from [permissionSetupStepsFor].
  final List<PermissionSetupStep> steps;

  /// The steps in [steps] whose permission is granted.
  final Set<PermissionSetupStep> granted;

  /// What AlarmKit said. `unsupported` off iOS and below iOS 26.
  final AlarmAuthorization alarm;

  /// The steps whose system prompt will not come up again, so the only way
  /// left to grant them is a switch in Settings.
  final Set<PermissionSetupStep> promptSpent;

  /// Nothing left for setup to ask.
  bool get everyGranted => everySetupPermissionGranted(steps, granted);
}

/// Reads the step list and every step's status, without prompting.
///
/// Nothing is remembered between calls. A store may grant a permission at
/// install and the user may change one in Settings at any time, so the
/// screen calls this when it opens and every time the app comes back.
/// Every read is local, so launch can wait on it.
class ReadPermissionSetupUsecase {
  const ReadPermissionSetupUsecase({
    required this.platform,
    required this.isWeb,
    required this.checkNotifications,
    required this.alarm,
    required this.devicePermissions,
    required this.makerReader,
    this.sdkReader,
  });

  final TargetPlatform platform;
  final bool isWeb;
  final CheckNotificationPermissionUsecase checkNotifications;
  final AlarmHost alarm;
  final DevicePermissionsRepository devicePermissions;
  final DeviceMakerReader makerReader;

  /// Null in tests that do not care which Android this is.
  final AndroidSdkReader? sdkReader;

  Future<PermissionSetupSnapshot> call() async {
    final isIos = !isWeb && platform == TargetPlatform.iOS;
    final isAndroid = !isWeb && platform == TargetPlatform.android;

    // The alarm channel answers `unsupported` off iOS, so only iOS is asked.
    final authorization = isIos
        ? await alarm.authorizationStatus()
        : AlarmAuthorization.unsupported;
    final maker = isAndroid ? await makerReader.read() : DeviceMaker.unknown;

    final steps = permissionSetupStepsFor(
      platform,
      isWeb: isWeb,
      hasAlarmKit: authorization != AlarmAuthorization.unsupported,
      maker: maker,
    );

    final notifications = steps.isEmpty
        ? null
        : (await checkNotifications(const NoParams())).getOrNull();
    final notificationsGranted =
        notifications == NotificationPermissionStatus.granted;
    final sdk = isAndroid ? await sdkReader?.sdkInt() : null;

    final granted = <PermissionSetupStep>{};
    final promptSpent = <PermissionSetupStep>{};
    for (final step in steps) {
      switch (step) {
        case PermissionSetupStep.iosNotifications:
        case PermissionSetupStep.androidNotifications:
          if (notificationsGranted) granted.add(step);
          if (notificationPromptSpent(
            platform: platform,
            granted: notificationsGranted,
            // The repository answers `denied` only once the app has asked.
            refusedBefore: notifications == NotificationPermissionStatus.denied,
            androidSdk: sdk,
          )) {
            promptSpent.add(step);
          }
        case PermissionSetupStep.iosAlarms:
          if (authorization == AlarmAuthorization.authorized) {
            granted.add(step);
          }
          // AlarmKit prompts once.
          if (authorization == AlarmAuthorization.denied) {
            promptSpent.add(step);
          }
        case PermissionSetupStep.iosTimeSensitiveExplainer:
          break;
        case PermissionSetupStep.androidFullScreen:
          if (await _deviceGranted(DevicePermissionType.fullScreenIntent)) {
            granted.add(step);
          }
        case PermissionSetupStep.androidBattery:
          if (await _deviceGranted(DevicePermissionType.batteryOptimization)) {
            granted.add(step);
          }
      }
    }
    return PermissionSetupSnapshot(
      steps: steps,
      granted: granted,
      alarm: authorization,
      promptSpent: promptSpent,
    );
  }

  /// A read that fails counts as not granted: the step shows, and the user
  /// can still skip it.
  Future<bool> _deviceGranted(DevicePermissionType type) async =>
      (await devicePermissions.checkPermission(type)).getOrNull() ==
      DevicePermissionStatus.granted;
}
