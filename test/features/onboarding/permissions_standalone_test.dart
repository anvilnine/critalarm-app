import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';

class MockRequestPermission extends Mock
    implements RequestNotificationPermissionUsecase {}

class MockCheckPermission extends Mock
    implements CheckNotificationPermissionUsecase {}

class MockOpenSettings extends Mock
    implements OpenNotificationSettingsUsecase {}

/// Health opens the prompt screen on its own for a permission the user was
/// never asked. It asks only what can still be asked, then closes.
void main() {
  late MockRequestPermission request;
  late MockCheckPermission check;
  late MockOpenSettings openSettings;
  late FakeAlarmHost fake;

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() {
    request = MockRequestPermission();
    check = MockCheckPermission();
    openSettings = MockOpenSettings();
    fake = FakeAlarmHost();
  });

  NotificationPermissionsCubit build() => NotificationPermissionsCubit(
    request,
    openSettings,
    alarm: fake.host,
    checkPermission: check,
    standalone: true,
  );

  blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
    'lands on the alarm step when only alarms were never asked',
    setUp: () {
      when(() => check(any())).thenAnswer(
        (_) async => NotificationPermissionStatus.granted.toSuccess(),
      );
      fake.answers['authorizationStatus'] = 'notDetermined';
    },
    build: build,
    act: (cubit) => cubit.refresh(),
    verify: (cubit) {
      expect(cubit.state.activeSubstep, 1);
      expect(cubit.state.canNavigate, isFalse);
    },
  );

  blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
    'closes after notifications when alarms cannot be asked again',
    setUp: () {
      when(() => check(any())).thenAnswer(
        (_) async => NotificationPermissionStatus.notDetermined.toSuccess(),
      );
      when(() => request(any())).thenAnswer(
        (_) async => NotificationPermissionStatus.granted.toSuccess(),
      );
      fake.answers['authorizationStatus'] = 'denied';
    },
    build: build,
    act: (cubit) async {
      await cubit.refresh();
      await cubit.requestNotifications();
    },
    verify: (cubit) {
      expect(cubit.state.activeSubstep, 0);
      expect(cubit.state.canNavigate, isTrue);
    },
  );

  blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
    '"Not now" closes when there is no alarm prompt left',
    setUp: () {
      when(() => check(any())).thenAnswer(
        (_) async => NotificationPermissionStatus.notDetermined.toSuccess(),
      );
      fake.answers['authorizationStatus'] = 'unsupported';
    },
    build: build,
    act: (cubit) async {
      await cubit.refresh();
      cubit.skipStep();
    },
    verify: (cubit) => expect(cubit.state.canNavigate, isTrue),
  );

  blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
    'onboarding still shows the alarm step when it only explains',
    setUp: () {
      when(() => check(any())).thenAnswer(
        (_) async => NotificationPermissionStatus.notDetermined.toSuccess(),
      );
      fake.answers['authorizationStatus'] = 'denied';
    },
    build: () => NotificationPermissionsCubit(
      request,
      openSettings,
      alarm: fake.host,
      checkPermission: check,
    ),
    act: (cubit) async {
      await cubit.refresh();
      cubit.skipStep();
    },
    verify: (cubit) {
      expect(cubit.state.activeSubstep, 1);
      expect(cubit.state.canNavigate, isFalse);
    },
  );
}
