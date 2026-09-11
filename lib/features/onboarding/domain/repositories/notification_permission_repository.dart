import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';

/// Contract for checking and requesting notification and full-screen intent
/// permissions.
abstract interface class NotificationPermissionRepository {
  /// Checks current notification permission status.
  Future<AppResult<NotificationPermissionStatus>> checkPermission();

  /// Requests notification and full-screen intent permissions.
  Future<AppResult<NotificationPermissionStatus>> requestPermission();

  /// Opens the device system settings for app notifications.
  Future<AppResult<bool>> openSettings();
}
