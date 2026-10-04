import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The last step of setup: the curl line for the topic setup made, a watch
/// for the first message the user's own tool sends, and the one analytics
/// switch.
///
/// Rules it keeps:
///
/// - The token is held in memory, here and in [FirstTopicHandoff], and
///   nowhere else. When it is gone (the app was killed since the topic was
///   made) one new token is made for the topic.
/// - Nothing here waits on the first message. The screen's Done button
///   never asks this cubit whether it may leave.
/// - A replay from Settings shows made-up values and reads, sends, makes
///   and saves nothing.
class HookUpCubit extends Cubit<HookUpState> {
  HookUpCubit({
    required this.handoff,
    required this.templates,
    required this.createToken,
    required this.readTopics,
    required this.refreshTopics,
    required this.readServerUrl,
    required this.watcher,
    required this.consent,
    this.alarmHost,
    this.isReplay = false,
    this.on = const OnboardingPlatform(
      platform: TargetPlatform.android,
      isWeb: false,
    ),
  }) : super(const HookUpState());

  final FirstTopicHandoff handoff;
  final ToolTemplateStore templates;
  final CreateTopicTokenUsecase createToken;

  /// The topics on the server, from the app's shared list.
  final Future<List<Topic>> Function() readTopics;

  /// The same list, fetched again. Asked only when the list does not hold
  /// the topic setup made.
  final Future<List<Topic>> Function() refreshTopics;

  /// The address of the connected server, or null when none is saved.
  final Future<String?> Function() readServerUrl;
  final FirstMessageWatcher watcher;
  final SetupStatsConsent consent;

  /// Null in tests with no platform channel.
  final AlarmHost? alarmHost;

  /// The phone the step runs on, handed in as values.
  final OnboardingPlatform on;
  final bool isReplay;

  /// What a replay shows in place of a real address, topic and token.
  static const exampleServerUrl = 'https://api.critalarm.app';
  static const exampleTopic = 'my-topic';
  static const exampleToken = 'tk_example';

  StreamSubscription<bool>? _arrivals;
  String _tokenName = '';
  bool _isMinting = false;
  bool _isAnswering = false;

