import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/tool_snippet.dart';
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
/// Done is always there and never waits on anything.
class HookUpScreen extends StatelessWidget {
  const HookUpScreen({super.key});

  /// The query parameters that put a replay on a state. Read in a
  /// developer build only.
  static const replayStateParam = 'show';
  static const replayToolParam = 'tool';

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
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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

  /// Done. The flow engine completes setup when no step is left, and that
  /// is what forgets the token.
  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    unawaited(finishOnboardingStep(context, OnboardingStepId.hookUp));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HookUpCubit, HookUpState>(
      builder: (context, state) {
        final cubit = context.read<HookUpCubit>();
        // The row has something to wait for once there is a topic. A phone
        // that already has its first message shows it whatever the state.
        final showsRow =
            state.isFirstMessageReceived ||
            (state.topicName != null &&
                state.phase != HookUpPhase.noTopic &&
                state.phase != HookUpPhase.noServer);
        return AppScreenScaffold(
          backgroundColor: Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.app_title.tr(),
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
              if (showsRow) ...[
                FirstMessageRow(isReceived: state.isFirstMessageReceived),
                const SizedBox(height: Spacing.s3),
              ],
              AppButton(
                label: LocaleKeys.onboarding_hook_up_done.tr(),
                size: AppButtonSize.lg,
                isFullWidth: true,
                onPressed: _finish,
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
        title: LocaleKeys.onboarding_hook_up_mint_failed.tr(),
        line: LocaleKeys.onboarding_hook_up_mint_failed_line.tr(),
        reason: state.mintFailure == null
            ? null
            : failureMessage(state.mintFailure!),
        onTryAgain: () => unawaited(cubit.retryMint()),
      ),
      HookUpPhase.noTopic => _problem(
        context,
        title: LocaleKeys.onboarding_hook_up_no_topic.tr(),
        line: LocaleKeys.onboarding_hook_up_no_topic_line.tr(),
      ),
      HookUpPhase.noServer => _problem(
        context,
        title: LocaleKeys.onboarding_hook_up_no_server.tr(),
        line: LocaleKeys.onboarding_hook_up_no_server_line.tr(),
      ),
      HookUpPhase.ready => _ready(context, state),
    };
  }

  /// A wait: the face, waiting, over the one line that says what for.
  Widget _wait(String message) => Padding(
    padding: const EdgeInsets.only(top: Spacing.s6),
    child: Center(
      child: AppWaitingFace(message: message, heroTag: 'onboarding-face'),
    ),
  );

  Widget _face(FaceState face) => Center(
    child: Hero(
      tag: 'onboarding-face',
      flightShuttleBuilder: faceFlightShuttleBuilder,
      child: FaceWidget(state: face, size: 72, isLive: true),
    ),
  );

  Widget _problem(
    BuildContext context, {
    required String title,
    required String line,
    String? reason,
    VoidCallback? onTryAgain,
  }) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _face(FaceState.worried),
        const SizedBox(height: Spacing.s4),
        Semantics(
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headline(colors.onCanvas, fontSize: 22),
          ),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          line,
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        if (reason != null) ...[
          const SizedBox(height: Spacing.s4),
          AppToast(faceState: FaceState.worried, message: reason),
        ],
        if (onTryAgain != null) ...[
          const SizedBox(height: Spacing.s4),
          AppButton(
            label: LocaleKeys.onboarding_hook_up_try_again.tr(),
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            onPressed: onTryAgain,
          ),
        ],
      ],
    );
  }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _face(
          state.isFirstMessageReceived ? FaceState.calm : FaceState.watching,
        ),
        const SizedBox(height: Spacing.s3),
        Text(
          LocaleKeys.onboarding_hook_up_title.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_hook_up_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s5),
        // The line rings: it carries the priority a critical topic opens
        // an alarm for. It wraps, so the whole of it shows at any text
        // size, and the copy button sits under it.
        AppCodeBlock(
          code: CurlLine.build(
            serverUrl: serverUrl,
            topic: topic,
            token: token,
            message: message,
            priority: CurlLine.urgent,
          ),
          isWrapped: true,
          copyLabel: LocaleKeys.onboarding_hook_up_copy_line.tr(),
        ),
        const SizedBox(height: Spacing.s2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
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
                const SizedBox(height: Spacing.s1),
                // The words about ringing follow what this phone can do.
                Text(
                  switch (state.claim) {
                    RingClaim.alarm =>
                      LocaleKeys.onboarding_hook_up_critical_off.tr(),
                    RingClaim.timeSensitive =>
                      LocaleKeys.onboarding_hook_up_critical_off_time_sensitive
                          .tr(),
                  },
                  style: note.copyWith(
                    color: colors.onCanvas,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (snippet != null && state.template != null) ...[
          const SizedBox(height: Spacing.s5),
          _ToolSection(template: state.template!, snippet: snippet),
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
                for (final (index, field) in fields.indexed) ...[
                  if (index > 0) const SizedBox(height: 6),
                  AppKeyValueRow(
                    label: field.label,
                    value: field.value,
                    showCopyButton: field.isCopyable,
                  ),
                ],
              ],
            ),
          },
        ],
      ),
    );
  }
}
