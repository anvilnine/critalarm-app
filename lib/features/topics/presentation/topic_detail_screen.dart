import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_tokens_section.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/tour_anchor.dart';
import 'package:critalarm/features/tour/presentation/tour_examples.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
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
    super.key,
  });

  final String topicName;

  /// True when this screen is drawn inside a detail pane rather than pushed
  /// as its own page.
  final bool isPane;

  @override
  Widget build(BuildContext context) {
    // The tour's made-up topic is not on the server, so it is drawn from the
    // example instead of being asked for.
    final isExample = getIt<TourCubit>().state.showsExampleTopic(topicName);
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicDetailCubit>();
        if (isExample) {
          cubit.showExample(TourExamples.topicDetail());
        } else {
          unawaited(cubit.load(topicName));
        }
        return cubit;
      },
      child: _TopicDetailScreenContent(isPane: isPane, isExample: isExample),
    );
  }
}

class _TopicDetailScreenContent extends StatelessWidget {
  const _TopicDetailScreenContent({
    required this.isPane,
    required this.isExample,
  });

  final bool isPane;

  /// The tour's example topic. It has no tokens on the server to list.
  final bool isExample;

  /// Asks first, then deletes, then leaves.
  ///
  /// The screen goes as soon as the person says yes, and the shared topic list
  /// has the topic out of it before that, so the list behind is already right
  /// rather than catching up a moment later. A server that refuses puts the
  /// topic back and says why on the screen underneath, which by then is the
  /// topics list.
  Future<void> _confirmDelete(BuildContext context, String topicName) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.topic_detail_delete_dialog_title.tr(
        namedArgs: {'topic': topicName},
      ),
      body: LocaleKeys.topic_detail_delete_dialog_content.tr(),
      actions: [
        AppDialogAction(
          label: LocaleKeys.common_cancel.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: LocaleKeys.topic_detail_delete_dialog_confirm.tr(),
          value: true,
          variant: AppButtonVariant.crit,
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicDetailCubit, TopicDetailState>(
      builder: (context, state) {
        final latest = state.messages.isEmpty ? null : state.messages.first;
        final olderCount = state.messages.isEmpty
            ? 0
            : state.messages.length - 1;

        // Nothing is ringing, so there is nothing to stop. The button used to
        // sit at the bottom of the sheet on every topic, whatever its state.
        final isRinging = state.openIncidentIds.isNotEmpty;

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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RefreshActivityIndicator(),
                  const SizedBox(width: 8),
                  AppTopicChip(
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
                ],
              ),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: Spacing.s3),
                    AppStage(
                      faceState: state.faceState,
                      faceSize: 170,
                      word: state.word,
                      topicName: state.topicName,
                      sub: state.subText,
                    ),
                    const SizedBox(height: Spacing.s4),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  // The acknowledge button floats over the bottom of the
                  // list, so the sheet leaves room for it rather than sliding
                  // its last row underneath.
                  padding: EdgeInsets.fromLTRB(12, 0, 12, isRinging ? 88 : 16),
                  child: AppSheet(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.capReached != null)
                          AppEmptyState(
                            title: state.capReached!.message,
                            description:
                                'Review your plan to increase this limit.',
                            faceState: FaceState.worried,
                            buttonLabel: null,
                            isLive: false,
                          )
                        else if (state.errorMessage != null) ...[
                          // Was a bare Text dropped in the middle of the
                          // sheet, with no way to try the thing again.
                          // The toast is a pill that sizes to its text, so it
                          // stays centred while the rest of the card stretches.
                          Center(
                            child: AppToast(
                              faceState: FaceState.worried,
                              message: state.errorMessage,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 10),
                        ],
                        TourAnchor(
                          id: TourAnchorId.topicCritical,
                          child: AppToggleRow(
                            title: LocaleKeys.topic_detail_critical_toggle_title
                                .tr(),
                            subtitle: state.canEditCritical
                                ? LocaleKeys
                                      .topic_detail_critical_toggle_subtitle
                                      .tr()
                                : LocaleKeys.topic_detail_critical_needs_alarm
                                      .tr(),
                            value: state.critical,
                            // No alarm permission, no critical delivery: the
                            // push would arrive as a plain notification and
                            // never ring.
                            onChanged: state.canEditCritical
                                ? (val) {
                                    AppHaptics.selection();
                                    unawaited(
                                      context
                                          .read<TopicDetailCubit>()
                                          .toggleCriticalDelivery(
                                            isCritical: val,
                                          ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Per-topic sound. Stored on the device only, so it
                        // is not part of the topic the server knows about.
                        TourAnchor(
                          id: TourAnchorId.topicSound,
                          child: AppListRow(
                            name: LocaleKeys.topic_detail_sound_row_title.tr(),
                            meta: LocaleKeys.topic_detail_sound_row_default
                                .tr(),
                            trailing: AppGlyph(
                              GlyphType.arrow,
                              color: context.appColors.ink3,
                              size: 16,
                            ),
                            onTap: () => context.push(
                              '${GoRouterState.of(context).uri.path}/sounds',
                            ),
                          ),
                        ),
                        const AppSectionDivider(),
                        AppSectionHeader(
                          LocaleKeys.topic_detail_messages_header.tr(),
                        ),
                        // Only the newest one. The whole list used to run
                        // down the sheet and push the action button off the
                        // bottom of a long topic.
                        if (latest != null) ...[
                          Hero(
                            tag: topicLatestMessageHeroTag(
                              state.topicName,
                              latest.timestamp,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: AppMessageCard(
                                title: latest.title,
                                timestamp: latest.timestamp,
                                body: latest.body,
                                source: latest.source,
                                isHigh: latest.isHigh,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (olderCount > 0)
                          AppButton(
                            label: LocaleKeys.topic_detail_view_all_messages
                                .plural(olderCount),
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            isFullWidth: true,
                            onPressed: () => unawaited(
                              context.push(
                                '${GoRouterState.of(context).uri.path}/messages',
                              ),
                            ),
                          ),
                        if (!isExample)
                          TopicTokensSection(topicName: state.topicName),
                        const SizedBox(height: Spacing.s5),
                        // Last on the sheet, so nothing is reached past to
                        // get to it.
                        TourAnchor(
                          id: TourAnchorId.topicDelete,
                          child: AppButton(
                            label: LocaleKeys.topic_detail_delete_button.tr(),
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            isFullWidth: true,
                            onPressed: () => unawaited(
                              _confirmDelete(context, state.topicName),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return scaffold;
      },
    );
  }
}
