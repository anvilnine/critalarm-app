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
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel ?? const MethodChannel('app.critalarm/settings');

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() async {
    try {
      final notifsResult = await checkPermission(
        DevicePermissionType.notifications,
      );
      final fsiResult = await checkPermission(
        DevicePermissionType.fullScreenIntent,
      );
      final batteryResult = await checkPermission(
        DevicePermissionType.batteryOptimization,
      );

      final notifsStatus = notifsResult.fold(
        (status) => status,
        (_) => DevicePermissionStatus.denied,
      );
      final fsiStatus = fsiResult.fold(
        (status) => status,
        (_) => DevicePermissionStatus.denied,
      );
      final batteryStatus = batteryResult.fold(
        (status) => status,
        (_) => DevicePermissionStatus.denied,
      );

      final items = [
        DevicePermissionItem(
          type: DevicePermissionType.notifications,
          title: LocaleKeys.device_permissions_item_notifications_title.tr(),
          description:
              LocaleKeys.device_permissions_item_notifications_description.tr(),
          status: notifsStatus,
          canFix: notifsStatus != DevicePermissionStatus.granted,
        ),
        DevicePermissionItem(
          type: DevicePermissionType.fullScreenIntent,
          title:
              LocaleKeys.device_permissions_item_full_screen_intent_title.tr(),
          description:
              LocaleKeys
                  .device_permissions_item_full_screen_intent_description
                  .tr(),
          status: fsiStatus,
          canFix: fsiStatus != DevicePermissionStatus.granted,
        ),
        DevicePermissionItem(
          type: DevicePermissionType.batteryOptimization,
          title:
              LocaleKeys.device_permissions_item_battery_optimization_title
                  .tr(),
          description:
              LocaleKeys
                  .device_permissions_item_battery_optimization_description
                  .tr(),
          status: batteryStatus,
          canFix: batteryStatus != DevicePermissionStatus.granted,
        ),
      ];

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
      };

      final opened = await _channel.invokeMethod<bool>(method) ?? true;
      return opened.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
