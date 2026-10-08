import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/first_topic_rules.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/topic_name_rule.dart';
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
    PlanChanges? planChanges,
    this._featureAccess,
  ]) : _planChanges = planChanges ?? appPlanChanges,
       super(const CreateTopicState()) {
    _planChanges.addListener(_onPlanChanged);
    _accessSub = _featureAccess?.changes
        .where((feature) => feature == AppFeature.unlimitedCriticalTopics)
        .listen((_) => _onPlanChanged());
  }

  final CreateTopicUsecase _createTopicUsecase;

  /// Asked once on load whether this phone can set an alarm, so the words
  /// under the critical switch match what the phone will do. Null in tests.
  AlarmHost? alarm;

  /// Where the picked tool chip is kept once the topic exists. Null in tests
  /// that do not need it.
  ToolTemplateStore? toolTemplates;

  /// Holds the new topic for the steps after this one in setup. Null in tests
  /// that do not need it.
  FirstTopicHandoff? handoff;

  /// True when this screen is a setup step, so the new topic is handed on to
  /// the next steps. Everywhere else the token is shown once and forgotten.
  bool holdsHandoff = false;

  /// True in setup, where the screen is one step: the topic is created from
  /// the first step and its token is named for the user. Everywhere else
  /// the token-name step comes first.
  bool isOneStep = false;

  /// Reads the server this app is connected to. Optional so a test can build
  /// the cubit without one.
  final GetConnectionUsecase? _getConnection;
  final DeviceIdentityStore? _identityStore;
  final GetTopicsUsecase? _getTopics;

  /// Says whether this phone is past the cap on critical topics: Hosted, or
  /// a server of the user's own, which has no cap. Null in tests that do
  /// not care, and then the cap applies.
  final FeatureAccess? _featureAccess;
  StreamSubscription<AppFeature>? _accessSub;

  /// Moves when a registration brings new caps, so the count under the
  /// Critical switch follows.
  final PlanChanges _planChanges;

  /// Whether the cap on critical topics applies here. Waits for the plan
  /// to be read, so a paying person never sees the free count first.
  Future<bool> _isCapped() async =>
      !(await _featureAccess?.canOnceReady(
            AppFeature.unlimitedCriticalTopics,
          ) ??
          false);

  /// Reads the plan again and redraws the free-tier parts of the screen.
  void _onPlanChanged() {
    if (isClosed) return;
    unawaited(_reloadPlan());
  }

  Future<void> _reloadPlan() async {
    final identityStore = _identityStore;
    if (identityStore == null) return;
    final identity = await identityStore.readOrCreate();
    final isCapped = await _isCapped();
    if (isClosed) return;
    emit(
      state.copyWith(
        isFreeTier: isCapped,
        criticalLimit: AccountAccess(identity).caps?.criticalTopics,
      ),
    );
  }

  @override
  Future<void> close() {
    _planChanges.removeListener(_onPlanChanged);
    unawaited(_accessSub?.cancel());
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
        // Shown at once. The reads below go to the network, and a quick
        // Create must not hand an empty address on to the next steps.
        emit(state.copyWith(serverUrl: serverUrl));
      }
    }

    var isFreeTier = state.isFreeTier;
    var limit = state.criticalLimit;
    var used = state.criticalUsed;

    final identityStore = _identityStore;
    if (identityStore != null) {
      final identity = await identityStore.readOrCreate();
      final access = AccountAccess(identity);
      // Matches the Settings screen: a self-hosted server has no tier, so
      // it is never treated as the free plan.
      isFreeTier = await _isCapped();
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

  void nameChanged(String name) {
    emit(state.copyWith(name: name, clearError: true));
  }

  void tokenNameChanged(String name) {
    emit(state.copyWith(tokenName: name, clearError: true));
  }

  /// Feeds in the names of the topics the app already holds, so a name that is
  /// taken is caught on step 1 as the user types. The screen passes these from
  /// the shared topic list, so nothing here asks the server again.
  ///
  /// [isListReady] says the shared list has loaded. Leave it out to keep what
  /// was last said. The first-topic card waits on it, because an empty list
  /// that is still loading is not a user with no topics.
  void existingNamesChanged(Iterable<String> names, {bool? isListReady}) {
    final lowered = names.map((name) => name.trim().toLowerCase()).toSet();
    if (setEquals(lowered, state.existingNames) &&
        (isListReady == null || isListReady == state.isListReady)) {
      return;
    }
    emit(state.copyWith(existingNames: lowered, isListReady: isListReady));
  }

  /// A tap on a tool chip. Picks it, and fills the name field only when the
  /// field is empty or still holds a name a chip put there. A second tap on
  /// the picked chip clears the pick and leaves the name. Never touches
  /// [CreateTopicState.isCritical].
  void toolTemplateTapped(ToolTemplate tapped) {
    final result = tapToolTemplate(
      current: state.toolPick,
      currentName: state.name,
      tapped: tapped,
    );
    emit(
      state.copyWith(
        toolPick: result.pick,
        name: result.name,
        clearError: true,
      ),
    );
  }

  /// Why this topic name cannot be used, or null when it can.
  String? _nameError(String trimmedName) {
    if (trimmedName.isEmpty) {
      return LocaleKeys.create_topic_name_error_empty.tr();
    }
    if (!isValidTopicName(trimmedName)) {
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

  /// What the phone keeps about a topic the server just made: the tool chip,
  /// and in setup the hand-off to the next steps. A preference that fails to
  /// write never turns a created topic into an error.
  Future<void> _rememberTopic(Topic topic) async {
    final template = state.selectedTool;
    try {
      if (template != null) await toolTemplates?.save(topic.name, template);
      final token = topic.token;
      if (holdsHandoff && token != null) {
        await handoff?.hold(
          FirstTopicHandoffEntry(
            topicName: topic.name,
            serverUrl: await _serverUrlToHandOn(),
            token: token,
            templateId: template?.id,
          ),
        );
        // Setup never shows this token on this screen. Should the app be
        // killed before the last step shows it, that step makes another,
        // and takes this one back first: its id is saved for that. A token
        // nobody ever saw must not stay valid.
        final tokenId = topic.tokenId;
        if (tokenId != null && tokenId.isNotEmpty) {
          await handoff?.saveMintedTokenId(tokenId);
        }
      }
    } on Object catch (error) {
      debugPrint(
        'CreateTopicCubit: remembering the topic failed: ${error.runtimeType}',
      );
    }
  }

  /// The server address for the steps after this one: what the screen
  /// loaded, or the saved connection's when the load has not got there yet.
  Future<String> _serverUrlToHandOn() async {
    if (state.serverUrl.trim().isNotEmpty) return state.serverUrl;
    final saved = await _getConnection?.call(const NoParams());
    return saved?.getOrNull()?.serverUrl ?? state.serverUrl;
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

    // The two-step screen catches a taken name on the way to step 2. The
    // one-step screen has no such stop, so it is caught here.
    if (state.isDuplicateName) {
      emit(
        state.copyWith(
          step: CreateTopicStep.topic,
          errorMessage: LocaleKeys.api_errors_topic_already_exists.tr(),
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
        // The one-step screen never asks, and names it after the tool.
        tokenName: trimmedTokenName.isNotEmpty
            ? trimmedTokenName
            : isOneStep
            ? setupTokenName(state.selectedTool)
            : null,
      ),
    );

    final created = result.getOrNull();
    if (created != null) await _rememberTopic(created);
    if (isClosed) return;

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
            isProPending:
                _featureAccess?.decide(AppFeature.unlimitedCriticalTopics)
                    is FeatureConfirming,
          ),
        );
      },
    );
  }
}
