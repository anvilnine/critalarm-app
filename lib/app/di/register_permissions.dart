import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/permissions/data/repositories/platform_device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notification and device permission repositories.
void registerPermissionRepositories(GetIt getIt) {
  getIt
    ..registerLazySingleton<NotificationPermissionRepository>(
      () => PlatformNotificationPermissionRepository(
        capabilities: getIt<PlatformCapabilities>(),
        prefs: getIt<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<DevicePermissionsRepository>(
      () => PlatformDevicePermissionsRepository(
        capabilities: getIt<PlatformCapabilities>(),
        alarm: getIt<AlarmHost>(),
      ),
    );
}

/// The permission usecases, notification ones included.
void registerPermissionUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetDevicePermissionsUsecase(
        getIt<DevicePermissionsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => OpenPermissionSettingsUsecase(
        getIt<DevicePermissionsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => CheckNotificationPermissionUsecase(
        getIt<NotificationPermissionRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => RequestNotificationPermissionUsecase(
        getIt<NotificationPermissionRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => OpenNotificationSettingsUsecase(
        getIt<NotificationPermissionRepository>(),
      ),
    );
}

/// The device permissions cubit.
void registerPermissionsCubit(GetIt getIt) {
  getIt.registerFactory(
    () => DevicePermissionsCubit(
      getIt<GetDevicePermissionsUsecase>(),
      getIt<OpenPermissionSettingsUsecase>(),
      capabilities: getIt<PlatformCapabilities>(),
      checkNotifications: getIt<CheckNotificationPermissionUsecase>(),
    ),
  );
}
