import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';

class _Request extends Mock implements RequestNotificationPermissionUsecase {}

class _Check extends Mock implements CheckNotificationPermissionUsecase {}

class _Open extends Mock implements OpenNotificationSettingsUsecase {}

class _Permissions extends Mock implements DevicePermissionsRepository {}

void main() {
  late _Request request;
  late _Check check;
  late _Open open;
  late _Permissions permissions;
  late FakeAlarmHost fake;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(DevicePermissionType.fullScreenIntent);
  });

  setUp(() {
    request = _Request();
    check = _Check();
    open = _Open();
    permissions = _Permissions();
    fake = FakeAlarmHost();
    // Android's alarm channel answers unsupported.
    fake.answers['authorizationStatus'] = 'unsupported';
    when(() => check(any())).thenAnswer(
      (_) async => NotificationPermissionStatus.granted.toSuccess(),
    );
    when(
      () => permissions.openPermissionSettings(any()),
    ).thenAnswer((_) async => true.toSuccess());
  });

  void fullScreen(DevicePermissionStatus status) {
    when(
      () => permissions.checkPermission(DevicePermissionType.fullScreenIntent),
    ).thenAnswer((_) async => status.toSuccess());
  }

  NotificationPermissionsCubit android({bool standalone = false}) =>
      NotificationPermissionsCubit(
        request,
        open,
        alarm: fake.host,
        checkPermission: check,
        devicePermissions: permissions,
        platform: TargetPlatform.android,
        standalone: standalone,
      );

  group('Android step 2 is the full-screen alarm permission', () {
    test(
      'Android never gets the iOS 26 copy, whatever the alarm channel says',
      () {
        for (final auth in AlarmAuthorization.values) {
          expect(
            RingClaim.forPhone(
              auth,
              platform: TargetPlatform.android,
              isWeb: false,
            ),
            RingClaim.alarm,
          );
        }
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'step 2 stays and is marked as a full-screen step',
      setUp: () => fullScreen(DevicePermissionStatus.denied),
      build: android,
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.fullScreenStep, isTrue);
        expect(cubit.state.fullScreenGranted, isFalse);
        expect(cubit.state.alarmSupported, isFalse);
        expect(cubit.state.activeSubstep, 1);
        expect(cubit.state.canNavigate, isFalse);
        expect(
          RingClaim.forPhone(
            cubit.state.alarm,
            platform: TargetPlatform.android,
            isWeb: false,
          ),
          RingClaim.alarm,
        );
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'both granted lets onboarding move on',
      setUp: () => fullScreen(DevicePermissionStatus.granted),
      build: android,
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.canNavigate, isTrue);
        expect(cubit.state.criticalAlertsGranted, isTrue);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'the button opens the full-screen settings page and waits',
      setUp: () => fullScreen(DevicePermissionStatus.denied),
      build: android,
      act: (cubit) async {
        await cubit.refresh();
        await cubit.requestCriticalAlerts();
      },
      verify: (cubit) {
        verify(
          () => permissions.openPermissionSettings(
            DevicePermissionType.fullScreenIntent,
          ),
        ).called(1);
        expect(cubit.state.canNavigate, isFalse);
        expect(fake.callsTo('requestAuthorization'), isEmpty);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'standalone closes at once when it is already granted',
      setUp: () => fullScreen(DevicePermissionStatus.granted),
      build: () => android(standalone: true),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) => expect(cubit.state.canNavigate, isTrue),
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'Not now on step 1 reaches step 2 on Android',
      setUp: () => fullScreen(DevicePermissionStatus.denied),
      build: android,
      act: (cubit) async {
        await cubit.refresh();
        cubit.skipStep();
      },
      verify: (cubit) => expect(cubit.state.activeSubstep, 1),
    );
  });
}
