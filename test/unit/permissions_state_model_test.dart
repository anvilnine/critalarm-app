import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevicePermissionType', () {
    test('contains notifications, fullScreenIntent, batteryOptimization', () {
      expect(
        DevicePermissionType.values,
        containsAll([
          DevicePermissionType.notifications,
          DevicePermissionType.fullScreenIntent,
          DevicePermissionType.batteryOptimization,
        ]),
      );
      expect(DevicePermissionType.values.length, equals(3));
    });
  });

  group('DevicePermissionStatus', () {
    test('contains all 4 status values', () {
      expect(DevicePermissionStatus.values, [
        DevicePermissionStatus.granted,
        DevicePermissionStatus.denied,
        DevicePermissionStatus.restricted,
        DevicePermissionStatus.notDetermined,
      ]);
    });

    test('isGranted getter is true only for granted', () {
      expect(DevicePermissionStatus.granted.isGranted, isTrue);
      expect(DevicePermissionStatus.denied.isGranted, isFalse);
      expect(DevicePermissionStatus.restricted.isGranted, isFalse);
      expect(DevicePermissionStatus.notDetermined.isGranted, isFalse);
    });

    test('isDenied getter is true only for denied', () {
      expect(DevicePermissionStatus.denied.isDenied, isTrue);
      expect(DevicePermissionStatus.granted.isDenied, isFalse);
      expect(DevicePermissionStatus.restricted.isDenied, isFalse);
      expect(DevicePermissionStatus.notDetermined.isDenied, isFalse);
    });

    test('isRestricted getter is true only for restricted', () {
      expect(DevicePermissionStatus.restricted.isRestricted, isTrue);
      expect(DevicePermissionStatus.granted.isRestricted, isFalse);
      expect(DevicePermissionStatus.denied.isRestricted, isFalse);
      expect(DevicePermissionStatus.notDetermined.isRestricted, isFalse);
    });

    test('isNotDetermined getter is true only for notDetermined', () {
      expect(DevicePermissionStatus.notDetermined.isNotDetermined, isTrue);
      expect(DevicePermissionStatus.granted.isNotDetermined, isFalse);
      expect(DevicePermissionStatus.denied.isNotDetermined, isFalse);
      expect(DevicePermissionStatus.restricted.isNotDetermined, isFalse);
    });
  });

  group('DevicePermissionItem', () {
    const item = DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Alert banners and sound',
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    );

    test('properties retain assigned values', () {
      expect(item.type, DevicePermissionType.notifications);
      expect(item.title, 'Notifications');
      expect(item.description, 'Alert banners and sound');
      expect(item.status, DevicePermissionStatus.notDetermined);
      expect(item.canFix, isTrue);
    });

    test('copyWith updates properties correctly and preserves others', () {
      final updated = item.copyWith(
        status: DevicePermissionStatus.granted,
        canFix: false,
      );
      expect(updated.status, DevicePermissionStatus.granted);
      expect(updated.canFix, isFalse);
      expect(updated.type, item.type);
      expect(updated.title, item.title);
      expect(updated.description, item.description);

      final same = item.copyWith();
      expect(same, equals(item));
    });

    test('equality and hashCode compare field values correctly', () {
      const clone = DevicePermissionItem(
        type: DevicePermissionType.notifications,
        title: 'Notifications',
        description: 'Alert banners and sound',
        status: DevicePermissionStatus.notDetermined,
        canFix: true,
      );
      expect(item, equals(clone));
      expect(item.hashCode, equals(clone.hashCode));

      final different = item.copyWith(status: DevicePermissionStatus.denied);
      expect(item, isNot(equals(different)));
    });
  });

  group('DevicePermissionsState', () {
    test('initial state defaults match specifications', () {
      const state = DevicePermissionsState();

      expect(state.status, DevicePermissionsCubitStatus.initial);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isFailure, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.permissions.length, equals(3));
      expect(state.items, equals(state.permissions));
      expect(state.allGranted, isFalse);
      expect(state.hasIssues, isTrue);
      expect(state.hasDenied, isFalse);
    });

    test('status getters reflect cubit status', () {
      const loading = DevicePermissionsState(
        status: DevicePermissionsCubitStatus.loading,
      );
      expect(loading.isLoading, isTrue);
      expect(loading.isSuccess, isFalse);
      expect(loading.isFailure, isFalse);

      const success = DevicePermissionsState(
        status: DevicePermissionsCubitStatus.success,
      );
      expect(success.isSuccess, isTrue);
      expect(success.isLoading, isFalse);
      expect(success.isFailure, isFalse);

      const failure = DevicePermissionsState(
        status: DevicePermissionsCubitStatus.failure,
        errorMessage: 'Failed to query permissions',
      );
      expect(failure.isFailure, isTrue);
      expect(failure.errorMessage, 'Failed to query permissions');
    });

    test('allGranted is true when every permission is granted', () {
      final allGrantedItems = [
        const DevicePermissionItem(
          type: DevicePermissionType.notifications,
          title: 'Notifications',
          description: 'desc',
          status: DevicePermissionStatus.granted,
          canFix: false,
        ),
        const DevicePermissionItem(
          type: DevicePermissionType.fullScreenIntent,
          title: 'Full screen',
          description: 'desc',
          status: DevicePermissionStatus.granted,
          canFix: false,
        ),
      ];

      final state = DevicePermissionsState(permissions: allGrantedItems);
      expect(state.allGranted, isTrue);
      expect(state.hasIssues, isFalse);
      expect(state.hasDenied, isFalse);
    });

    test('hasDenied is true when at least one permission is denied', () {
      final itemsWithDenial = [
        const DevicePermissionItem(
          type: DevicePermissionType.notifications,
          title: 'Notifications',
          description: 'desc',
          status: DevicePermissionStatus.granted,
          canFix: false,
        ),
        const DevicePermissionItem(
          type: DevicePermissionType.batteryOptimization,
          title: 'Battery',
          description: 'desc',
          status: DevicePermissionStatus.denied,
          canFix: true,
        ),
      ];

      final state = DevicePermissionsState(permissions: itemsWithDenial);
      expect(state.allGranted, isFalse);
      expect(state.hasIssues, isTrue);
      expect(state.hasDenied, isTrue);
    });

    test('permissionByType locates correct item by type', () {
      const state = DevicePermissionsState();
      final notificationItem = state.permissionByType(
        DevicePermissionType.notifications,
      );
      expect(notificationItem, isNotNull);
      expect(notificationItem?.type, DevicePermissionType.notifications);

      final batteryItem = state.permissionByType(
        DevicePermissionType.batteryOptimization,
      );
      expect(batteryItem, isNotNull);
      expect(batteryItem?.type, DevicePermissionType.batteryOptimization);
    });

    test('empty permissions list edge cases', () {
      const emptyState = DevicePermissionsState(permissions: []);
      expect(emptyState.allGranted, isFalse);
      expect(emptyState.hasIssues, isFalse);
      expect(emptyState.hasDenied, isFalse);
      expect(emptyState.items, isEmpty);
      expect(
        emptyState.permissionByType(DevicePermissionType.notifications),
        isNull,
      );
    });

    test('copyWith works correctly with overrides and clearError', () {
      const initial = DevicePermissionsState(
        status: DevicePermissionsCubitStatus.failure,
        errorMessage: 'Some error',
      );

      final cleared = initial.copyWith(
        status: DevicePermissionsCubitStatus.success,
        clearError: true,
      );
      expect(cleared.status, DevicePermissionsCubitStatus.success);
      expect(cleared.errorMessage, isNull);

      final updatedPermissions = initial.copyWith(
        permissions: const [],
      );
      expect(updatedPermissions.permissions, isEmpty);
      expect(updatedPermissions.errorMessage, 'Some error');
    });

    test(
      'equality and hashCode compare all fields including permissions list',
      () {
        const a = DevicePermissionsState();
        const b = DevicePermissionsState();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        final c = a.copyWith(status: DevicePermissionsCubitStatus.loading);
        expect(a, isNot(equals(c)));

        final d = a.copyWith(errorMessage: 'Network error');
        expect(a, isNot(equals(d)));

        final e = a.copyWith(permissions: const []);
        expect(a, isNot(equals(e)));
      },
    );
  });
}
