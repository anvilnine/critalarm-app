import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
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
///   made) one new token is made for the topic, after the one an earlier
///   launch made is taken back.
/// - Nothing here waits on the first message. The screen's Done button
///   never asks this cubit whether it may leave.
/// - The curl line rings a critical topic. When that alarm reaches the
///   phone the row turns at once, without waiting for a poll, and the state
///   names the incident so the screen can hand over to the alarm.
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
    required this.revokeToken,
    required this.ring,
    this.isSetupComplete,
    this.alarmArrivals,
    this.readIncidentTopic,
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

  final RevokeTopicTokenUsecase revokeToken;

  /// Setup's own incidents: its tests, and the alarm of the first message.
  final SetupTestRing ring;

  /// Whether setup is already over. This step does nothing for a user who
  /// finished it. Null in tests that do not care, and counts as not over.
  final Future<bool> Function()? isSetupComplete;

  /// The incident of every alarm that reaches this phone while the app
  /// runs. Null in tests that do not need it.
  final Stream<String>? alarmArrivals;

  /// The topic an incident is on, or null when it cannot be read. An alarm
  /// only counts as the first message when it is on the topic of this
  /// step.
  final Future<String?> Function(String incidentId)? readIncidentTopic;

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
  StreamSubscription<String>? _alarms;
  String _tokenName = '';
  bool _isMinting = false;
  bool _isAnswering = false;

  /// Reads what the step needs and shows the line. [tokenName] names the
  /// token made when the first one is gone.
  Future<void> load({required String tokenName}) async {
    _tokenName = tokenName;

    if (isReplay) {
      emit(
        state.copyWith(
          phase: HookUpPhase.ready,
          topicName: exampleTopic,
          serverUrl: exampleServerUrl,
          token: exampleToken,
          isCritical: true,
          isExample: true,
        ),
      );
      final claim = await _readClaim();
      if (!isClosed) emit(state.copyWith(claim: claim));
      return;
    }

    // Setup is over: nothing is read, made, watched or saved.
    if (await isSetupComplete?.call() ?? false) {
      if (!isClosed) emit(state.copyWith(phase: HookUpPhase.noTopic));
      return;
    }
    if (isClosed) return;

    // With the topic setup made still in hand, the line shows in the first
    // frame. Everything else is read behind it.
    var held = handoff.entry;
    // An entry handed on without its address is completed from the saved
    // connection, never shown as it is: the line would have no host.
    if (held != null && held.serverUrl.trim().isEmpty) {
      final saved = await readServerUrl();
      if (isClosed) return;
      held = saved == null || saved.trim().isEmpty
          ? null
          : FirstTopicHandoffEntry(
              topicName: held.topicName,
              serverUrl: saved,
              token: held.token,
              templateId: held.templateId,
            );
      if (held != null) await handoff.hold(held);
      if (isClosed) return;
    }
    emit(
      state.copyWith(
        phase: held == null ? null : HookUpPhase.ready,
        topicName: held?.topicName,
        serverUrl: held?.serverUrl,
        token: held?.token,
        template: held == null
            ? null
            : ToolTemplate.fromId(held.templateId) ??
                  templates.read(held.topicName),
        isFirstMessageReceived: watcher.isReceived,
      ),
    );
    _arrivals = watcher.changes.listen((_) {
      if (!isClosed) emit(state.copyWith(isFirstMessageReceived: true));
    });
    _alarms = alarmArrivals?.listen(_onAlarm);
    if (held != null) unawaited(watcher.start(held.topicName));

    final claim = await _readClaim();
    final isAnalyticsOn = await consent.isOn();
    if (isClosed) return;
    emit(state.copyWith(claim: claim, isAnalyticsOn: isAnalyticsOn));

    if (held != null) {
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
    // Only the topic setup made. With no name on record there is nothing
    // to guess from: another topic on the account is not this step's.
    final savedName = handoff.savedTopicName;
    final topic = savedName == null ? null : await _findTopic(savedName);
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

  /// An alarm reached the phone. It is the first message only when it is
  /// on this step's topic and is not one of setup's own tests: an alarm
  /// from another topic, a test ringing late and the test of this phone
  /// only all leave the row alone.
  Future<void> _onAlarm(String incidentId) async {
    if (isClosed || state.ringingIncidentId != null) return;
    if (incidentId == phoneOnlyTestIncidentId) return;
    if (ring.incidentIds.contains(incidentId) ||
        ring.unclosedIds.contains(incidentId) ||
        ring.setupIncidentIds.contains(incidentId)) {
      return;
    }
    final topicName = state.topicName;
    if (topicName == null) return;
    String? alarmTopic;
    try {
      alarmTopic = await readIncidentTopic?.call(incidentId);
    } on Exception {
      alarmTopic = null;
    }
    if (isClosed || alarmTopic != topicName) return;
    if (state.ringingIncidentId != null) return;
    // Setup asked for this message, so its alarm is not real use.
    await ring.holdFirstMessage(incidentId);
    await watcher.arrived();
    if (isClosed) return;
    emit(
      state.copyWith(
        isFirstMessageReceived: true,
        ringingIncidentId: incidentId,
      ),
    );
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

  /// The topic called [name], or null when the server does not hold it or
  /// cannot be asked.
  Future<Topic?> _findTopic(String name) async {
    try {
      var topics = await readTopics();
      if (!topics.any((topic) => topic.name == name)) {
        topics = await refreshTopics();
      }
      for (final topic in topics) {
        if (topic.name == name) return topic;
      }
      return null;
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
      // A token this step made on an earlier launch is taken back first,
      // so relaunching never piles up valid tokens nobody can see.
      final earlier = handoff.mintedTokenId;
      if (earlier != null) {
        final revoked = await revokeToken(
          RevokeTopicTokenParams(topicName: topicName, tokenId: earlier),
        );
        if (isClosed) return;
        final failure = revoked.exceptionOrNull();
        if (failure != null && !_isGone(failure)) {
          emit(
            state.copyWith(
              phase: HookUpPhase.mintFailed,
              mintFailure: failure,
            ),
          );
          return;
        }
      }
      final result = await createToken(
        CreateTopicTokenParams(topicName: topicName, name: _tokenName),
      );
      if (isClosed) return;
      await result.fold(
        (made) async {
          // The id is saved, never the secret.
          await handoff.saveMintedTokenId(made.tokenId);
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

  /// The token to take back is already gone from the server.
  static bool _isGone(Failure failure) =>
      failure is NotFoundFailure ||
      (failure is ApiFailure && failure.statusCode == 404);

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
    await _alarms?.cancel();
    await watcher.dispose();
    return super.close();
  }
}
