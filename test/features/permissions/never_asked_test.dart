import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetPermissions extends Mock implements GetDevicePermissionsUsecase {}

class MockOpenSettings extends Mock implements OpenPermissionSettingsUsecase {}

class MockCheckNotifications extends Mock
    implements CheckNotificationPermissionUsecase {}

DevicePermissionItem _item(
  DevicePermissionType type,
  DevicePermissionStatus status,
) => DevicePermissionItem(
  type: type,
  title: type.name,
  description: '',
  status: status,
  canFix: true,
);

/// Health's "Turn on" asks in the app only when the system prompt can still
/// show. Everything else goes to the system settings screen.
void main() {
  late MockGetPermissions getPermissions;
  late MockCheckNotifications check;
  late DevicePermissionsCubit cubit;

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() {
    getPermissions = MockGetPermissions();
    check = MockCheckNotifications();
    cubit = DevicePermissionsCubit(
      getPermissions,
      MockOpenSettings(),
      checkNotifications: check,
    );
  });

  tearDown(() => cubit.close());

  test('notifications never asked', () async {
    when(() => check(any())).thenAnswer(
      (_) async => NotificationPermissionStatus.notDetermined.toSuccess(),
    );
    expect(await cubit.neverAsked(DevicePermissionType.notifications), isTrue);
  });

  test('notifications already refused', () async {
    when(() => check(any())).thenAnswer(
      (_) async => NotificationPermissionStatus.denied.toSuccess(),
    );
    expect(
      await cubit.neverAsked(DevicePermissionType.notifications),
      isFalse,
    );
  });

  test('alarms follow the status Health already read', () async {
    when(() => getPermissions(any())).thenAnswer(
      (_) async => [
        _item(
          DevicePermissionType.alarms,
          DevicePermissionStatus.notDetermined,
        ),
      ].toSuccess(),
    );
    await cubit.loadPermissions();
    expect(await cubit.neverAsked(DevicePermissionType.alarms), isTrue);

    when(() => getPermissions(any())).thenAnswer(
      (_) async => [
        _item(DevicePermissionType.alarms, DevicePermissionStatus.denied),
      ].toSuccess(),
    );
    await cubit.loadPermissions();
    expect(await cubit.neverAsked(DevicePermissionType.alarms), isFalse);
  });

  test('settings-only permissions never ask in the app', () async {
    expect(
      await cubit.neverAsked(DevicePermissionType.timeSensitive),
      isFalse,
    );
    expect(
      await cubit.neverAsked(DevicePermissionType.batteryOptimization),
      isFalse,
    );
  });
}
