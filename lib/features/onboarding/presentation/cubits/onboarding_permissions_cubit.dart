import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Permissions onboarding screen and test alarm triggering.
class OnboardingPermissionsCubit extends Cubit<OnboardingPermissionsState> {
  OnboardingPermissionsCubit(this._triggerTestAlarm)
    : super(const OnboardingPermissionsState());

  final TriggerTestAlarmUsecase _triggerTestAlarm;

  Future<void> ringTestAlarm({String? topic}) async {
    final targetTopic = topic ?? state.topic;
    emit(
      state.copyWith(
        status: OnboardingPermissionsStatus.ringing,
        topic: targetTopic,
        clearError: true,
      ),
    );

    final result = await _triggerTestAlarm(targetTopic);
    result.fold(
      (incidentId) {
        emit(
          state.copyWith(
            status: OnboardingPermissionsStatus.success,
            incidentId: incidentId,
            clearError: true,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: OnboardingPermissionsStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  void reset() {
    emit(const OnboardingPermissionsState());
  }
}
