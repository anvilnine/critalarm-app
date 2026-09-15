import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and topic creation on CreateTopicScreen.
class CreateTopicCubit extends Cubit<CreateTopicState> {
  CreateTopicCubit(this._createTopicUsecase, [this._getConnection])
    : super(const CreateTopicState());

  final CreateTopicUsecase _createTopicUsecase;

  /// Reads the server this app is connected to. Optional so a test can build
  /// the cubit without one.
  final GetConnectionUsecase? _getConnection;

  /// Fills in the base URL so the result card can show the whole endpoint.
  Future<void> loadConnection() async {
    final usecase = _getConnection;
    if (usecase == null) return;
    final result = await usecase(const NoParams());
    final conn = result.getOrNull();
    if (conn == null) return;
    emit(state.copyWith(serverUrl: conn.serverUrl));
  }
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
