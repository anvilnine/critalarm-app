import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/topics/domain/topic_messages_page.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/message_share_text.dart';
import 'package:critalarm/features/topics/presentation/widgets/messages_page_header.dart';
import 'package:critalarm/features/topics/presentation/widgets/messages_page_row.dart';
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
///
/// The top says how many there are and draws the last seven days as bars,
/// with the days an alarm rang in red. The white sheet under it lists the
/// messages by day. A message that rang has a red mark and a mono line about
/// the ring, read from the incident the phone already holds for it.
///
/// The count is the number of messages in the list, which is the number the
/// "All N messages" link on the topic screen shows: every message the plan's
/// history window keeps.
class TopicMessagesScreen extends StatelessWidget {
  const TopicMessagesScreen({
    required this.topicName,
    this.cubit,
    this.incidents,
    super.key,
  });

  final String topicName;

  /// Optional cubit for testing and captures. It is not closed here.
  final TopicDetailCubit? cubit;

  /// The incident list the "rang" lines are read from. Null reads the app's
  /// own.
  final IncidentsCubit? incidents;

  @override
  Widget build(BuildContext context) {
    final view = BlocProvider.value(
      value: incidents ?? getIt<IncidentsCubit>(),
      child: _TopicMessagesView(topicName: topicName),
    );
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: view);
    }
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicDetailCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: view,
    );
  }
}

/// One message with the things the page works out for it.
class _Entry {
  const _Entry({
    required this.item,
    required this.at,
    required this.match,
  });

  final TopicDetailMessageItem item;
  final DateTime at;
  final RangMatch? match;
}

class _TopicMessagesView extends StatefulWidget {
  const _TopicMessagesView({required this.topicName});

  final String topicName;

  @override
  State<_TopicMessagesView> createState() => _TopicMessagesViewState();
}

