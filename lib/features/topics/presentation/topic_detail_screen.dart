import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_signals.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_examples.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/topics/domain/topic_hero_card.dart';
import 'package:critalarm/features/topics/domain/topic_summary.dart';
import 'package:critalarm/features/topics/domain/topic_tokens_page_rules.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/message_share_text.dart';
import 'package:critalarm/features/topics/presentation/pane_rules.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_hero_parts.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_message_row.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_pass_stack.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// TopicDetailScreen with severity retinting, messages, and critical toggle.
class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({
    required this.topicName,
    this.isPane = false,
    this.startCurlFlow = false,
    this.cubit,
    this.isExample = false,
    super.key,
  });

  final String topicName;

  /// True when this screen is drawn inside a detail pane rather than pushed
  /// as its own page.
  final bool isPane;

  /// Opens the Tokens page with its New token sheet already open, as soon as
  /// this screen builds. The silent topic reminder's "Get curl line" arrives
  /// here.
  final bool startCurlFlow;

  /// Optional cubit for testing.
  final TopicDetailCubit? cubit;

  /// Whether a given [cubit] holds the guide's made-up topic. Without a cubit
  /// the guide decides, so this is read only with one.
  final bool isExample;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _TopicDetailScreenContent(isPane: isPane, isExample: isExample),
      );
    }
    // The guide's made-up topic is not on the server, so it is drawn from the
    // example instead of being asked for.
    final isGuideExample = getIt<FeatureGuideCubit>().state.showsExampleTopic(
      topicName,
    );
    return _CurlStarter(
      isEnabled: startCurlFlow && !isGuideExample,
      topicName: topicName,
      child: BlocProvider(
        create: (_) {
          final cubit = getIt<TopicDetailCubit>();
          if (isGuideExample) {
            cubit.showExample(FeatureGuideExamples.topicDetail());
          } else {
            unawaited(cubit.load(topicName));
          }
          return cubit;
        },
        child: _TopicDetailScreenContent(
          isPane: isPane,
          isExample: isGuideExample,
        ),
      ),
    );
  }
}

/// Pushes the Tokens page with `?curl=1` once, right after the screen first
/// builds, so back from it lands on the topic.
class _CurlStarter extends StatefulWidget {
  const _CurlStarter({
    required this.isEnabled,
    required this.topicName,
    required this.child,
  });

  final bool isEnabled;
  final String topicName;
  final Widget child;

  @override
  State<_CurlStarter> createState() => _CurlStarterState();
}