  /// Reads what the step needs and shows the line. [tokenName] names the
  /// token made when the first one is gone.
  Future<void> load({required String tokenName}) async {
    _tokenName = tokenName;
    final claim = await _readClaim();
    if (isClosed) return;

    if (isReplay) {
      emit(
        state.copyWith(
          phase: HookUpPhase.ready,
          topicName: exampleTopic,
          serverUrl: exampleServerUrl,
          token: exampleToken,
          isCritical: true,
          claim: claim,
          isExample: true,
        ),
      );
      return;
    }

    final isAnalyticsOn = await consent.isOn();
    if (isClosed) return;
    emit(
      state.copyWith(
        claim: claim,
        isAnalyticsOn: isAnalyticsOn,
        isFirstMessageReceived: watcher.isReceived,
      ),
    );
    _arrivals = watcher.changes.listen((_) {
      if (!isClosed) emit(state.copyWith(isFirstMessageReceived: true));
    });

    final held = handoff.entry;
    if (held != null) {
      // Everything the line needs is in hand, so it shows at once. Whether
      // the topic is critical is read behind it.
      emit(
        state.copyWith(
          phase: HookUpPhase.ready,
          topicName: held.topicName,
          serverUrl: held.serverUrl,
          token: held.token,
          template:
              ToolTemplate.fromId(held.templateId) ??
              templates.read(held.topicName),
        ),
      );
      unawaited(watcher.start(held.topicName));
      final topic = await _findTopic(held.topicName);
      if (isClosed || topic == null) return;
      emit(state.copyWith(isCritical: topic.critical));
      return;
    }

    final serverUrl = await readServerUrl();
    if (isClosed) return;
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      emit(state.copyWith(phase: HookUpPhase.noServer));
      return;
    }
    final topic = await _findTopic(handoff.savedTopicName);
    if (isClosed) return;
    if (topic == null) {
      emit(state.copyWith(phase: HookUpPhase.noTopic, serverUrl: serverUrl));
      return;
    }
    emit(
      state.copyWith(
        topicName: topic.name,
        serverUrl: serverUrl,
        isCritical: topic.critical,
        template: templates.read(topic.name),
      ),
    );
    unawaited(watcher.start(topic.name));
    await _mint();
  }

  Future<RingClaim> _readClaim() async {
    AlarmAuthorization? alarm;
    try {
      alarm = await alarmHost?.authorizationStatus();
    } on Object catch (_) {
      alarm = null;
    }
    return RingClaim.forPhone(
      alarm ?? AlarmAuthorization.unsupported,
      platform: on.platform,
      isWeb: on.isWeb,
    );
  }

  /// The topic setup made: the one called [name], else the first on the
  /// server. Null when the server holds none or cannot be asked.
  Future<Topic?> _findTopic(String? name) async {
    try {
      var topics = await readTopics();
      final isListed = name == null
          ? topics.isNotEmpty
          : topics.any((topic) => topic.name == name);
      if (!isListed) topics = await refreshTopics();
      return setupTestTopic(heldName: name, savedName: name, topics: topics);
    } on Exception {
      return null;
    }
  }

  /// Makes one token for the topic and puts it in the line. A second call
  /// while one is running does nothing.
  Future<void> _mint() async {
    final topicName = state.topicName;
    final serverUrl = state.serverUrl;
    if (isReplay || _isMinting || topicName == null || serverUrl == null) {
      return;
    }
    if (state.token != null) return;
    _isMinting = true;
    try {
      emit(state.copyWith(phase: HookUpPhase.minting, clearMintFailure: true));
      final result = await createToken(
        CreateTopicTokenParams(topicName: topicName, name: _tokenName),
      );
      if (isClosed) return;
      await result.fold(
        (made) async {
          // Held for the rest of this run, so coming back to the step does
          // not make another.
          await handoff.hold(
            FirstTopicHandoffEntry(
              topicName: topicName,
              serverUrl: serverUrl,
              token: made.token,
              templateId: state.template?.id,
            ),
          );
          if (isClosed) return;
          emit(state.copyWith(phase: HookUpPhase.ready, token: made.token));
        },
        (failure) async => emit(
          state.copyWith(phase: HookUpPhase.mintFailed, mintFailure: failure),
        ),
      );
    } finally {
      _isMinting = false;
    }
  }

  /// Try again, after the server would not make the token.
  Future<void> retryMint() async {
    if (state.phase != HookUpPhase.mintFailed) return;
    await _mint();
  }

  /// The user tapped the analytics switch. The switch follows the tap only
  /// once the choice is saved.
  Future<void> setAnalytics({required bool isOn}) async {
    if (isReplay) {
      // A look at the screen: the switch moves and nothing is written.
      emit(state.copyWith(isAnalyticsOn: isOn));
      return;
    }
    if (_isAnswering || state.isAnalyticsOn == isOn) return;
    _isAnswering = true;
    try {
      final isSaved = await consent.answer(isOn: isOn);
      if (isClosed || !isSaved) return;
      emit(state.copyWith(isAnalyticsOn: isOn));
    } finally {
      _isAnswering = false;
    }
  }

  /// The app left the front: the watch for the first message stops.
  void appPaused() {
    if (!isReplay) watcher.pause();
  }

  /// The app is back at the front: the watch asks at once.
  void appResumed() {
    if (!isReplay) watcher.resume();
  }

  /// Puts a replay on a state, so a developer can look at it without
  /// making it happen. Does nothing outside a replay.
  void showForReplay({
    HookUpPhase? phase,
    ToolTemplate? template,
    bool? isCritical,
    bool? isFirstMessageReceived,
    RingClaim? claim,
  }) {
    if (!isReplay) return;
    emit(
      state.copyWith(
        phase: phase,
        template: template,
        isCritical: isCritical,
        isFirstMessageReceived: isFirstMessageReceived,
        claim: claim,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _arrivals?.cancel();
    await watcher.dispose();
    return super.close();
  }
}
