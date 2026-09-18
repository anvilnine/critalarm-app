import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Platform implementation of [DevicePermissionsRepository] querying native
/// system state via [FlutterLocalNotificationsPlugin] and custom
/// [MethodChannel].
class PlatformDevicePermissionsRepository
    implements DevicePermissionsRepository {
  PlatformDevicePermissionsRepository({
    AlarmHost? alarm,
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
    TargetPlatform? platform,
    // The field is private and the parameter is public, so it cannot be an
    // initializing formal.
    // ignore: prefer_initializing_formals
  }) : _alarm = alarm,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel ?? const MethodChannel('app.critalarm/settings'),
       _platform = platform ?? defaultTargetPlatform;

  /// Null in tests and off iOS. Only the alarm row needs it.
  final AlarmHost? _alarm;
  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;
  final TargetPlatform _platform;

  List<DevicePermissionType> get _typesForPlatform =>
      devicePermissionTypesFor(_platform, isWeb: kIsWeb);

  static String _titleFor(DevicePermissionType type) => switch (type) {
    DevicePermissionType.notifications =>
      LocaleKeys.device_permissions_item_notifications_title.tr(),
    DevicePermissionType.fullScreenIntent =>
      LocaleKeys.device_permissions_item_full_screen_intent_title.tr(),
    DevicePermissionType.batteryOptimization =>
      LocaleKeys.device_permissions_item_battery_optimization_title.tr(),
    DevicePermissionType.timeSensitive =>
      LocaleKeys.device_permissions_item_time_sensitive_title.tr(),
    DevicePermissionType.alarms =>
      LocaleKeys.device_permissions_item_alarms_title.tr(),
  };

  static String _descriptionFor(DevicePermissionType type) => switch (type) {
    DevicePermissionType.notifications =>
      LocaleKeys.device_permissions_item_notifications_description.tr(),
    DevicePermissionType.fullScreenIntent =>
      LocaleKeys.device_permissions_item_full_screen_intent_description.tr(),
    DevicePermissionType.batteryOptimization =>
      LocaleKeys.device_permissions_item_battery_optimization_description.tr(),
    DevicePermissionType.timeSensitive =>
      LocaleKeys.device_permissions_item_time_sensitive_description.tr(),
    DevicePermissionType.alarms =>
      LocaleKeys.device_permissions_item_alarms_description.tr(),
  };

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() async {
    try {
      final items = <DevicePermissionItem>[];
      for (final type in _typesForPlatform) {
        final status = (await checkPermission(type)).fold(
          (status) => status,
          (_) => DevicePermissionStatus.denied,
        );
        items.add(
          DevicePermissionItem(
            type: type,
            title: _titleFor(type),
            description: _descriptionFor(type),
            status: status,
            canFix: status != DevicePermissionStatus.granted,
          ),
        );
      }
      return items.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async {
    try {
      if (kIsWeb) {
        return DevicePermissionStatus.granted.toSuccess();
      }

      switch (type) {
        case DevicePermissionType.notifications:
          try {
            final android = _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
            if (android != null) {
              final areEnabled =
                  await android.areNotificationsEnabled() ?? false;
              return (areEnabled
                      ? DevicePermissionStatus.granted
                      : DevicePermissionStatus.denied)
                  .toSuccess();
            }
          } on Object catch (_) {
            // Plugin platform implementation not available or not initialized
          }

          try {
            final res = await _channel.invokeMethod<bool>(
              'checkNotificationPermission',
            );
            if (res != null) {
              return (res
                      ? DevicePermissionStatus.granted
                      : DevicePermissionStatus.denied)
                  .toSuccess();
            }
          } on PlatformException catch (_) {
            // Ignore channel fallback failure
          }
          return DevicePermissionStatus.granted.toSuccess();

        case DevicePermissionType.fullScreenIntent:
          try {
            final res = await _channel.invokeMethod<bool>(
              'checkFullScreenIntent',
            );
            if (res != null) {
              return (res
                      ? DevicePermissionStatus.granted
                      : DevicePermissionStatus.denied)
                  .toSuccess();
            }
          } on PlatformException catch (_) {
            // Ignore channel fallback failure
          }
          return DevicePermissionStatus.granted.toSuccess();

        case DevicePermissionType.batteryOptimization:
          try {
            final isIgnoring = await _channel.invokeMethod<bool>(
              'checkBatteryOptimization',
            );
            if (isIgnoring != null) {
              return (isIgnoring
                      ? DevicePermissionStatus.granted
                      : DevicePermissionStatus.denied)
                  .toSuccess();
            }
          } on PlatformException catch (_) {
            // Ignore channel fallback failure
          }
          return DevicePermissionStatus.granted.toSuccess();

        case DevicePermissionType.timeSensitive:
          try {
            final enabled = await _channel.invokeMethod<bool>(
              'checkTimeSensitive',
            );
            if (enabled != null) {
              return (enabled
                      ? DevicePermissionStatus.granted
                      : DevicePermissionStatus.denied)
                  .toSuccess();
            }
          } on PlatformException catch (_) {
            // Ignore channel fallback failure
          }
          return DevicePermissionStatus.granted.toSuccess();

        case DevicePermissionType.alarms:
          final host = _alarm;
          if (host == null) {
            return DevicePermissionStatus.granted.toSuccess();
          }
          final authorization = await host.authorizationStatus();
          return switch (authorization) {
            AlarmAuthorization.authorized => DevicePermissionStatus.granted,
            AlarmAuthorization.denied => DevicePermissionStatus.denied,
            AlarmAuthorization.notDetermined =>
              DevicePermissionStatus.notDetermined,
            // Nothing to ask for on this OS, so nothing is wrong.
            AlarmAuthorization.unsupported => DevicePermissionStatus.granted,
          }.toSuccess();
      }
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<bool>> openPermissionSettings(
    DevicePermissionType type,
  ) async {
    try {
      final method = switch (type) {
        DevicePermissionType.notifications => 'openNotificationSettings',
        DevicePermissionType.fullScreenIntent => 'openFullScreenIntentSettings',
        DevicePermissionType.batteryOptimization =>
          'openBatteryOptimizationSettings',
        // Both live on this app's own page in iOS Settings.
        DevicePermissionType.timeSensitive ||
        DevicePermissionType.alarms => 'openNotificationSettings',
      };

      final opened = await _channel.invokeMethod<bool>(method) ?? true;
      return opened.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
