import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/read_permission_setup_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:flutter/foundation.dart';

import '../../../core/alarm/fake_alarm_host.dart';

const samsung = DeviceMaker(manufacturer: 'samsung', brand: 'samsung');
const pixel = DeviceMaker(manufacturer: 'Google', brand: 'google');

/// The notification permission of a phone a test controls.
class FakeNotificationPermissions implements NotificationPermissionRepository {
  NotificationPermissionStatus status =
      NotificationPermissionStatus.notDetermined;

  /// What the prompt answers. It becomes [status], as on a phone.
  NotificationPermissionStatus requestAnswer =
      NotificationPermissionStatus.granted;

  /// Makes the prompt fail outright, as a missing plugin does.
  bool requestFails = false;

  int checks = 0;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async {
    checks++;
    return status.toSuccess();
  }

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async {
    requests++;
    if (requestFails) {
      return const Failure.unexpected(
        message: 'Plugin unavailable',
      ).toFailure();
    }
    status = requestAnswer;
    return status.toSuccess();
  }

  @override
  Future<AppResult<bool>> openSettings() async {
    settingsOpened++;
    return true.toSuccess();
  }
}

/// The Android permissions of a phone a test controls. Anything not set is
/// not granted.
class FakeDevicePermissions implements DevicePermissionsRepository {
  final Map<DevicePermissionType, DevicePermissionStatus> statuses = {};

  /// Every status read, in order.
  final List<DevicePermissionType> checked = [];

  /// Every settings page opened, in order.
  final List<DevicePermissionType> opened = [];

  void grant(DevicePermissionType type) =>
      statuses[type] = DevicePermissionStatus.granted;

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async {
    checked.add(type);
    return (statuses[type] ?? DevicePermissionStatus.denied).toSuccess();
  }

  @override
  Future<AppResult<bool>> openPermissionSettings(
    DevicePermissionType type,
  ) async {
    opened.add(type);
    return true.toSuccess();
  }

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() async =>
      <DevicePermissionItem>[].toSuccess();
}

/// Counts the reads, so a test can see the maker is asked for on Android
/// and nowhere else.
class CountingMakerReader implements DeviceMakerReader {
  CountingMakerReader(this.maker);

  DeviceMaker maker;
  int reads = 0;

  @override
  Future<DeviceMaker> read() async {
    reads++;
    return maker;
  }
}

/// One phone: the real reader and the real cubit over fakes for everything
/// that touches the system.
class PermissionPhone {
  PermissionPhone(
    this.platform, {
    this.isWeb = false,
    DeviceMaker maker = DeviceMaker.unknown,
    String alarmStatus = 'unsupported',
  }) : maker = CountingMakerReader(maker) {
    alarm.answers['authorizationStatus'] = alarmStatus;
    alarm.answers['requestAuthorization'] = alarmStatus;
  }

  /// An iPhone on iOS 26 or later, AlarmKit never asked.
  PermissionPhone.ios26({String alarmStatus = 'notDetermined'})
    : this(TargetPlatform.iOS, alarmStatus: alarmStatus);

  /// An iPhone on iOS 16 to 25. There is no AlarmKit.
  PermissionPhone.iosOld() : this(TargetPlatform.iOS);

  /// An Android phone. [maker] decides whether it has a battery step.
  PermissionPhone.android({DeviceMaker maker = pixel})
    : this(TargetPlatform.android, maker: maker);

  final TargetPlatform platform;
  final bool isWeb;
  final CountingMakerReader maker;
  final FakeNotificationPermissions notifications =
      FakeNotificationPermissions();
  final FakeDevicePermissions device = FakeDevicePermissions();
  final FakeAlarmHost alarm = FakeAlarmHost();

  void grantNotifications() =>
      notifications.status = NotificationPermissionStatus.granted;

  late final ReadPermissionSetupUsecase read = ReadPermissionSetupUsecase(
    platform: platform,
    isWeb: isWeb,
    checkNotifications: CheckNotificationPermissionUsecase(notifications),
    alarm: alarm.host,
    devicePermissions: device,
    makerReader: maker,
  );

  NotificationPermissionsCubit cubit({
    bool replayForDemo = false,
    bool standalone = false,
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) => NotificationPermissionsCubit(
    RequestNotificationPermissionUsecase(notifications),
    OpenNotificationSettingsUsecase(notifications),
    readSetup: read,
    alarm: alarm.host,
    devicePermissions: device,
    replayForDemo: replayForDemo,
    standalone: standalone,
    initialStep: initialStep,
  );
}

/// Every state a cubit emits from now on, in order.
List<NotificationPermissionsState> record(NotificationPermissionsCubit cubit) {
  final states = <NotificationPermissionsState>[];
  cubit.stream.listen(states.add);
  return states;
}
