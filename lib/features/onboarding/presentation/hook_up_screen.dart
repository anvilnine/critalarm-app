import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/hook_up_waiting_line.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/hook_up_leaving.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/hook_up_steps.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_problem_card.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/tool_snippet.dart';
import 'package:critalarm/features/topics/domain/tool_steps.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_message_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The last step of setup: the curl line for the topic setup made, the row
/// that waits for the first message, and the one analytics switch.
///
/// A tool with documented steps (Uptime Kuma, Healthchecks, Home Assistant)
/// leads with those steps instead, and keeps the curl line one tap away
/// (`HookUpStepsLayout`).
///
/// Done is always there and never waits on anything.
class HookUpScreen extends StatelessWidget {
  const HookUpScreen({super.key});

  /// The query parameters that put a replay on a state. Read in a
  /// developer build only.
  static const replayStateParam = 'show';
  static const replayToolParam = 'tool';

  /// A wire id of the `use` answer the replay should act on.
  static const replayUseParam = 'use';

  static const _arrived = 'arrived';
  static const _criticalOff = 'critical_off';
  static const _criticalOffTimeSensitive = 'critical_off_time_sensitive';
  static const _statsOn = 'stats_on';

  /// Every state a developer build can open a replay on.
  static final List<String> replayStateNames = List.unmodifiable([
    HookUpPhase.ready.name,
    _arrived,
    _criticalOff,
    _criticalOffTimeSensitive,
    _statsOn,
    HookUpPhase.minting.name,
    HookUpPhase.mintFailed.name,
    HookUpPhase.noTopic.name,
    HookUpPhase.noServer.name,
  ]);

  /// Puts the answer the replay shows in memory, before the first frame, so
  /// the screen never draws once for the saved answer.
  static void _pickUse(Uri uri) {
    if (!buildHasOnboardingDeveloperTools) return;
    final use = SetupUse.tryParse(uri.queryParameters[replayUseParam]);
    if (use != null) getIt<SetupUseReplay>().set(use);
  }

  static void _show(HookUpCubit cubit, Uri uri) {
    if (!buildHasOnboardingDeveloperTools) return;
    final template = ToolTemplate.fromId(
      uri.queryParameters[replayToolParam],
    );
    final name = uri.queryParameters[replayStateParam];
    final phase = HookUpPhase.values.where((phase) => phase.name == name);
    cubit.showForReplay(
      phase: phase.isEmpty ? null : phase.first,
      template: template,
      isFirstMessageReceived: name == _arrived ? true : null,
      isCritical: name == _criticalOff || name == _criticalOffTimeSensitive
          ? false
          : null,
      claim: name == _criticalOffTimeSensitive ? RingClaim.timeSensitive : null,
    );
    if (name == _statsOn) unawaited(cubit.setAnalytics(isOn: true));
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final isReplay = isOnboardingReplayUri(uri);
    return BlocProvider(
      create: (_) {
        if (isReplay) _pickUse(uri);
        final cubit = getIt<HookUpCubit>(param1: isReplay);
        unawaited(
          cubit
              .load(tokenName: LocaleKeys.onboarding_hook_up_token_name.tr())
              .then((_) {
                if (!isReplay || cubit.isClosed) return;
                _show(cubit, uri);
              }),
        );
        return cubit;
      },
      child: const _HookUpView(),
    );
  }
}

class _HookUpView extends StatefulWidget {
  const _HookUpView();

  @override
  State<_HookUpView> createState() => _HookUpViewState();
}

class _HookUpViewState extends State<_HookUpView> with WidgetsBindingObserver {
  late final HookUpLeaving _leaving = HookUpLeaving(
    // The flow engine completes setup when no step is left, and that is
    // what forgets the token.
    finishAndGoNext: () =>
        unawaited(finishOnboardingStep(context, OnboardingStepId.hookUp)),
    // Never a replay here: a replay hears no alarm.
    finishStep: () => finishOnboardingStepInEngine(
      OnboardingStepId.hookUp,
      isReplay: false,
    ),
    openAlarm: (incidentId) =>
        _router.go(PushDeepLink.incidentLocation(incidentId)),
    wait: () => Future<void>.delayed(_tickWait),
    isStillHere: () =>
        mounted &&
        _router.routerDelegate.currentConfiguration.uri.path == _path,
    // A replay saves nothing, so it has nothing to take back either.
    forgetFirstTool: () {
      if (isOnboardingReplay(context)) return;
      unawaited(getIt<SetupTestRing>().forgetFirstTool());
    },
  );

