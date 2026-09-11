import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTriggerTestAlarmUsecase extends Mock
    implements TriggerTestAlarmUsecase {}

void main() {
  late MockTriggerTestAlarmUsecase mockTriggerTestAlarm;

  setUp(() {
    mockTriggerTestAlarm = MockTriggerTestAlarmUsecase();
  });

  group('OnboardingPermissionsCubit', () {
    test('initial state has default topic prod-db and initial status',
        () async {
      final cubit = OnboardingPermissionsCubit(mockTriggerTestAlarm);
      expect(cubit.state.status, OnboardingPermissionsStatus.initial);
      expect(cubit.state.topic, 'prod-db');
      expect(cubit.state.incidentId, isNull);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    blocTest<OnboardingPermissionsCubit, OnboardingPermissionsState>(
      'ringTestAlarm succeeds and emits ringing then success with '
      'incidentId',
      setUp: () {
        when(() => mockTriggerTestAlarm('prod-db'))
            .thenAnswer((_) async => 'inc_12345'.toSuccess());
      },
      build: () => OnboardingPermissionsCubit(mockTriggerTestAlarm),
      act: (cubit) => cubit.ringTestAlarm(),
      expect: () => [
        const OnboardingPermissionsState(
          status: OnboardingPermissionsStatus.ringing,
        ),
        const OnboardingPermissionsState(
          status: OnboardingPermissionsStatus.success,
          incidentId: 'inc_12345',
        ),
      ],
    );

    blocTest<OnboardingPermissionsCubit, OnboardingPermissionsState>(
      'ringTestAlarm fails and emits ringing then failure with error '
      'message',
      setUp: () {
        when(() => mockTriggerTestAlarm('prod-db')).thenAnswer(
          (_) async => const Failure.api(
            statusCode: 409,
            message: 'topic is not critical',
          ).toFailure(),
        );
      },
      build: () => OnboardingPermissionsCubit(mockTriggerTestAlarm),
      act: (cubit) => cubit.ringTestAlarm(),
      expect: () => [
        const OnboardingPermissionsState(
          status: OnboardingPermissionsStatus.ringing,
        ),
        const OnboardingPermissionsState(
          status: OnboardingPermissionsStatus.failure,
          errorMessage: 'topic is not critical',
        ),
      ],
    );

    blocTest<OnboardingPermissionsCubit, OnboardingPermissionsState>(
      'reset returns state to initial',
      build: () => OnboardingPermissionsCubit(mockTriggerTestAlarm),
      seed: () => const OnboardingPermissionsState(
        status: OnboardingPermissionsStatus.success,
        incidentId: 'inc_abc',
      ),
      act: (cubit) => cubit.reset(),
      expect: () => [
        const OnboardingPermissionsState(),
      ],
    );
  });
}