class _CurlStarterState extends State<_CurlStarter> {
  @override
  void initState() {
    super.initState();
    if (!widget.isEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = GoRouterState.of(context).uri.path;
      final base = path == '/history' || path.startsWith('/history/')
          ? '/history'
          : '/';
      unawaited(
        context.push<void>(
          topicTokensPath(base, widget.topicName, startCurlFlow: true),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TopicDetailScreenContent extends StatelessWidget {
  const _TopicDetailScreenContent({
    required this.isPane,
    required this.isExample,
  });

  final bool isPane;

  /// The guide's example topic. It has no tokens on the server to list.
  final bool isExample;

  /// Asks first, then deletes, then leaves.
  ///
  /// The screen goes as soon as the person says yes, and the shared topic list
  /// has the topic out of it before that, so the list behind is already right
  /// rather than catching up a moment later. A server that refuses puts the
  /// topic back and says why on the screen underneath, which by then is the
  /// topics list.
  Future<void> _confirmDelete(BuildContext context, String topicName) async {
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: AppDialog(
            title: LocaleKeys.topic_detail_delete_dialog_title.tr(
              namedArgs: {'topic': topicName},
            ),
            body: LocaleKeys.topic_detail_delete_dialog_content.tr(),
            content: AppToggleRow(
              title: LocaleKeys.topic_detail_delete_confirm_toggle.tr(),
              value: acknowledged,
              onChanged: (value) => setDialogState(() {
                acknowledged = value;
              }),
            ),
            actions: [
              AppButton(
                label: LocaleKeys.common_cancel.tr(),
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              AppButton(
                label: LocaleKeys.topic_detail_delete_dialog_confirm.tr(),
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.sm,
                onPressed: acknowledged
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    AppHaptics.destructive();
    // Read before the pop, because the pop takes this context with it.
    final topics = getIt<TopicsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // As a pane there is no page to leave; the topics list beside it drops
    // the row and the pane clears itself.
    if (!isPane && router.canPop()) router.pop();

    final reason = await topics.deleteTopic(topicName);
    if (reason == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          LocaleKeys.topic_detail_delete_failed.tr(
            namedArgs: {'topic': topicName, 'reason': reason},
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmTurnOffCritical(BuildContext context) =>
      showAppDialog<bool>(
        context: context,
        title: LocaleKeys.topic_detail_critical_off_one_way_title.tr(),
        body: LocaleKeys.topic_detail_critical_off_one_way_body.tr(),
        actions: [
          AppDialogAction(
            label: LocaleKeys.common_cancel.tr(),
            value: false,
            variant: AppButtonVariant.ghost,
          ),
          AppDialogAction(
            label: LocaleKeys.topic_detail_critical_off_one_way_confirm.tr(),
            value: true,
            variant: AppButtonVariant.crit,
          ),
        ],
      );

  /// Flips Critical delivery. Everything the old row did stays: the haptic,
  /// the one-way-off confirm, the cap and the error states in the cubit.
  Future<void> _setCritical(BuildContext context, bool value) async {
    AppHaptics.selection();
    final cubit = context.read<TopicDetailCubit>();
    if (!value && await cubit.turningOffIsOneWay()) {
      if (!context.mounted) return;
      final confirmed = await _confirmTurnOffCritical(context);
      if (confirmed != true) return;
    }
    await cubit.toggleCriticalDelivery(isCritical: value);
  }

  void _showCriticalInfo(BuildContext context, TopicDetailState state) {
    unawaited(
      showAppDialog<void>(
        context: context,
        title: LocaleKeys.topic_detail_critical_info_title.tr(),
        body: _criticalInfoText(state),
        actions: [
          AppDialogAction<void>(
            label: LocaleKeys.common_close.tr(),
            variant: AppButtonVariant.ghost,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicDetailCubit, TopicDetailState>(
      builder: (context, state) {
        // Nothing is ringing, so there is nothing to stop. The button used to
        // sit at the bottom of the sheet on every topic, whatever its state.
        final isRinging = state.openIncidentIds.isNotEmpty;

        final isLoading =
            state.status == TopicDetailStatus.initial ||
            state.status == TopicDetailStatus.loading;
        final card = topicHeroCardFor(
          critical: state.critical,
          canEditCritical: state.canEditCritical,
          claim: RingClaim.forPhone(state.alarm),
          isLoading: isLoading,
        );
        final summary = topicSummaryFor(
          messageTimes: state.messageTimes,
          lastAlarmAt: state.lastAlarmAt,
          now: DateTime.now(),
        );

        final tone = _heroTone(card, state.severity);

        // On a fold the face and the Critical delivery card hold still in
        // their own pane. Tabletop: they fill the top half and the name,
        // messages and passes scroll in the bottom half. Book: the start
        // pane also carries the name and the newest message, and the passes
        // scroll in the end pane. A pane inside Home never sees the fold.
        final fold = AppFold.of(context);
        final onStage = !isPane && heroOnFoldStage(fold, hasDetail: false);
        final isBookStage = onStage && fold.isBook;

        final header = TopicHeader(
          name: state.topicName,
          // Blank until the messages have been read, so the line does not
          // say "nothing yet" and then change.
          summary: state.areMessageTimesKnown ? topicSummaryText(summary) : '',
        );
        final hero = AppHeroScene(
          face: state.faceState,
          tone: tone,
          gaze: AppHeroGaze.card,
          isPane: isPane,
          card: FeatureGuideAnchor(
            id: FeatureGuideAnchorId.topicCritical,
            child: TopicCriticalCard(
              card: card,
              onChanged: card.canSwitch
                  ? (value) => unawaited(_setCritical(context, value))
                  : null,
              onInfo: () => _showCriticalInfo(context, state),
            ),
          ),
        );
        final sheet = Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: _TopicSheet(
            state: state,
            isExample: isExample,
            showsMessages: !isBookStage,
            onDelete: () => unawaited(_confirmDelete(context, state.topicName)),
          ),
        );

        final scaffold = SeverityScope(
          severity: state.severity,
          child: AppScreenScaffold(
            // Pushed, this screen covers the display and the tab bar goes with
            // it. As a pane it never had one. Either way there is no bar to
            // leave room for.
            hasTabBar: false,
            onFaceRefresh: () => context.read<TopicDetailCubit>().refresh(),
            withGhosts: !isPane,
            backgroundColor: isPane ? context.appColors.surface : null,
            // Pinned rather than trailing the message list, so acknowledging
            // never means scrolling first.
            bottomBar: isRinging
                ? AppButton(
                    label: LocaleKeys.topic_detail_stop_alarm_button.tr(),
                    variant: AppButtonVariant.ink,
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    isLoading: state.isMarkingAsRead,
                    onPressed: () {
                      AppHaptics.capture();
                      unawaited(
                        context.read<TopicDetailCubit>().markAsRead(),
                      );
                    },
                  )
                : null,
            topBar: AppTopBar(
              leading: isPane
                  ? null
                  : AppIconButton(
                      glyph: GlyphType.back,
                      ariaLabel: LocaleKeys.topic_detail_back_aria_label.tr(),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
              // In the title slot, which is the one slot that is given a
              // width, so the chip shrinks with an ellipsis for a long name.
              titleWidget: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const RefreshActivityIndicator(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppTopicChip(
                        text: 'POST /${state.topicName}',
                        onTap: () {
                          unawaited(
                            Clipboard.setData(
                              ClipboardData(
                                text: 'POST /${state.topicName}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            foldStage: !onStage
                ? null
                : FoldStageColumn(
                    children: [
                      const SizedBox(height: Spacing.s3),
                      if (isBookStage) ...[
                        header,
                        const SizedBox(height: Spacing.s3),
                      ],
                      hero,
                      if (isBookStage) ...[
                        const SizedBox(height: Spacing.s4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: AppInboxSheet(
                            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                            children: [_MessagesBlock(state: state, limit: 1)],
                          ),
                        ),
                      ],
                    ],
                  ),
            slivers: [
              SliverToBoxAdapter(
                // The hero and the sheet are one box, so the sheet paints
                // over the part of the disc that reaches down behind it.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Spacing.s3),
                    if (!isBookStage) ...[
                      header,
                      const SizedBox(height: Spacing.s3),
                    ],
                    if (!onStage) ...[
                      hero,
                      const SizedBox(height: Spacing.s4),
                    ],
                    sheet,
                  ],
                ),
              ),
            ],
          ),
        );

        // The pane draws on the surface beside the list, and the list owns the
        // canvas there. A pushed page gives the canvas its own backdrop: the
        // Topics hero profile, with the disc under this screen's face. Read
        // outside the severity scope, so it is the app's own colours.
        //
        // It is an override and not a profile registered for the route's path:
        // the router's current location ignores a pushed page, so the shell
        // never sees a path change when Home pushes this screen. The override
        // goes when the screen does, and the canvas morphs back to Home's.
        if (isPane) return scaffold;
        return AmbientOverride(
          direction: AmbientDirection.push,
          profile: topicCanvasProfileFor(
            context,
            state,
            stage: !onStage
                ? null
                : (isBookStage ? TopicFoldStage.book : TopicFoldStage.tabletop),
          ),
          child: scaffold,
        );
      },
    );
  }

  static AppHeroTone _heroTone(TopicHeroCard card, SeverityMode severity) =>
      topicHeroToneFor(card, severity);
}

/// The disc tint: quiet while Critical delivery is off. Under a warning or
/// ringing canvas the disc is the canvas's own lighter step, so it stays
/// calm there.
AppHeroTone topicHeroToneFor(TopicHeroCard card, SeverityMode severity) =>
    card.hasQuietDisc && severity == SeverityMode.none
    ? AppHeroTone.quiet
    : AppHeroTone.calm;

/// The canvas behind the Topic screen for [state]: the Topics hero profile
/// with the disc under this screen's face.
///
/// Where the hero's disc sits depends on how tall the name and the summary
/// are, which stand between the top bar and the scene. The tone depends on
/// Critical delivery, so it is read from [TopicDetailState.critical] even
/// while the card still shows its dots.
AmbientProfile topicCanvasProfileFor(
  BuildContext context,
  TopicDetailState state, {
  TopicFoldStage? stage,
}) {
  final card = topicHeroCardFor(
    critical: state.critical,
    canEditCritical: state.canEditCritical,
    claim: RingClaim.forPhone(state.alarm),
  );
  final stageWidth = stage == null ? null : foldStageHeroSpot(context).width;
  final headerHeight = topicHeaderHeight(
    context,
    name: state.topicName,
    width: stageWidth ?? MediaQuery.sizeOf(context).width,
    // Same text TopicHeader draws, so a two-line summary moves the disc too.
    summary: state.areMessageTimesKnown
        ? topicSummaryText(
            topicSummaryFor(
              messageTimes: state.messageTimes,
              lastAlarmAt: state.lastAlarmAt,
              now: DateTime.now(),
            ),
          )
        : '',
  );
  return AmbientAppProfiles.topicsHero(
    context.appColors,
    severity: state.severity,
    tone: topicHeroToneFor(card, state.severity),
    spot: switch (stage) {
      null => heroDiscSpotOf(context, above: headerHeight + Spacing.s3),
      TopicFoldStage.tabletop => foldStageDiscSpotOf(context),
      TopicFoldStage.book => foldStageDiscSpotOf(
        context,
        above: headerHeight + Spacing.s3,
      ),
    },
  );
}

/// Which fold stage the Topic screen draws its hero in. See
/// [topicCanvasProfileFor].
enum TopicFoldStage {
  /// The top half: face and card.
  tabletop,

  /// The start pane: name, face, card and the newest message.
  book,
}

/// Gives the canvas the Topic screen's arrangement before the screen is
/// pushed, so it starts gliding to it with the route and the screen's first
/// frame is already on it. The screen would hand it over after its first
/// frame otherwise. Call it from the list, just before pushing the topic.
/// Does nothing when the app holds nothing about the topic yet, and the
/// screen then sets the canvas itself.
void primeTopicCanvas(BuildContext context, String topicName) {
  unawaited(warmTopicSoundPeaks());
  final controller = AmbientScope.controllerOf(context);
  if (controller == null || !getIt.isRegistered<TopicDetailCubit>()) return;
  final cubit = getIt<TopicDetailCubit>();
  final seed = cubit.seedFor(topicName);
  unawaited(cubit.close());
  if (seed == null) return;
  controller.setOverride(
    profile: topicCanvasProfileFor(context, seed),
    direction: AmbientDirection.push,
  );
}

/// Copy explaining critical delivery. Older iPhones cannot ring through silent
/// mode, so use the platform-specific [RingClaim].
String _criticalInfoText(TopicDetailState state) {
  if (!state.canEditCritical) {
    return LocaleKeys.topic_detail_critical_needs_alarm.tr();
  }
  return switch (RingClaim.forPhone(state.alarm)) {
    RingClaim.timeSensitive =>
      LocaleKeys.topic_detail_critical_toggle_subtitle_time_sensitive.tr(),
    RingClaim.alarm => LocaleKeys.topic_detail_critical_toggle_subtitle.tr(),
  };
}

/// How many of the newest messages the sheet shows. The rest open on their
/// own screen.
const int _kSheetMessages = 3;

/// The white sheet under the hero: the messages to read, then the pass stack
/// for the topic's look, sound, challenge and tokens, then Delete topic.
class _TopicSheet extends StatelessWidget {
  const _TopicSheet({
    required this.state,
    required this.isExample,
    required this.onDelete,
    this.showsMessages = true,
  });

  final TopicDetailState state;
  final bool isExample;
  final VoidCallback onDelete;

  /// False when the messages are drawn elsewhere: beside the fold, in the
  /// start pane with the face.
  final bool showsMessages;

  @override
  Widget build(BuildContext context) {
    return AppInboxSheet(
      // Nothing under the Delete button's tap box, which has the 6 itself.
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      children: [
        if (showsMessages) _MessagesBlock(state: state),
        // The topic's look, sound, wake-up challenge and tokens. Each card
        // opens the page that changes it. Kept on the device only, except the
        // tokens.
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
          child: TopicPassStack(
            topicName: state.topicName,
            isExample: isExample,
          ),
        ),
        // Flash and strong vibration, added to the ring. Kept on the device
        // only, like the sound.
        if (!isExample)
          _AlarmSignalRows(
            state: state,
            rows: alarmSignalRowsFor(
              capabilities: getIt<PlatformCapabilities>(),
              hasTorch: state.hasTorch,
              critical: state.critical,
            ),
          ),
        // Last on the sheet, so nothing is reached past to get to it.
        FeatureGuideAnchor(
          id: FeatureGuideAnchorId.topicDelete,
          // The button is a 36 pill with 4 above it, under the sheet's
          // divider, and 4 below it with the sheet's own 6 under that. Its tap
          // box takes all of that: 4 above, 10 below, 50 high, and the pill
          // does not move.
          child: AppTapTarget(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: AppButton(
                label: LocaleKeys.topic_detail_delete_button.tr(),
                variant: AppButtonVariant.dangerText,
                size: AppButtonSize.sm,
                hasTapBox: false,
                isFullWidth: true,
                onPressed: onDelete,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A cap or an error, the newest messages, and the way to all of them.
class _MessagesBlock extends StatelessWidget {
  const _MessagesBlock({required this.state, this.limit = _kSheetMessages});

  final TopicDetailState state;

  /// How many of the newest messages show before the link to all of them.
  final int limit;

  /// Keeps the old child in place while the new one fades in, and animates the
  /// height between the two.
  Widget _swap(BuildContext context, {required Widget child}) => AnimatedSize(
    duration: context.motion(AppDurations.base),
    curve: AppCurves.easeOut,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      switchOutCurve: AppCurves.easeOut,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ...previousChildren,
          ?currentChild,
        ],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final messages = state.messages;
    final shown = messages.take(limit).toList();
    final newest = messages.isEmpty ? null : messages.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _swap(
          context,
          child: state.capReached != null
              ? KeyedSubtree(
                  key: const ValueKey('sheet_cap_reached'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: AppEmptyState(
                      title: state.capReached!.message,
                      description: LocaleKeys
                          .create_topic_limit_review_plan_hint
                          .tr(),
                      faceState: FaceState.worried,
                      isLive: false,
                    ),
                  ),
                )
              : state.errorMessage != null
              ? KeyedSubtree(
                  key: ValueKey('sheet_error_${state.errorMessage}'),
                  child: Padding(
                    // No padding below: the retry button's tap box reaches 6
                    // under the pill, so the 4 that were there and 2 of the 12
                    // in the header's top are spent on it.
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Column(
                      children: [
                        Center(
                          child: AppToast(
                            faceState: FaceState.worried,
                            message: state.errorMessage,
                          ),
                        ),
                        // The retry button is a 36 pill in a 48 tap box: 6
                        // less above it.
                        const SizedBox(height: 4),
                        AppButton(
                          label: LocaleKeys.topic_detail_retry_button.tr(),
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          isFullWidth: true,
                          onPressed: () => unawaited(
                            context.read<TopicDetailCubit>().load(
                              state.topicName,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('sheet_no_error')),
        ),
        AppSectionHeader(
          LocaleKeys.topic_detail_messages_header.tr(),
          // 2 less on top when the retry button is above: its tap box reaches
          // 6 below the pill and the padding under it was 4.
          padding: EdgeInsets.fromLTRB(
            14,
            state.capReached == null && state.errorMessage != null ? 10 : 12,
            14,
            0,
          ),
        ),
        _swap(
          context,
          child: state.showMessagesSkeleton && messages.isEmpty
              ? const KeyedSubtree(
                  key: ValueKey('messages_skeleton'),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: AppMessageCardSkeleton(),
                  ),
                )
              : messages.isEmpty
              ? KeyedSubtree(
                  key: const ValueKey('messages_empty'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    child: Text(
                      LocaleKeys.topic_hero_no_messages.tr(),
                      style: AppTypography.small(colors.ink3),
                    ),
                  ),
                )
              : KeyedSubtree(
                  key: ValueKey(
                    'messages_${newest!.timestamp}_${messages.length}',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: ColoredBox(
                              color: colors.hairline,
                              child: const SizedBox(height: 1),
                            ),
                          ),
                        _row(
                          context,
                          shown[i],
                          isNewest: i == 0,
                          // The link is 4 taller than it was, and its words
                          // keep their place: the row above gives up the 4.
                          bottomPadding:
                              i == shown.length - 1 &&
                                  messages.length > shown.length
                              ? 8
                              : 12,
                        ),
                      ],
                      if (messages.length > shown.length)
                        _AllMessagesLink(
                          count: messages.length,
                          onTap: () => unawaited(
                            context.push('${_topicPath(context)}/messages'),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// The topic's own path. In Home's detail pane the router is on `/`, so
  /// the pane names the topic itself.
  String _topicPath(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path.contains('/topics/')
        ? path
        : '/topics/${Uri.encodeComponent(state.topicName)}';
  }

  Widget _row(
    BuildContext context,
    TopicDetailMessageItem message, {
    required bool isNewest,
    required double bottomPadding,
  }) {
    final row = TopicMessageRow(
      bottomPadding: bottomPadding,
      title: message.title,
      timestamp: message.timestamp,
      body: message.body,
      source: message.source,
      isHigh: message.isHigh,
      shareLabel: LocaleKeys.topic_messages_share_label.tr(),
      onShare: (origin) => shareMessage(message, state.topicName, origin),
    );
    if (!isNewest) return row;
    // The newest message flies to the messages screen when it is opened.
    return Hero(
      tag: topicLatestMessageHeroTag(state.topicName, message.timestamp),
      child: Material(color: Colors.transparent, child: row),
    );
  }
}

/// "All 14 messages", in the accent, opening the messages screen.
class _AllMessagesLink extends StatelessWidget {
  const _AllMessagesLink({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              // 4 more above than below, so the words sit where they did in
              // the 44 high row, which started 4 lower.
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Text(
                LocaleKeys.topic_hero_all_messages.plural(count),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.highlight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The flash and strong vibration switches for one topic. Draws nothing when
/// the phone or the topic has neither: see [alarmSignalRowsFor].
class _AlarmSignalRows extends StatelessWidget {
  const _AlarmSignalRows({required this.state, required this.rows});

  final TopicDetailState state;
  final AlarmSignalRows rows;

  @override
  Widget build(BuildContext context) {
    if (!rows.any) return const SizedBox.shrink();
    final cubit = context.read<TopicDetailCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rows.flash)
            AppToggleRow(
              title: LocaleKeys.topic_detail_flash_row_title.tr(),
              subtitle: rows.flashNeedsAlarmScreen
                  ? LocaleKeys.topic_detail_flash_row_subtitle_ios.tr()
                  : LocaleKeys.topic_detail_flash_row_subtitle.tr(),
              value: state.flashOn,
              onChanged: (on) {
                AppHaptics.selection();
                unawaited(cubit.setFlash(on: on));
              },
            ),
          if (rows.flash && rows.strongVibration) const SizedBox(height: 8),
          if (rows.strongVibration)
            AppToggleRow(
              title: LocaleKeys.topic_detail_vibration_row_title.tr(),
              subtitle: LocaleKeys.topic_detail_vibration_row_subtitle.tr(),
              value: state.strongVibrationOn,
              onChanged: (on) {
                AppHaptics.selection();
                unawaited(cubit.setStrongVibration(on: on));
              },
            ),
        ],
      ),
    );
  }
}