  late GoRouter _router;
  late String _path;
  Duration _tickWait = Duration.zero;

  /// The face every setup step shares.
  static const _faceHeroTag = 'onboarding-face';

  /// True for one beat after the first message lands, while the face
  /// realizes it, before it settles.
  bool _isRealizing = false;
  Timer? _realizeTimer;

  /// The message has just landed while the user watched.
  void _onFirstMessage() {
    final beat = context.motion(AppDurations.base);
    if (beat == Duration.zero) return;
    _realizeTimer?.cancel();
    setState(() => _isRealizing = true);
    _realizeTimer = Timer(beat, () {
      if (mounted) setState(() => _isRealizing = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
    _path = GoRouterState.of(context).uri.path;
    _tickWait = context.motion(tickDuration);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _realizeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The watch for the first message runs only while the app is in front.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<HookUpCubit>();
    switch (state) {
      case AppLifecycleState.resumed:
        cubit.appResumed();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        cubit.appPaused();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HookUpCubit, HookUpState>(
      listenWhen: (prev, curr) =>
          (prev.ringingIncidentId != curr.ringingIncidentId &&
              curr.ringingIncidentId != null) ||
          (!prev.isFirstMessageReceived && curr.isFirstMessageReceived),
      listener: (context, state) {
        if (state.isFirstMessageReceived && !_isRealizing) _onFirstMessage();
        if (state.ringingIncidentId case final incidentId?) {
          unawaited(_leaving.alarm(incidentId));
        }
      },
      builder: (context, state) {
        final cubit = context.read<HookUpCubit>();
        // The row has something to wait for once there is a topic. A phone
        // that already has its first message shows it whatever the state.
        final showsRow =
            state.isFirstMessageReceived ||
            (state.topicName != null &&
                // With no token there is no line on screen to send.
                state.phase != HookUpPhase.mintFailed &&
                state.phase != HookUpPhase.noTopic &&
                state.phase != HookUpPhase.noServer);
        // At a large text size a pinned row would take a third of the
        // screen, so it goes into the body, under the line.
        final textScale = setupTextScaleOf(context);
        final pinsRow = setupPinsFirstMessageRow(textScale);
        final waitingLineKey = _stepsWaitingLineKey(context, state);
        // The row that waits for the message. The steps layout has its own
        // card for it, which turns into the same row when the message lands.
        Widget waitingRow({required bool isCompact}) => waitingLineKey == null
            ? FirstMessageRow(
                isReceived: state.isFirstMessageReceived,
                isCompact: isCompact,
              )
            : HookUpWaitingCard(
                isReceived: state.isFirstMessageReceived,
                lineKey: waitingLineKey,
                isCompact: isCompact,
              );
        return AppScreenScaffold(
          backgroundColor: Colors.transparent,
          withGhosts: false,
          // The body scrolls under the top bar and the pinned row and
          // button, so both get a solid backing in the canvas colour.
          barBacking: context.appColors.canvas,
          hasTabBar: false,
          topBar: AppTopBar(
            title: setupTopBarTitle(context),
            leading: context.canPop()
                ? AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.common_back.tr(),
                    onPressed: context.pop,
                  )
                : null,
          ),
          // The bottom block stays put: the row is always in view when the
          // message lands, however far the body is scrolled.
          bottomBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showsRow && pinsRow) ...[
                waitingRow(
                  // Waiting, the row is a face, one line and the empty
                  // tick. The second line is the proof, so it shows once
                  // the message has landed, where there is room for it.
                  isCompact: !state.isFirstMessageReceived || textScale > 1.3,
                ),
                const SizedBox(height: Spacing.s3),
              ],
              AppButton(
                label: LocaleKeys.onboarding_hook_up_done.tr(),
                size: AppButtonSize.lg,
                isFullWidth: true,
                onPressed: _leaving.done,
              ),
            ],
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                Spacing.s4,
                Spacing.s5,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _top(context, state, cubit),
                    if (showsRow && !pinsRow) ...[
                      const SizedBox(height: Spacing.s5),
                      waitingRow(isCompact: !state.isFirstMessageReceived),
                    ],
                    const SizedBox(height: Spacing.s5),
                    // The one ask in setup: a row, no sheet, nothing held.
                    AppToggleRow(
                      title: LocaleKeys.onboarding_hook_up_analytics_title.tr(),
                      subtitle: LocaleKeys.onboarding_hook_up_analytics_line
                          .tr(),
                      value: state.isAnalyticsOn,
                      onChanged: (isOn) =>
                          unawaited(cubit.setAnalytics(isOn: isOn)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _top(BuildContext context, HookUpState state, HookUpCubit cubit) {
    return switch (state.phase) {
      HookUpPhase.finding => _wait(
        LocaleKeys.onboarding_hook_up_finding.tr(),
      ),
      HookUpPhase.minting => _wait(
        LocaleKeys.onboarding_hook_up_minting.tr(),
      ),
      HookUpPhase.mintFailed => _problem(
        context,
        face: FaceState.worried,
        title: LocaleKeys.onboarding_hook_up_mint_failed.tr(),
        line: LocaleKeys.onboarding_hook_up_mint_failed_line.tr(),
        reason: state.mintFailure == null
            ? null
            : failureMessage(state.mintFailure!),
        onTryAgain: () => unawaited(cubit.retryMint()),
      ),
      // Missing, not broken.
      HookUpPhase.noTopic => _problem(
        context,
        face: FaceState.sad,
        title: LocaleKeys.onboarding_hook_up_no_topic.tr(),
        line: LocaleKeys.onboarding_hook_up_no_topic_line.tr(),
      ),
      HookUpPhase.noServer => _problem(
        context,
        face: FaceState.sad,
        title: LocaleKeys.onboarding_hook_up_no_server.tr(),
        line: LocaleKeys.onboarding_hook_up_no_server_line.tr(),
      ),
      HookUpPhase.ready => _ready(context, state),
    };
  }

  /// The answer the screen draws for: the replay's pick in a replay, the
  /// saved one otherwise. Null reads as [SetupUse.other].
  SetupUse? _use(BuildContext context) => setupUseFor(
    isReplay: isOnboardingReplay(context),
    store: getIt<SetupUseStore>(),
    replay: getIt<SetupUseReplay>(),
  );

  /// The `en.json` key of the waiting card's mono line when the steps layout
  /// is on screen, or null when the screen is today's.
  String? _stepsWaitingLineKey(BuildContext context, HookUpState state) {
    if (!_usesSteps(state)) return null;
    return hookUpWaitingLineKey(
      waitingLineFor(use: _use(context), savedTool: state.template),
    );
  }

  /// Whether the tool saved on the topic has steps to lead with, and the
  /// line they sit around is there to show.
  bool _usesSteps(HookUpState state) =>
      state.phase == HookUpPhase.ready &&
      state.hasLine &&
      toolStepsFor(state.template, isCritical: state.isCritical) != null;

  /// A wait: the face, waiting, over the one line that says what for.
  Widget _wait(String message) => Center(
    child: AppWaitingFace(
      message: message,
      faceSize: SetupFace.waitingSizeOf(context),
      heroTag: _faceHeroTag,
    ),
  );

  Widget _face(FaceState face) => Center(child: SetupFace(state: face));

  /// A problem: the face, then one card with what is wrong and, where
  /// there is one, the thing to do about it.
  Widget _problem(
    BuildContext context, {
    required FaceState face,
    required String title,
    required String line,
    String? reason,
    VoidCallback? onTryAgain,
  }) => SetupProblemCard(
    face: face,
    title: title,
    line: line,
    // The server's own reason, unless it only says the title again.
    detail: reason != null && reason != title
        ? AppToast(faceState: FaceState.worried, message: reason)
        : null,
    actionLabel: LocaleKeys.onboarding_hook_up_try_again.tr(),
    onAction: onTryAgain,
  );

  Widget _ready(BuildContext context, HookUpState state) {
    final colors = context.appColors;
    final serverUrl = state.serverUrl ?? '';
    final topic = state.topicName ?? '';
    final token = state.token ?? '';
    final message = LocaleKeys.onboarding_hook_up_sample_message.tr();
    final snippet = ToolSnippet.build(
      template: state.template,
      serverUrl: serverUrl,
      topic: topic,
      token: token,
      message: message,
    );
    final note = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 13,
      height: 1.35,
      color: colors.onCanvasMuted,
    );

    final curl = AppCodeBlock(
      code: CurlLine.build(
        serverUrl: serverUrl,
        topic: topic,
        token: token,
        message: message,
        priority: CurlLine.urgent,
      ),
      isWrapped: true,
      copyLabel: LocaleKeys.onboarding_hook_up_copy_line.tr(),
    );
    // What the user is told about the token and about ringing.
    final notes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.isExample
              ? LocaleKeys.onboarding_hook_up_example.tr()
              : LocaleKeys.create_topic_token_warning.tr(),
          style: note,
        ),
        if (state.isCritical == false) ...[
          const SizedBox(height: Spacing.s2),
          // The words about ringing follow what this phone can do.
          // Same weight as the note above it: it stands out by its
          // ink, not by going bold next to a regular line.
          Text(
            switch (state.claim) {
              RingClaim.alarm =>
                LocaleKeys.onboarding_hook_up_critical_off.tr(),
              RingClaim.timeSensitive =>
                LocaleKeys.onboarding_hook_up_critical_off_time_sensitive.tr(),
            },
            style: note.copyWith(color: colors.onCanvas),
          ),
        ],
      ],
    );

    final steps = toolStepsFor(state.template, isCritical: state.isCritical);
    if (_usesSteps(state) && steps != null && snippet != null) {
      return HookUpStepsLayout(
        template: state.template!,
        steps: steps,
        snippet: snippet,
        serverUrl: serverUrl,
        token: token,
        curl: curl,
        notes: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: notes,
        ),
      );
    }

    // A job runs the line once, at the end of a script or when it fails.
    final isJobs = _use(context) == SetupUse.jobs;
    // The line rings: it carries the priority a critical topic opens an
    // alarm for. It wraps, so the whole of it shows at any text size, and
    // the copy button sits under it.
    final curlBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        curl,
        const SizedBox(height: Spacing.s2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isJobs) ...[
                Text(
                  LocaleKeys.onboarding_hook_up_steps_jobs_note.tr(),
                  style: note,
                ),
                const SizedBox(height: Spacing.s2),
              ],
              notes,
            ],
          ),
        ),
      ],
    );
    final tool = snippet != null && state.template != null
        ? _ToolSection(template: state.template!, snippet: snippet)
        : null;
    // A tool with a form of its own wants its fields, so they come first
    // and the curl line second. Everything else pastes the line.
    final toolFirst = snippet is ToolSnippetFields;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handing over the line. When the message lands the face realizes
        // it for a beat, then settles. The row below does the waiting.
        _face(
          !state.isFirstMessageReceived
              ? FaceState.proud
              : _isRealizing
              ? FaceState.realization
              : FaceState.love,
        ),
        const SizedBox(height: Spacing.s4),
        AppFittedTitle(
          LocaleKeys.onboarding_hook_up_title.tr(),
          minFontSize: setupTitleMinFontSize,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_hook_up_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s5),
        if (tool != null && toolFirst) ...[
          tool,
          const SizedBox(height: Spacing.s5),
        ],
        curlBlock,
        if (tool != null && !toolFirst) ...[
          const SizedBox(height: Spacing.s5),
          tool,
        ],
      ],
    );
  }
}

