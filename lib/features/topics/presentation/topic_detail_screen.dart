import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
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
    super.key,
  });

  final String topicName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicDetailCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: const _TopicDetailScreenContent(),
    );
  }
}

class _TopicDetailScreenContent extends StatelessWidget {
  const _TopicDetailScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicDetailCubit, TopicDetailState>(
      builder: (context, state) {
        final colors = context.appColors;

        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return SeverityScope(
          severity: state.severity,
          child: Scaffold(
            backgroundColor: colors.canvas,
            body: GhostField(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  AppSliverTopBar(
                    leading: AppIconButton(
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
                    trailing: AppTopicChip(
                      text: 'POST /t/${state.topicName}',
                      onTap: () {
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(
                              text: 'POST /t/${state.topicName}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          16 + bottomInset,
                        ),
                        child: AppSheet(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final msg in state.messages) ...[
                                AppMessageCard(
                                  title: msg.title,
                                  timestamp: msg.timestamp,
                                  body: msg.body,
                                  source: msg.source,
                                  isHigh: msg.isHigh,
                                ),
                                const SizedBox(height: 10),
                              ],
                              const SizedBox(height: 4),
                              AppToggleRow(
                                title: LocaleKeys
                                    .topic_detail_critical_toggle_title
                                    .tr(),
                                subtitle: LocaleKeys
                                    .topic_detail_critical_toggle_subtitle
                                    .tr(),
                                value: state.critical,
                                onChanged: (val) {
                                  unawaited(
                                    context
                                        .read<TopicDetailCubit>()
                                        .toggleCriticalDelivery(
                                          isCritical: val,
                                        ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: LocaleKeys
                                    .topic_detail_mark_as_read_button
                                    .tr(),
                                variant: AppButtonVariant.ink,
                                isFullWidth: true,
                                isLoading: state.isMarkingAsRead,
                                onPressed: () {
                                  unawaited(
                                    context
                                        .read<TopicDetailCubit>()
                                        .markAsRead(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
