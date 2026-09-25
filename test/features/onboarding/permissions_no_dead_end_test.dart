import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
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

  group('a refused permission is never a wall', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'a denied alarm still lets the user through',
      setUp: () {
        fake.answers['requestAuthorization'] = 'denied';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
      ),
      act: (cubit) => cubit.requestCriticalAlerts(),
      verify: (cubit) {
        // AlarmKit never prompts twice, so blocking here would strand the
        // user for good, and Apple flags exactly that.
        expect(cubit.state.canNavigate, isTrue);
        expect(cubit.state.alarm, AlarmAuthorization.denied);
        expect(cubit.state.criticalAlertsGranted, isFalse);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'continueWithout leaves the denied screen',
      build: () => NotificationPermissionsCubit(request, openSettings),
      seed: () => const NotificationPermissionsState(
        step: NotificationPermissionStep.denied,
      ),
      act: (cubit) => cubit.continueWithout(),
      verify: (cubit) {
        expect(cubit.state.isDenied, isFalse);
        expect(cubit.state.canNavigate, isTrue);
      },
    );
  });

  group('no denied screen', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'refused notifications land on step two',
      setUp: () {
        when(() => request(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.denied.toSuccess(),
        );
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
      ),
      act: (cubit) => cubit.requestNotifications(),
      verify: (cubit) {
        expect(cubit.state.isDenied, isFalse);
        expect(cubit.state.activeSubstep, 1);
        expect(cubit.state.canNavigate, isFalse);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'not now on step one goes to step two without asking',
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
      ),
      act: (cubit) => cubit.skipStep(),
      verify: (cubit) {
        expect(cubit.state.activeSubstep, 1);
        verifyNever(() => request(any()));
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'not now on step two finishes',
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
      ),
      seed: () => const NotificationPermissionsState(activeSubstep: 1),
      act: (cubit) => cubit.skipStep(),
      verify: (cubit) {
        expect(cubit.state.canNavigate, isTrue);
        expect(fake.callsTo('requestAuthorization'), isEmpty);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'coming back to the app does not send the user back to step one',
      setUp: () {
        when(() => check(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.denied.toSuccess(),
        );
        fake.answers['authorizationStatus'] = 'notDetermined';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
        checkPermission: check,
      ),
      seed: () => const NotificationPermissionsState(activeSubstep: 1),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) => expect(cubit.state.activeSubstep, 1),
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'coming back mid request leaves the request alone',
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
        checkPermission: check,
      ),
      seed: () => const NotificationPermissionsState(
        step: NotificationPermissionStep.requesting,
      ),
      act: (cubit) => cubit.refresh(),
      expect: () => const <NotificationPermissionsState>[],
    );
  });

  group('unsupported is not a grant', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'an OS with no alarm permission still reports two steps',
      setUp: () {
        fake.answers['requestAuthorization'] = 'unsupported';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
      ),
      act: (cubit) => cubit.requestCriticalAlerts(),
      verify: (cubit) {
        expect(cubit.state.alarmSupported, isFalse);
        expect(cubit.state.totalSteps, 2);
        expect(cubit.state.canNavigate, isTrue);
      },
    );
  });

  group('a granted step is not shown again', () {
    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'everything already granted goes straight through',
      setUp: () {
        when(() => check(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );
        fake.answers['authorizationStatus'] = 'authorized';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
        checkPermission: check,
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.canNavigate, isTrue);
        verifyNever(() => request(any()));
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'notifications granted but not alarms lands on step two',
      setUp: () {
        when(() => check(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );
        fake.answers['authorizationStatus'] = 'notDetermined';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
        checkPermission: check,
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.activeSubstep, 1);
        expect(cubit.state.canNavigate, isFalse);
      },
    );

    blocTest<NotificationPermissionsCubit, NotificationPermissionsState>(
      'the developer replay shows every step anyway',
      setUp: () {
        when(() => check(any())).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );
        fake.answers['authorizationStatus'] = 'authorized';
      },
      build: () => NotificationPermissionsCubit(
        request,
        openSettings,
        alarm: fake.host,
        checkPermission: check,
        replayForDemo: true,
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.activeSubstep, 0);
        expect(cubit.state.canNavigate, isFalse);
      },
    );
  });
}
