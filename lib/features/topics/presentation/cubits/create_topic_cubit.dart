import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and topic creation on CreateTopicScreen.
class CreateTopicCubit extends Cubit<CreateTopicState> {
  CreateTopicCubit(
    this._createTopicUsecase, [
    this._getConnection,
    this._identityStore,
    this._getTopics,
    this._proOverride,
  ]) : super(const CreateTopicState());

  final CreateTopicUsecase _createTopicUsecase;

  /// Reads the server this app is connected to. Optional so a test can build
  /// the cubit without one.
  final GetConnectionUsecase? _getConnection;
  final DeviceIdentityStore? _identityStore;
  final GetTopicsUsecase? _getTopics;
  final ProOverride? _proOverride;

  /// Fills in the base URL and checks account limits so the screen can display
  /// remaining free-tier critical allowance.
  Future<void> loadConnection() async {
    String? serverUrl;
    final getConnection = _getConnection;
    if (getConnection != null) {
      final result = await getConnection(const NoParams());
      final conn = result.getOrNull();
      if (conn != null) {
        serverUrl = conn.serverUrl;
      }
    }

    var isFreeTier = state.isFreeTier;
    var limit = state.criticalLimit;
    var used = state.criticalUsed;

    final identityStore = _identityStore;
    if (identityStore != null) {
      final identity = await identityStore.readOrCreate();
      final access = AccountAccess(identity, proOverride: _proOverride);
      isFreeTier = !access.isPaid;
      limit = access.caps?.criticalTopics;
      final getTopics = _getTopics;
      if (getTopics != null) {
        final topicsResult = await getTopics(const NoParams());
        final topics = topicsResult.getOrNull() ?? [];
        used = access.criticalCount(topics);
      }
    }

    emit(
      state.copyWith(
        serverUrl: serverUrl ?? state.serverUrl,
        isFreeTier: isFreeTier,
        criticalLimit: limit,
        criticalUsed: used,
      ),
    );
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
        final cap = CapReached.fromFailure(failure);
        emit(
          state.copyWith(
            status: CreateTopicStatus.failure,
            // failure.message is the server's wire code, e.g. "cap". Never
            // put that under a text field.
            errorMessage: apiErrorMessage(failure.message, cap: cap?.name),
            capReached: cap,
          ),
        );
      },
    );
  }
}
