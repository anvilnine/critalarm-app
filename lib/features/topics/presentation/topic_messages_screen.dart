import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Hero tag for the newest message on a topic. The topic screen shows that one
/// card and this screen repeats it at the top of the full list, so the card
/// flies between the two instead of the list appearing from nowhere.
String topicLatestMessageHeroTag(String topicName, String timestamp) =>
    'topic-message-$topicName-$timestamp';

/// Every message on one topic. The topic screen shows only the newest so its
/// action button stays on screen; this is where the rest live.
class TopicMessagesScreen extends StatelessWidget {
  const TopicMessagesScreen({required this.topicName, super.key});

  final String topicName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicDetailCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: const _TopicMessagesView(),
    );
  }
}

class _TopicMessagesView extends StatelessWidget {
  const _TopicMessagesView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicDetailCubit, TopicDetailState>(
      builder: (context, state) {
        final messages = state.messages;

        return SeverityScope(
          severity: state.severity,
          child: AppScreenScaffold(
            hasTabBar: false,
            topBar: AppTopBar(
              title: state.topicName,
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.topic_detail_back_aria_label.tr(),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/topics/${state.topicName}');
                  }
                },
              ),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 16),
                  child: AppSheet(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSectionHeader(
                          LocaleKeys.topic_detail_messages_header.tr(),
                        ),
                        if (messages.isEmpty)
                          AppEmptyState(
                            title: LocaleKeys.topic_messages_empty_title.tr(),
                            description: LocaleKeys.topic_messages_empty_body
                                .tr(),
                            buttonLabel: null,
                            isLive: false,
                          ),
                        for (var i = 0; i < messages.length; i++) ...[
                          _card(messages[i], state.topicName, isNewest: i == 0),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(
    TopicDetailMessageItem msg,
    String topicName, {
    required bool isNewest,
  }) {
    final card = AppMessageCard(
      title: msg.title,
      timestamp: msg.timestamp,
      body: msg.body,
      source: msg.source,
      isHigh: msg.isHigh,
    );

    if (!isNewest) return card;

    return Hero(
      tag: topicLatestMessageHeroTag(topicName, msg.timestamp),
      child: Material(color: Colors.transparent, child: card),
    );
  }
}
