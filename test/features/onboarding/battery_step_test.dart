import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';

class MockRequestPermission extends Mock
    implements RequestNotificationPermissionUsecase {}

class MockCheckPermission extends Mock
    implements CheckNotificationPermissionUsecase {}

class MockOpenSettings extends Mock
    implements OpenNotificationSettingsUsecase {}

class MockGetDevicePermissions extends Mock
    implements GetDevicePermissionsUsecase {}

class MockOpenPermissionSettings extends Mock
    implements OpenPermissionSettingsUsecase {}

DevicePermissionItem _item(
  DevicePermissionType type,
  DevicePermissionStatus status,
) => DevicePermissionItem(
  type: type,
  title: type.name,
  description: '',
  status: status,
  canFix: status != DevicePermissionStatus.granted,
);

void main() {
  late MockRequestPermission request;
  late MockCheckPermission check;
  late MockOpenSettings openSettings;
  late MockGetDevicePermissions getPermissions;
  late MockOpenPermissionSettings openPermission;
  late FakeAlarmHost fake;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(DevicePermissionType.notifications);
  });

  setUp(() {
    request = MockRequestPermission();
    check = MockCheckPermission();
    openSettings = MockOpenSettings();
    getPermissions = MockGetDevicePermissions();
    openPermission = MockOpenPermissionSettings();
    fake = FakeAlarmHost();
    // Android: no AlarmKit.
    fake.answers['authorizationStatus'] = 'unsupported';
    when(() => check(any())).thenAnswer(
      (_) async => NotificationPermissionStatus.granted.toSuccess(),
    );
    when(() => openPermission(any())).thenAnswer((_) async => true.toSuccess());
  });

  NotificationPermissionsCubit build() => NotificationPermissionsCubit(
    request,
    openSettings,
    alarm: fake.host,
    checkPermission: check,
    getDevicePermissions: getPermissions,
    openPermissionSettings: openPermission,
  );

  void batteryIs(DevicePermissionStatus status) {
    when(() => getPermissions(any())).thenAnswer(
      (_) async => [
        _item(
          DevicePermissionType.notifications,
          DevicePermissionStatus.granted,
        ),
        _item(DevicePermissionType.batteryOptimization, status),
      ].toSuccess(),
    );
  }

  group('Android battery step', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'battery still optimised lands on the battery step, not past it',
      setUp: () => batteryIs(DevicePermissionStatus.denied),
      build: build,
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.activeSubstep, 1);
        expect(cubit.state.isBatteryStep, isTrue);
        expect(cubit.state.totalSteps, 2);
        expect(cubit.state.canNavigate, isFalse);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'battery already exempt goes straight through',
      setUp: () => batteryIs(DevicePermissionStatus.granted),
      build: build,
      act: (cubit) => cubit.refresh(),
      verify: (cubit) => expect(cubit.state.canNavigate, isTrue),
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'the button opens the battery prompt and the resume moves on',
      setUp: () => batteryIs(DevicePermissionStatus.denied),
      build: build,
      act: (cubit) async {
        await cubit.refresh();
        await cubit.requestBatteryExemption();
        // The user taps Allow in the system prompt and comes back.
        batteryIs(DevicePermissionStatus.granted);
        await cubit.refresh();
      },
      verify: (cubit) {
        verify(
          () => openPermission(DevicePermissionType.batteryOptimization),
        ).called(1);
        expect(cubit.state.canNavigate, isTrue);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'skipping the battery step is never a wall',
      setUp: () => batteryIs(DevicePermissionStatus.denied),
      build: build,
      act: (cubit) async {
        await cubit.refresh();
        cubit.continueWithout();
      },
      verify: (cubit) => expect(cubit.state.canNavigate, isTrue),
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'granting notifications moves on to the battery step',
      setUp: () {
        when(() => check(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.denied.toSuccess(),
        );
        when(() => request(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );
        batteryIs(DevicePermissionStatus.denied);
      },
      build: build,
      act: (cubit) async {
        await cubit.refresh();
        await cubit.requestNotifications();
      },
      verify: (cubit) {
        expect(cubit.state.activeSubstep, 1);
        expect(cubit.state.isBatteryStep, isTrue);
        expect(cubit.state.canNavigate, isFalse);
      },
    );
  });

  group('iOS has no battery step', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'no battery row means no battery step',
      setUp: () {
        fake.answers['authorizationStatus'] = 'authorized';
        when(() => getPermissions(any())).thenAnswer(
          (_) async => [
            _item(
              DevicePermissionType.notifications,
              DevicePermissionStatus.granted,
            ),
          ].toSuccess(),
        );
      },
      build: build,
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.batteryNeeded, isFalse);
        expect(cubit.state.isBatteryStep, isFalse);
        expect(cubit.state.canNavigate, isTrue);
      },
    );
  });
}
