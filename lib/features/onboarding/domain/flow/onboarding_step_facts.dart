import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:flutter/foundation.dart';

/// The phone a flow runs on, passed in as values so nothing in the registry
/// asks the platform itself.
@immutable
class OnboardingPlatform {
  const OnboardingPlatform({required this.platform, required this.isWeb});

  final TargetPlatform platform;
  final bool isWeb;
}

/// What is already true for this user. Every answer is a local read, so
/// launch never waits on the network.
abstract interface class OnboardingStepFacts {
  /// A server connection is saved.
  Future<bool> hasConnection();

  /// Every permission setup asks for on this platform is granted.
  Future<bool> hasEveryPermission();

  /// The user has owned a topic.
  Future<bool> hasOwnedTopic();
}

/// Whether the permissions step has nothing left to ask.
///
/// iOS reads notifications and, on iOS 26 or later, AlarmKit. An older
/// iPhone reports [AlarmAuthorization.unsupported] and is judged on
/// notifications alone. Android reads notifications and the full-screen
/// intent permission.
bool onboardingPermissionsSatisfied({
  required OnboardingPlatform on,
  required bool notificationsGranted,
  required AlarmAuthorization alarm,
  required bool fullScreenGranted,
}) {
  if (!notificationsGranted) return false;
  if (on.isWeb) return true;
  return switch (on.platform) {
    TargetPlatform.android => fullScreenGranted,
    TargetPlatform.iOS =>
      alarm == AlarmAuthorization.authorized ||
          alarm == AlarmAuthorization.unsupported,
    _ => true,
  };
}

/// Reads the facts from what the phone already holds.
class DeviceOnboardingStepFacts implements OnboardingStepFacts {
  const DeviceOnboardingStepFacts({
    required this.on,
    required this.getConnection,
    required this.checkNotifications,
    required this.alarm,
    required this.devicePermissions,
    required this.notices,
  });

  final OnboardingPlatform on;
  final GetConnectionUsecase getConnection;
  final CheckNotificationPermissionUsecase checkNotifications;
  final AlarmHost alarm;
  final DevicePermissionsRepository devicePermissions;
  final InAppNoticeRepository notices;

  @override
  Future<bool> hasConnection() async =>
      (await getConnection(const NoParams())).getOrNull() != null;

  @override
  Future<bool> hasEveryPermission() async {
    final notifications = (await checkNotifications(
      const NoParams(),
    )).getOrNull();
    final isIos = !on.isWeb && on.platform == TargetPlatform.iOS;
    final isAndroid = !on.isWeb && on.platform == TargetPlatform.android;
    return onboardingPermissionsSatisfied(
      on: on,
      notificationsGranted:
          notifications == NotificationPermissionStatus.granted,
      alarm: isIos
          ? await alarm.authorizationStatus()
          : AlarmAuthorization.unsupported,
      fullScreenGranted:
          isAndroid &&
          (await devicePermissions.checkPermission(
                DevicePermissionType.fullScreenIntent,
              )).getOrNull() ==
              DevicePermissionStatus.granted,
    );
  }

  @override
  Future<bool> hasOwnedTopic() async => notices.getFirstTopicOwnedAt() != null;
}
