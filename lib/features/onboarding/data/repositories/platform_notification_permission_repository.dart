import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform implementation of [NotificationPermissionRepository] using
/// [FlutterLocalNotificationsPlugin] and a custom platform method channel for
/// system settings deep linking.
class PlatformNotificationPermissionRepository
    implements NotificationPermissionRepository {
  PlatformNotificationPermissionRepository({
    required PlatformCapabilities capabilities,
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
    this.prefs,
    // The field is private and the parameter is public, so it cannot be an
    // initializing formal.
    // ignore: prefer_initializing_formals
  }) : _capabilities = capabilities,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel ?? const MethodChannel('app.critalarm/settings');

  final PlatformCapabilities _capabilities;
  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;

  /// Null in tests. Holds [_askedKey].
  final SharedPreferences? prefs;

  /// Set once the app has shown the system prompt. Neither platform tells an
  /// app apart "never asked" from "said no", so the app remembers it asked.
  static const _askedKey = 'notifications_prompt_shown';

  /// What a phone without the permission reports: denied once the prompt
  /// has been shown, not determined before that.
  NotificationPermissionStatus get _notGranted =>
      (prefs?.getBool(_askedKey) ?? false)
      ? NotificationPermissionStatus.denied
      : NotificationPermissionStatus.notDetermined;

  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async {
    try {
      if (_capabilities.isWeb) {
        return NotificationPermissionStatus.granted.toSuccess();
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final areEnabled = await android.areNotificationsEnabled() ?? false;
        return (areEnabled ? NotificationPermissionStatus.granted : _notGranted)
            .toSuccess();
      }

      // iOS. The plugin has no read-only check, so this goes over the app's
      // own channel, which reads UNNotificationSettings.authorizationStatus.
      try {
        final granted = await _channel.invokeMethod<bool>(
          'checkNotificationPermission',
        );
        if (granted != null) {
          return (granted ? NotificationPermissionStatus.granted : _notGranted)
              .toSuccess();
        }
      } on PlatformException catch (_) {
        // No handler on this platform; fall through to "not asked yet".
      } on MissingPluginException catch (_) {
        // Same, on a platform with no channel at all.
      }

      return _notGranted.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async {
    try {
      if (_capabilities.isWeb) {
        return NotificationPermissionStatus.granted.toSuccess();
      }
      await prefs?.setBool(_askedKey, true);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        // Notifications only. The full-screen alarm permission is its own
        // step 2 in onboarding, so it is asked there with its own words.
        final notifsGranted =
            await android.requestNotificationsPermission() ?? false;
        return (notifsGranted
                ? NotificationPermissionStatus.granted
                : NotificationPermissionStatus.denied)
            .toSuccess();
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
