import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_state.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Permissions onboarding screen and test alarm triggering.
class OnboardingPermissionsCubit extends Cubit<OnboardingPermissionsState> {
  OnboardingPermissionsCubit(this._triggerTestAlarm, {this.getTopics})
    : super(const OnboardingPermissionsState());

  final TriggerTestAlarmUsecase _triggerTestAlarm;
  final GetTopicsUsecase? getTopics;

  Future<void> loadTestTopic() async {
    final result = await getTopics?.call(const NoParams());
    final topics = result?.getOrNull() ?? [];
    emit(
      state.copyWith(
        topic: topics.where((t) => t.critical).firstOrNull?.name ?? '',
        errorMessage: result?.exceptionOrNull()?.message,
      ),
    );
  }

  Future<void> ringTestAlarm({String? topic}) async {
    if (getTopics != null) await loadTestTopic();
    final targetTopic = getTopics == null
        ? (topic ?? state.topic)
        : state.topic;
    if (targetTopic.isEmpty) {
      emit(
        state.copyWith(
          status: OnboardingPermissionsStatus.failure,
          errorMessage:
              'Create a topic and enable critical delivery '
              'before testing an alarm.',
        ),
      );
      return;
    }
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
