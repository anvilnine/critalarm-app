import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/history/presentation/widgets/history_filter_sheet.dart';
import 'package:critalarm/features/history/presentation/widgets/history_hero.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Past alarms grouped by day. Root of the History tab.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<HistoryCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _HistoryScreenContent(),
    );
  }
}

class _HistoryScreenContent extends StatefulWidget {
  const _HistoryScreenContent();

  @override
  State<_HistoryScreenContent> createState() => _HistoryScreenContentState();
}

class _HistoryScreenContentState extends State<_HistoryScreenContent> {
  HistoryEntry? _selected;

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);

    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        // Nothing is on screen to count until the first read finishes.
        final isFirstLoad =
            (state.isLoading || state.status == HistoryStatus.initial) &&
            state.days.isEmpty;
        final hasHero = !isFirstLoad && state.status != HistoryStatus.failure;
        final week = buildWeekBars(
          // What the list shows, so a filter narrows the chart too.
          entries: [for (final day in state.days) ...day.entries],
          now: DateTime.now(),
          shownDays: state.shownDays,
          hasMore: state.hasMore,
          oldestLoaded: state.entries.isEmpty
              ? null
              : state.entries.last.startedAt,
        );

        // The canvas behind the screen is the ambient one. It gets the disc
        // behind the face, and morphs to the next tab's profile on a change.
        return AmbientRouteProfile(
          path: '/history',
          profile: AmbientAppProfiles.historyHero(
            context.appColors,
            spot: historyDiscSpotOf(context),
          ),
          child: NotificationListener<ScrollNotification>(
            // Reads the next page off the phone as the list nears its end.
            // Nothing here touches the network: the rows are already on disk.
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (state.hasMore &&
                  !state.isLoadingMore &&
                  metrics.pixels > metrics.maxScrollExtent - 400) {
                unawaited(context.read<HistoryCubit>().loadMore());
              }
              return false;
            },
            child: AppScreenScaffold(
              // The list is text on white and scrolls under the title, so the
              // backing holds full strength behind the whole title row.
              onFaceRefresh: () => context.read<HistoryCubit>().refresh(),
              topBar: AppTopBar(
                title: LocaleKeys.history_title.tr(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RefreshActivityIndicator(),
                    const SizedBox(width: 8),
                    _FilterButton(filter: state.filter),
                  ],
                ),
              ),
              detail: state.isEmpty
                  ? null
                  : _selected == null
                  ? AppEmptyState(
                      title: LocaleKeys.history_detail_empty_title.tr(),
                      description: LocaleKeys.history_detail_empty_body.tr(),
                    )
                  : _IncidentDetail(
                      key: ValueKey(_selected?.id),
                      entry: _selected!,
                    ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      Spacing.s3,
                      12,
                      Spacing.s4,
                    ),
                    child: hasHero
                        ? HistoryHero(
                            week: week,
                            isFiltered: state.filter.isActive,
                          )
                        : const SizedBox(height: Spacing.s2),
                  ),
                ),
                // Loading and failure both used to fall through to the list
                // branch, which drew an empty card with no spinner, no message
                // and no way to try again. `errorMessage` was never rendered.
                if (state.status == HistoryStatus.failure)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppToast(
                            faceState: FaceState.worried,
                            message:
                                state.errorMessage ??
                                LocaleKeys.history_load_failed.tr(),
                          ),
                          const SizedBox(height: 10),
                          AppButton(
                            label: LocaleKeys.history_retry_button.tr(),
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            isFullWidth: true,
                            onPressed: () => unawaited(
                              context.read<HistoryCubit>().refresh(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // A refresh keeps the list that is already on screen. Only a
                // first load, with nothing grouped yet, says "loading".
                else if (isFirstLoad)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(child: _LoadingSheet()),
                  )
                else if (state.isEmptyAfterFilter)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(
                      child: AppEmptyState(
                        title: LocaleKeys.history_empty_filtered_title.tr(),
                        description: LocaleKeys.history_empty_filtered_body
                            .tr(),
                        buttonLabel: LocaleKeys.history_filter_reset.tr(),
                        onButtonPressed: () =>
                            context.read<HistoryCubit>().clearFilter(),
                        showFace: false,
                        isLive: false,
                      ),
                    ),
                  )
                else if (state.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(
                      child: AppEmptyState(
                        title: LocaleKeys.history_empty_title.tr(),
                        description: state.shownDays < HistoryWindow.paidDays
                            ? LocaleKeys.history_empty_body_free.tr(
                                namedArgs: {'days': '${state.shownDays}'},
                              )
                            : LocaleKeys.history_empty_body.tr(),
                        showFace: false,
                        isLive: false,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(
                      child: AppInboxSheet(
                        children: [
                          for (final day in state.days)
                            _DaySection(
                              day: day,
                              selectedId: size.isExpanded
                                  ? _selected?.id
                                  : null,
                              onTap: (entry) {
                                if (size.isExpanded) {
                                  AppHaptics.selection();
                                  setState(() => _selected = entry);
                                } else {
                                  primeTopicCanvas(context, entry.topic);
                                  unawaited(
                                    context.push(
                                      '/history/topics/${entry.topic}',
                                    ),
                                  );
                                }
                              },
                            ),
                          if (state.olderCount > 0)
                            _OlderAlarmsFooter(count: state.olderCount),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One day: its heading, then its alarms with a hairline between them.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.selectedId,
    required this.onTap,
  });

  final HistoryDay day;
  final String? selectedId;
  final void Function(HistoryEntry entry) onTap;

  static String _markLabel(HistoryMark mark) => switch (mark) {
    HistoryMark.answered => LocaleKeys.history_hero_mark_answered.tr(),
    HistoryMark.notAnswered => LocaleKeys.history_hero_mark_not_answered.tr(),
    HistoryMark.ringing => LocaleKeys.history_hero_mark_ringing.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeader(
          _dayLabel(day.day),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        ),
        for (var i = 0; i < day.entries.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ColoredBox(
                color: colors.hairline,
                child: const SizedBox(height: 1),
              ),
            ),
          Builder(
            builder: (context) {
              final entry = day.entries[i];
              final mark = historyMarkFor(entry.state);
              return HistoryRow(
                name: entry.topic,
                meta: historyMetaText(entry),
                time: DateFormat.Hm().format(entry.startedAt),
                mark: mark,
                markLabel: _markLabel(mark),
                isSelected: entry.id == selectedId,
                onTap: () => onTap(entry),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Placeholder rows while the first read has not finished.
class _LoadingSheet extends StatelessWidget {
  const _LoadingSheet();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: LocaleKeys.history_loading_title.tr(),
      child: ExcludeSemantics(
        child: AppInboxSheet(
          children: [
            for (var i = 0; i < 3; i++)
              const AppSkeleton(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      AppSkeletonBone(
                        width: HistoryMarkBadge.size,
                        height: HistoryMarkBadge.size,
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonBone.text(width: 120),
                            SizedBox(height: 8),
                            AppSkeletonBone.text(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One quiet line under the last alarm on the free tier: the phone is holding
/// older alarms that this plan does not show (api.md §4.2). Nothing was
/// deleted, so buying Pro puts them back on screen with no download. Tapping
/// opens the paywall.
class _OlderAlarmsFooter extends StatelessWidget {
  const _OlderAlarmsFooter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s1, bottom: Spacing.s2),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () {
            AppHaptics.selection();
            unawaited(
              openPaywallForFeature(
                context,
                AppFeature.longHistory,
                LockSource.historyOlder,
              ),
            );
          },
          child: Text(
            LocaleKeys.history_older_notice.plural(count),
            style: AppTypography.small(context.appColors.ink3, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Opens the filter sheet, with a dot on it while a filter is on so the state
/// is visible without opening the sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.filter});

  final HistoryFilter filter;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    final chosen = await showHistoryFilterSheet(
      context,
      filter,
      shownDays: cubit.state.shownDays,
    );
    if (chosen != null) cubit.applyFilter(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          glyph: GlyphType.filter,
          // The dot is colour only, so the label carries it too.
          ariaLabel: filter.isActive
              ? LocaleKeys.history_filter_active_aria_label.tr()
              : LocaleKeys.history_filter_aria_label.tr(),
          onPressed: () => unawaited(_open(context)),
        ),
        if (filter.isActive)
          Positioned(
            top: 2,
            right: 2,
            child: IgnorePointer(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.highlight,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.canvas, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The right pane on an expanded display: one picked incident, full detail.
class _IncidentDetail extends StatelessWidget {
  const _IncidentDetail({required this.entry, super.key});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaceWidget(state: entry.faceState, size: 96),
          const SizedBox(height: Spacing.s4),
          Text(
            entry.topic,
            style: AppTypography.monoBold(colors.ink, fontSize: 22),
          ),
          const SizedBox(height: Spacing.s2),
          Text(historyMetaText(entry), style: AppTypography.small(colors.ink3)),
          const SizedBox(height: Spacing.s4),
          AppKeyValueRow(
            label: LocaleKeys.history_detail_started_label.tr(),
            value: DateFormat.Hm().format(entry.startedAt),
          ),
          const SizedBox(height: 10),
          AppKeyValueRow(
            label: LocaleKeys.history_detail_ring_label.tr(),
            value: formatRingDuration(entry.ringDuration ?? Duration.zero),
          ),
        ],
      ),
    );
  }
}

/// "Tuesday 9 September", or "Today, Tuesday 9 September" when [day] is
/// today.
String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // intl already knows the weekday and month names for the active locale.
  final formatted = DateFormat('EEEE d MMMM').format(day);

  if (day == today) {
    return LocaleKeys.history_day_today.tr(namedArgs: {'date': formatted});
  }
  return formatted;
}
