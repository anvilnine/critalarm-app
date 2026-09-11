import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDevicePermissionsUsecase extends Mock
    implements GetDevicePermissionsUsecase {}

class MockOpenPermissionSettingsUsecase extends Mock
    implements OpenPermissionSettingsUsecase {}

void main() {
  late MockGetDevicePermissionsUsecase mockGetPermissions;
  late MockOpenPermissionSettingsUsecase mockOpenSettings;

  final testPermissionsGranted = [
    const DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows banners and sound.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: 'Full-screen intent',
      description: 'Allows lock screen wake.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.batteryOptimization,
      title: 'Battery optimization exemption',
      description: 'Prevents killing alarm sync.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    ),
  ];

  final testPermissionsDenied = [
    const DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows banners and sound.',
      status: DevicePermissionStatus.denied,
      canFix: true,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: 'Full-screen intent',
      description: 'Allows lock screen wake.',
      status: DevicePermissionStatus.restricted,
      canFix: true,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.batteryOptimization,
      title: 'Battery optimization exemption',
      description: 'Prevents killing alarm sync.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(DevicePermissionType.notifications);
  });

  setUp(() {
    mockGetPermissions = MockGetDevicePermissionsUsecase();
    mockOpenSettings = MockOpenPermissionSettingsUsecase();
  });

  group('DevicePermissionsCubit', () {
    test('initial state has default permissions and initial status', () {
      final cubit = DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      );

      expect(cubit.state.status, DevicePermissionsCubitStatus.initial);
      expect(cubit.state.permissions.length, 3);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isSuccess, isFalse);
      expect(cubit.state.isFailure, isFalse);
      expect(cubit.state.allGranted, isFalse);
      expect(cubit.state.hasIssues, isTrue);
      expect(
        cubit.state.permissionByType(DevicePermissionType.notifications),
        isNotNull,
      );
    });

    blocTest<DevicePermissionsCubit, DevicePermissionsState>(
      'loadPermissions emits loading then success with permissions list',
      setUp: () {
        when(
          () => mockGetPermissions(any()),
        ).thenAnswer((_) async => testPermissionsGranted.toSuccess());
      },
      build: () => DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.loadPermissions(),
      expect: () => [
        isA<DevicePermissionsState>().having(
          (s) => s.status,
          'status',
          DevicePermissionsCubitStatus.loading,
        ),
        isA<DevicePermissionsState>()
            .having(
              (s) => s.status,
              'status',
              DevicePermissionsCubitStatus.success,
            )
            .having((s) => s.permissions, 'permissions', testPermissionsGranted)
            .having((s) => s.allGranted, 'allGranted', isTrue)
            .having((s) => s.hasIssues, 'hasIssues', isFalse),
      ],
      verify: (_) {
        verify(() => mockGetPermissions(any())).called(1);
      },
    );

    blocTest<DevicePermissionsCubit, DevicePermissionsState>(
      'loadPermissions emits loading then failure on error',
      setUp: () {
        when(() => mockGetPermissions(any())).thenAnswer(
          (_) async => const Failure.unexpected(
            message: 'Failed to inspect device permissions',
          ).toFailure(),
        );
      },
      build: () => DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.loadPermissions(),
      expect: () => [
        isA<DevicePermissionsState>().having(
          (s) => s.status,
          'status',
          DevicePermissionsCubitStatus.loading,
        ),
        isA<DevicePermissionsState>()
            .having(
              (s) => s.status,
              'status',
              DevicePermissionsCubitStatus.failure,
            )
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to inspect device permissions',
            )
            .having((s) => s.allGranted, 'allGranted', isFalse)
            .having((s) => s.hasIssues, 'hasIssues', isTrue),
      ],
    );

    blocTest<DevicePermissionsCubit, DevicePermissionsState>(
      'state reflects hasIssues when some permissions denied',
      setUp: () {
        when(
          () => mockGetPermissions(any()),
        ).thenAnswer((_) async => testPermissionsDenied.toSuccess());
      },
      build: () => DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.loadPermissions(),
      expect: () => [
        isA<DevicePermissionsState>().having(
          (s) => s.status,
          'status',
          DevicePermissionsCubitStatus.loading,
        ),
        isA<DevicePermissionsState>()
            .having(
              (s) => s.status,
              'status',
              DevicePermissionsCubitStatus.success,
            )
            .having((s) => s.allGranted, 'allGranted', isFalse)
            .having((s) => s.hasIssues, 'hasIssues', isTrue),
      ],
    );

    test('openSettings invokes openPermissionSettings usecase', () async {
      when(
        () => mockOpenSettings(any()),
      ).thenAnswer((_) async => true.toSuccess());
      when(
        () => mockGetPermissions(any()),
      ).thenAnswer((_) async => testPermissionsGranted.toSuccess());

      final cubit = DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      );

      await cubit.openSettings(DevicePermissionType.fullScreenIntent);

      verify(
        () => mockOpenSettings(DevicePermissionType.fullScreenIntent),
      ).called(1);
      await cubit.close();
    });

    test('refresh invokes loadPermissions', () async {
      when(
        () => mockGetPermissions(any()),
      ).thenAnswer((_) async => testPermissionsGranted.toSuccess());

      final cubit = DevicePermissionsCubit(
        mockGetPermissions,
        mockOpenSettings,
      );

      await cubit.refresh();

      verify(() => mockGetPermissions(any())).called(1);
      await cubit.close();
    });
  });
}
