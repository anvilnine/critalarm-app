import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and topic creation on CreateTopicScreen.
class CreateTopicCubit extends Cubit<CreateTopicState> {
  CreateTopicCubit(this._createTopicUsecase) : super(const CreateTopicState());

  final CreateTopicUsecase _createTopicUsecase;
  static final RegExp _topicRegex = RegExp(r'^[-_A-Za-z0-9]{1,64}$');

  void nameChanged(String name) {
    emit(state.copyWith(name: name, clearError: true));
  }

  void criticalToggled({required bool isCritical}) {
    emit(
      state.copyWith(
        isCritical: isCritical,
        clearError: true,
      ),
    );
  }

  Future<void> createTopic() async {
    if (state.status == CreateTopicStatus.success ||
        state.status == CreateTopicStatus.submitting) {
      return;
    }
    final trimmedName = state.name.trim();
    if (trimmedName.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.create_topic_name_error_empty.tr(),
        ),
      );
      return;
    }

    if (!_topicRegex.hasMatch(trimmedName)) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.create_topic_name_error_invalid.tr(),
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
            createdToken: topic.token,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: CreateTopicStatus.failure,
            errorMessage: failure.message,
            capReached: CapReached.fromFailure(failure),
          ),
        );
      },
    );
  }
}
