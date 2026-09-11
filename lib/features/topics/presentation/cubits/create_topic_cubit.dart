import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and topic creation on CreateTopicScreen.
class CreateTopicCubit extends Cubit<CreateTopicState> {
  CreateTopicCubit(this._createTopicUsecase) : super(const CreateTopicState());

  final CreateTopicUsecase _createTopicUsecase;
  static final RegExp _topicRegex = RegExp(r'^[-_A-Za-z0-9]{1,64}$');

  void nameChanged(String name) {
    emit(state.copyWith(name: name, clearError: true));
  }

  void priorityChanged(PriorityLevel priority) {
    emit(
      state.copyWith(
        defaultPriority: priority,
        isCritical: priority == PriorityLevel.critical,
        clearError: true,
      ),
    );
  }

  void criticalToggled({required bool isCritical}) {
    emit(
      state.copyWith(
        isCritical: isCritical,
        defaultPriority: isCritical
            ? PriorityLevel.critical
            : state.defaultPriority,
        clearError: true,
      ),
    );
  }

  Future<void> createTopic() async {
    final trimmedName = state.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: 'Topic name cannot be empty'));
      return;
    }

    if (!_topicRegex.hasMatch(trimmedName)) {
      emit(
        state.copyWith(
          errorMessage:
              'Invalid name. Use 1-64 lowercase, digits, and hyphens.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreateTopicStatus.submitting,
        clearError: true,
      ),
    );

    final result = await _createTopicUsecase(
      CreateTopicParams(
        name: trimmedName,
        critical: state.isCritical,
      ),
    );

    result.fold(
      (topic) {
        emit(
          state.copyWith(
            status: CreateTopicStatus.success,
            createdTopic: topic,
            createdToken: topic.token ?? 'ca_live_${trimmedName}_token',
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: CreateTopicStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }
}
