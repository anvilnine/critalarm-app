import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestNotificationPermissionUsecase extends Mock
    implements RequestNotificationPermissionUsecase {}

class MockOpenNotificationSettingsUsecase extends Mock
    implements OpenNotificationSettingsUsecase {}

void main() {
  late MockRequestNotificationPermissionUsecase mockRequestPermission;
  late MockOpenNotificationSettingsUsecase mockOpenSettings;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockRequestPermission = MockRequestNotificationPermissionUsecase();
    mockOpenSettings = MockOpenNotificationSettingsUsecase();
  });

  group('NotificationPermissionsCubit', () {
    test('initial state has initial step and cannot navigate', () async {
      final cubit = NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      );
      expect(cubit.state.step, NotificationPermissionStep.initial);
      expect(cubit.state.canNavigate, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'requestPermissions granted emits requesting then granted',
      setUp: () {
        when(() => mockRequestPermission(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );
      },
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.requestPermissions(),
      expect: () => [
        const NotificationPermissionsState(
          step: NotificationPermissionStep.requesting,
        ),
        const NotificationPermissionsState(
          step: NotificationPermissionStep.granted,
          notificationsGranted: true,
          criticalAlertsGranted: true,
          canNavigate: true,
          alarmSupported: false,
        ),
      ],
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'requestPermissions denied emits requesting then denied path',
      setUp: () {
        when(() => mockRequestPermission(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.denied.toSuccess(),
        );
      },
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.requestPermissions(),
      expect: () => [
        const NotificationPermissionsState(
          step: NotificationPermissionStep.requesting,
        ),
        const NotificationPermissionsState(
          step: NotificationPermissionStep.denied,
        ),
      ],
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'requestPermissions failure emits requesting then denied with error',
      setUp: () {
        when(() => mockRequestPermission(any())).thenAnswer(
          (_) async => const Failure.unexpected(
            message: 'Plugin unavailable',
          ).toFailure(),
        );
      },
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.requestPermissions(),
      expect: () => [
        const NotificationPermissionsState(
          step: NotificationPermissionStep.requesting,
        ),
        const NotificationPermissionsState(
          step: NotificationPermissionStep.denied,
          errorMessage: 'Something went wrong on the server. Try again.',
        ),
      ],
    );

    test('openSettings calls openSettings usecase', () async {
      when(
        () => mockOpenSettings(any()),
      ).thenAnswer((_) async => true.toSuccess());

      final cubit = NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      );
      await cubit.openSettings();
      verify(() => mockOpenSettings(any())).called(1);
      await cubit.close();
    });

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'requestCriticalAlerts without alarm host marks granted directly',
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      act: (cubit) => cubit.requestCriticalAlerts(),
      expect: () => [
        const NotificationPermissionsState(
          step: NotificationPermissionStep.granted,
          criticalAlertsGranted: true,
          canNavigate: true,
          // No alarm host means no alarm permission on this platform, so the
          // stepper is one step, not two.
          alarmSupported: false,
        ),
      ],
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'navigationHandled clears canNavigate',
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      seed: () => const NotificationPermissionsState(
        step: NotificationPermissionStep.granted,
        canNavigate: true,
      ),
      act: (cubit) => cubit.navigationHandled(),
      expect: () => [
        const NotificationPermissionsState(
          step: NotificationPermissionStep.granted,
        ),
      ],
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'reset returns state to initial',
      build: () => NotificationPermissionsCubit(
        mockRequestPermission,
        mockOpenSettings,
      ),
      seed: () => const NotificationPermissionsState(
        step: NotificationPermissionStep.denied,
      ),
      act: (cubit) => cubit.reset(),
      expect: () => [
        const NotificationPermissionsState(),
      ],
    );
  });
}
