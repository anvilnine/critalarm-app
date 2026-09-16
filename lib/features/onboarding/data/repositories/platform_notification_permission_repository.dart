import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Platform implementation of [NotificationPermissionRepository] using
/// [FlutterLocalNotificationsPlugin] and a custom platform method channel for
/// system settings deep linking.
class PlatformNotificationPermissionRepository
    implements NotificationPermissionRepository {
  PlatformNotificationPermissionRepository({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel ?? const MethodChannel('app.critalarm/settings');

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;

  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async {
    try {
      if (kIsWeb) {
        return NotificationPermissionStatus.granted.toSuccess();
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final areEnabled = await android.areNotificationsEnabled() ?? false;
        return (areEnabled
                ? NotificationPermissionStatus.granted
                : NotificationPermissionStatus.notDetermined)
            .toSuccess();
      }

      // iOS. The plugin has no read-only check, so this goes over the app's
      // own channel, which reads UNNotificationSettings.authorizationStatus.
      try {
        final granted = await _channel.invokeMethod<bool>(
          'checkNotificationPermission',
        );
        if (granted != null) {
          return (granted
                  ? NotificationPermissionStatus.granted
                  : NotificationPermissionStatus.notDetermined)
              .toSuccess();
        }
      } on PlatformException catch (_) {
        // No handler on this platform; fall through to "not asked yet".
      } on MissingPluginException catch (_) {
        // Same, on a platform with no channel at all.
      }

      return NotificationPermissionStatus.notDetermined.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async {
    try {
      if (kIsWeb) {
        return NotificationPermissionStatus.granted.toSuccess();
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final notifsGranted =
            await android.requestNotificationsPermission() ?? false;
        final fsiGranted =
            await android.requestFullScreenIntentPermission() ?? false;

        if (notifsGranted && fsiGranted) {
          return NotificationPermissionStatus.granted.toSuccess();
        } else {
          return NotificationPermissionStatus.denied.toSuccess();
        }
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted =
            await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            ) ??
            false;
        return (granted
                ? NotificationPermissionStatus.granted
                : NotificationPermissionStatus.denied)
            .toSuccess();
      }

      return NotificationPermissionStatus.granted.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<bool>> openSettings() async {
    try {
      final opened =
          await _channel.invokeMethod<bool>('openNotificationSettings') ?? true;
      return opened.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
