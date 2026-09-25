import 'dart:async';

import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and topic creation on CreateTopicScreen.
class CreateTopicCubit extends Cubit<CreateTopicState> {
  CreateTopicCubit(
    this._createTopicUsecase, [
    this._getConnection,
    this._identityStore,
    this._getTopics,
    this._proOverride,
    PlanChanges? planChanges,
  ]) : _planChanges = planChanges ?? appPlanChanges,
       super(const CreateTopicState()) {
    _planChanges.addListener(_onPlanChanged);
  }

  final CreateTopicUsecase _createTopicUsecase;

  /// Asked once on load whether this phone can set an alarm, so the words
  /// under the critical switch match what the phone will do. Null in tests.
  AlarmHost? alarm;

  /// Says whether the server is self-hosted. A self-hosted server has no
  /// tier, so it is never the free tier. Null in tests, and then the server
  /// is treated as not self-hosted.
  ApiSessionStore? sessionStore;

  /// Reads the server this app is connected to. Optional so a test can build
  /// the cubit without one.
  final GetConnectionUsecase? _getConnection;
  final DeviceIdentityStore? _identityStore;
  final GetTopicsUsecase? _getTopics;
  final ProOverride? _proOverride;

  /// Moves when a purchase lands, so the free-tier banner and the Go Pro
  /// button go away right after buying.
  final PlanChanges _planChanges;

  /// The last identity read, kept so a cap refusal can tell "Pro is still
  /// turning on" from "you are on the free plan".
  DeviceIdentity? _identity;

  AccountAccess _access(DeviceIdentity? identity) => AccountAccess(
    identity,
    proOverride: _proOverride,
    planChanges: _planChanges,
  );

  /// Reads the plan again and redraws the free-tier parts of the screen.
  void _onPlanChanged() {
    if (isClosed) return;
    unawaited(_reloadPlan());
  }

  Future<void> _reloadPlan() async {
    final identityStore = _identityStore;
    if (identityStore == null) return;
    final identity = await identityStore.readOrCreate();
    final isSelfHosted = await _isSelfHosted();
    if (isClosed) return;
    _identity = identity;
    final access = _access(identity);
    emit(
      state.copyWith(
        isFreeTier: !access.isPaid && !isSelfHosted,
        criticalLimit: access.caps?.criticalTopics,
      ),
    );
  }

  Future<bool> _isSelfHosted() async =>
      (await sessionStore?.read())?.mode == ServerMode.selfhosted;

  @override
  Future<void> close() {
    _planChanges.removeListener(_onPlanChanged);
    return super.close();
  }

  /// Fills in the base URL and checks account limits so the screen can display
  /// remaining free-tier critical allowance.
  Future<void> loadConnection() async {
    final authorization = await alarm?.authorizationStatus();
    if (authorization != null) {
      emit(state.copyWith(alarm: authorization));
    }

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
      _identity = identity;
      final access = _access(identity);
      // Matches the Settings screen: a self-hosted server has no tier, so
      // it is never treated as the free plan.
      isFreeTier = !access.isPaid && !await _isSelfHosted();
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

  void tokenNameChanged(String name) {
    emit(state.copyWith(tokenName: name, clearError: true));
  }

  /// Feeds in the names of the topics the app already holds, so a name that is
  /// taken is caught on step 1 as the user types. The screen passes these from
  /// the shared topic list, so nothing here asks the server again.
  void existingNamesChanged(Iterable<String> names) {
    final lowered = names.map((name) => name.trim().toLowerCase()).toSet();
    if (setEquals(lowered, state.existingNames)) return;
    emit(state.copyWith(existingNames: lowered));
  }

  /// Why this topic name cannot be used, or null when it can.
  String? _nameError(String trimmedName) {
    if (trimmedName.isEmpty) {
      return LocaleKeys.create_topic_name_error_empty.tr();
    }
    if (!_topicRegex.hasMatch(trimmedName)) {
      return LocaleKeys.create_topic_name_error_invalid.tr();
    }
    return null;
  }

  /// Step 1 to step 2. Nothing reaches the server here: the topic and its
  /// first token are made together when step 2 submits, so backing out of
  /// step 2 leaves nothing behind.
  void nextStep() {
    final error = _nameError(state.name.trim());
    if (error != null) {
      emit(state.copyWith(errorMessage: error));
      return;
    }
    if (state.isDuplicateName) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.api_errors_topic_already_exists.tr(),
        ),
      );
      return;
    }
    emit(state.copyWith(step: CreateTopicStep.token, clearError: true));
  }

  /// Step 2 back to step 1. The topic name stays where it was typed.
  void previousStep() {
    emit(state.copyWith(step: CreateTopicStep.topic, clearError: true));
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
    final nameError = _nameError(trimmedName);
    if (nameError != null) {
      emit(
        state.copyWith(
          step: CreateTopicStep.topic,
          errorMessage: nameError,
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

    final trimmedTokenName = state.tokenName.trim();
    final result = await _createTopicUsecase(
      CreateTopicParams(
        name: trimmedName,
        critical: state.isCritical,
        // Left off when it is blank, so the server falls back to `Token 1`.
        tokenName: trimmedTokenName.isEmpty ? null : trimmedTokenName,
      ),
    );

    result.fold(
      (topic) {
        emit(
          state.copyWith(
            status: CreateTopicStatus.success,
            createdTopic: topic,
            createdToken: topic.token,
            // The count was read when the screen opened, so it is one behind
            // the moment a critical topic is made. Move it on, or anything
            // reading it right after a create reads a stale number.
            criticalUsed: topic.critical
                ? state.criticalUsed + 1
                : state.criticalUsed,
          ),
        );
      },
      (failure) {
        final cap = CapReached.fromFailure(failure);
        emit(
          state.copyWith(
            status: CreateTopicStatus.failure,
            // Every error a create can raise is about the topic, never the
            // token, so send the user back to step 1 where the topic name
            // field is. The typed token name is kept.
            step: CreateTopicStep.topic,
            // failure.message is the server's wire code, e.g. "cap". Never
            // put that under a text field.
            errorMessage: apiErrorMessage(failure.message, cap: cap?.name),
            capReached: cap,
            // The store says Pro but the server has not caught up, so a cap
            // here means "wait a moment", not "go Pro".
            isProPending: _access(_identity).isProPending,
          ),
        );
      },
    );
  }
}