class _TopicMessagesViewState extends State<_TopicMessagesView> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/topics/${Uri.encodeComponent(widget.topicName)}');
    }
  }

  List<_Entry> _entries(
    TopicDetailState state,
    RangIndex rang,
    DateTime now,
  ) {
    final messages = state.messages;
    return [
      for (var i = 0; i < messages.length; i++)
        () {
          final item = messages[i];
          final at =
              item.sentAt ??
              (i < state.messageTimes.length ? state.messageTimes[i] : now);
          return _Entry(
            item: item,
            at: at,
            match: rang.find(at: at, title: item.title, body: item.body),
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncidentsCubit, IncidentsState>(
      builder: (context, incidents) {
        return BlocBuilder<TopicDetailCubit, TopicDetailState>(
          builder: (context, state) {
            final cubit = context.read<TopicDetailCubit>();
            final now = DateTime.now();
            final rang = RangIndex.of(incidents.forTopic(widget.topicName));
            final entries = _entries(state, rang, now);

            final isLoading =
                entries.isEmpty &&
                (state.showMessagesSkeleton ||
                    state.status == TopicDetailStatus.initial);
            final hasFailed =
                entries.isEmpty && state.status == TopicDetailStatus.failure;
            final bars = messageDayBars(
              messages: [
                for (final e in entries) (at: e.at, rang: e.match != null),
              ],
              now: now,
            );

            return AppScreenScaffold(
              hasTabBar: false,
              onRefresh: () async {
                await cubit.refresh();
              },
              scrollController: _scroll,
              // The bar has one fixed height, so its text stops growing at
              // the chrome limit instead of being cut off by it.
              topBar: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: kChromeMaxTextScale),
                ),
                child: AppTopBar(
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.topic_messages_back_aria.tr(
                      namedArgs: {'topic': widget.topicName},
                    ),
                    onPressed: _back,
                  ),
                  // In the title slot, which is the one slot that is given a
                  // width, so the chip shrinks with an ellipsis for a long
                  // name. The title comes in once the header has scrolled
                  // under the bar.
                  titleWidget: SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppScrollBarTitle(
                            controller: _scroll,
                            title: LocaleKeys.topic_detail_messages_header.tr(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AppTopicChip(text: widget.topicName),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: MessagesPageHeader(
                    count: isLoading || hasFailed ? null : entries.length,
                    bars: bars,
                    isLoading: isLoading,
                    below: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: AppSheet(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        child: AnimatedSize(
                          duration: context.motion(AppDurations.base),
                          curve: AppCurves.easeOut,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: context.motion(AppDurations.base),
                            switchInCurve: AppCurves.easeOut,
                            switchOutCurve: AppCurves.easeOut,
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: isLoading
                                ? const KeyedSubtree(
                                    key: ValueKey('messages_view_skeleton'),
                                    child: _Skeleton(),
                                  )
                                : hasFailed
                                ? KeyedSubtree(
                                    key: const ValueKey('messages_view_failed'),
                                    child: _LoadFailed(
                                      message:
                                          state.errorMessage ??
                                          LocaleKeys.topic_messages_load_failed
                                              .tr(),
                                      onRetry: () => unawaited(
                                        cubit.load(widget.topicName),
                                      ),
                                    ),
                                  )
                                : entries.isEmpty
                                ? KeyedSubtree(
                                    key: const ValueKey('messages_view_empty'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: AppEmptyState(
                                        title: LocaleKeys
                                            .topic_messages_empty_title
                                            .tr(),
                                        description: LocaleKeys
                                            .topic_messages_empty_body
                                            .tr(),
                                        isLive: false,
                                      ),
                                    ),
                                  )
                                : KeyedSubtree(
                                    key: ValueKey(
                                      'messages_view_list_${entries.length}',
                                    ),
                                    child: _Days(
                                      topicName: widget.topicName,
                                      entries: entries,
                                      now: now,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The day groups: a small day name, then the day's messages with a hairline
/// between each.
class _Days extends StatelessWidget {
  const _Days({
    required this.topicName,
    required this.entries,
    required this.now,
  });

  final String topicName;
  final List<_Entry> entries;
  final DateTime now;

  String _dayName(MessageDay<_Entry> group) => switch (group.kind) {
    MessageDayKind.today => LocaleKeys.topic_messages_day_today.tr(),
    MessageDayKind.yesterday => LocaleKeys.home_card_row_yesterday.tr(),
    MessageDayKind.earlier => DateFormat(
      group.day.year == now.year ? 'EEEE d MMMM' : 'EEEE d MMMM y',
    ).format(group.day),
  };

  String? _rangText(RangLine? line) {
    if (line == null) return null;
    final end = switch (line.end) {
      RangEnd.answered => LocaleKeys.topic_messages_end_answered.tr(),
      RangEnd.resolved => LocaleKeys.topic_messages_end_resolved.tr(),
      RangEnd.expired => LocaleKeys.topic_messages_end_expired.tr(),
      RangEnd.ringing => LocaleKeys.topic_messages_end_ringing.tr(),
    };
    final duration = line.duration;
    if (duration == null) return end;
    return LocaleKeys.topic_messages_rang_line.tr(
      namedArgs: {
        'rang': LocaleKeys.topic_messages_rang_for.tr(
          namedArgs: {'duration': formatCompactDuration(duration)},
        ),
        'end': end,
      },
    );
  }

  Widget _row(BuildContext context, _Entry entry, {required bool isNewest}) {
    final item = entry.item;
    final row = MessagesPageRow(
      title: item.title,
      time: item.sentAt == null
          ? item.timestamp
          : DateFormat.Hm().format(entry.at.toLocal()),
      body: item.body,
      tags: item.source,
      mark: entry.match != null
          ? MessageMark.rang
          : item.isHigh
          ? MessageMark.high
          : MessageMark.quiet,
      rangText: _rangText(entry.match?.line),
      shareLabel: LocaleKeys.topic_messages_share_label.tr(),
      onShare: (origin) => shareMessage(item, topicName, origin),
    );
    if (!isNewest) return row;
    // The newest message flies in from the topic screen.
    return Hero(
      tag: topicLatestMessageHeroTag(topicName, item.timestamp),
      child: Material(color: Colors.transparent, child: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final groups = groupMessagesByDay<_Entry>(
      entries,
      timeOf: (entry) => entry.at,
      now: now,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups) ...[
          AppSectionHeader(
            _dayName(group),
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
          ),
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0)
              ColoredBox(
                color: colors.hairline,
                child: const SizedBox(height: 1),
              ),
            _row(
              context,
              group.items[i],
              isNewest: identical(group.items[i], entries.first),
            ),
          ],
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const MessagesPageRowSkeleton(),
          ColoredBox(color: colors.hairline, child: const SizedBox(height: 1)),
          const MessagesPageRowSkeleton(),
          ColoredBox(color: colors.hairline, child: const SizedBox(height: 1)),
          const MessagesPageRowSkeleton(),
          ColoredBox(color: colors.hairline, child: const SizedBox(height: 1)),
          const MessagesPageRowSkeleton(),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: AppNote(text: message),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.topic_detail_retry_button.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