/// What to give the tool the user picked on the first topic.
class _ToolSection extends StatelessWidget {
  const _ToolSection({required this.template, required this.snippet});

  final ToolTemplate template;
  final ToolSnippet snippet;

  String _instruction(ToolSnippet snippet) => switch (template) {
    ToolTemplate.cron => LocaleKeys.onboarding_hook_up_tool_cron.tr(),
    ToolTemplate.ci => LocaleKeys.onboarding_hook_up_tool_ci.tr(
      args: [if (snippet is ToolSnippetCode) snippet.secretName ?? ''],
    ),
    ToolTemplate.homeAssistant =>
      LocaleKeys.onboarding_hook_up_tool_home_assistant.tr(),
    ToolTemplate.uptimeKuma =>
      LocaleKeys.onboarding_hook_up_tool_uptime_kuma.tr(),
    ToolTemplate.healthchecks =>
      LocaleKeys.onboarding_hook_up_tool_healthchecks.tr(),
    ToolTemplate.curl => '',
    ToolTemplate.other => '',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final snippet = this.snippet;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(
            LocaleKeys.onboarding_hook_up_tool_header.tr(
              args: [template.label ?? ''],
            ),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _instruction(snippet),
              style: AppTypography.small(colors.ink2),
            ),
          ),
          const SizedBox(height: Spacing.s3),
          switch (snippet) {
            ToolSnippetCode(:final code) => AppCodeBlock(
              code: code,
              isWrapped: true,
            ),
            ToolSnippetFields(:final fields) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // One list on the sheet, a hairline between rows. Six
                // stacked tiles read as a settings page.
                for (final (index, field) in fields.indexed) ...[
                  if (index > 0) Divider(height: 1, color: colors.hairline),
                  HookUpToolField(field: field),
                ],
              ],
            ),
          },
        ],
      ),
    );
  }
}
