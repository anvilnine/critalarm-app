import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/format/date_label.dart';
import 'package:critalarm/core/format/number_format.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/history/presentation/history_pane.dart';
import 'package:critalarm/features/history/presentation/widgets/history_filter_sheet.dart';
import 'package:critalarm/features/history/presentation/widgets/history_hero.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/topics/presentation/pane_rules.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_hero_parts.dart';
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
  /// The incident the person tapped. Null until then, and the pane shows
  /// [_openedId]. See [historyPaneEntry].
  String? _pickedId;

  /// The incident the pane opened on while nothing is picked: the newest,
  /// held while it is listed.
  String? _openedId;

  @override
  Widget build(BuildContext context) {
    // Book posture shows the pane at any width, tabletop shows none.
    final showsDetail = AppScreenScaffold.showsDetail(context);

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
        final selected = historyPaneEntry(
          state.days,
          _pickedId,
          openedId: _openedId,
        );
        if (_pickedId == null) _openedId = selected?.id;
        final hasDetail = !state.isEmpty;
        // On a fold the hero holds still in its own pane and only the list
        // scrolls. Read off the window: inside the stage the fold is gone.
        final fold = AppFold.of(context);
        final heroOnStage =
            hasHero && heroOnFoldStage(fold, hasDetail: hasDetail);
        // The top half of a tabletop fold is short: the face goes beside
        // the card there, at 120, rather than on top of it.
        final isBeside = heroOnStage && fold.isTabletop;
        // A cover screen trims the room around the hero so two rows fit
        // above the tab bar.
        final isCover = AppSize.of(context).isCover;
        final hero = Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            isCover ? Spacing.s2 : Spacing.s3,
            12,
            isCover ? Spacing.s3 : Spacing.s4,
          ),
          child: hasHero
              ? HistoryHero(
                  week: week,
                  isFiltered: state.filter.isActive,
                  isBeside: isBeside,
                )
              : const SizedBox(height: Spacing.s2),
        );

        // The canvas behind the screen is the ambient one. It gets the disc
        // behind the face, and morphs to the next tab's profile on a change.
        return AmbientRouteProfile(
          path: '/history',
          profile: AmbientAppProfiles.historyHero(
            context.appColors,
            spot: historyDiscSpotOf(
              context,
              onStage: heroOnStage,
              isBeside: isBeside,
            ),
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
                // The filter button is a 40 circle in a 48 tap box.
                trailingTapRoom: AppIconButton.tapRoom(40),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RefreshActivityIndicator(),
                    const SizedBox(width: 8),
                    _FilterButton(filter: state.filter),
                  ],
                ),
              ),
              foldStage: heroOnStage ? FoldStageColumn(children: [hero]) : null,
              detail: !hasDetail
                  ? null
                  : selected == null
                  ? AppEmptyState(
                      title: LocaleKeys.history_detail_empty_title.tr(),
                      description: LocaleKeys.history_detail_empty_body.tr(),
                    )
                  : _IncidentDetail(
                      key: ValueKey(selected.id),
                      entry: selected,
                      face: paneFaceFor(
                        selected.faceState,
                        hero: hasHero ? week.face : null,
                      ),
                    ),
              slivers: [
                SliverToBoxAdapter(
                  child: heroOnStage
                      ? const SizedBox(height: Spacing.s3)
                      : hero,
                ),
                // Loading and failure both used to fall through to the list
                // branch, which drew an empty card with no spinner, no message
                // and no way to try again. `errorMessage` was never rendered.
                if (state.status == HistoryStatus.failure)
                  SliverPadding(
                    // 6 less than the 16 it was, for the retry tap box.
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
                          // 6 less than the 10 it was, for the same box.
                          const SizedBox(height: 4),
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
                              selectedId: showsDetail ? selected?.id : null,
                              onTap: (entry) {
                                if (showsDetail) {
                                  AppHaptics.selection();
                                  setState(() => _pickedId = entry.id);
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
                time: DateFormat.Hm(
                  currentFormatLocale(),
                ).format(entry.startedAt),
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
    // The line is 12 high. Its tap box is 48 high from the top of the line,
    // so the line stays where it was and the room is under it, at the end of
    // the list where nothing waits for it.
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s1),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: kMinTapTarget,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                LocaleKeys.history_older_notice.plural(count),
                style: AppTypography.small(
                  context.appColors.ink3,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
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
          // 4 more than the 2 it was: the button's box reaches 4 past its
          // circle, and the dot sits on the circle.
          Positioned(
            top: 6,
            right: 6,
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
  const _IncidentDetail({
    required this.entry,
    required this.face,
    super.key,
  });

  final HistoryEntry entry;

  /// How the incident ended, or null when the hero beside the pane already
  /// shows that face. See [paneFaceFor].
  final FaceState? face;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // How the incident ended, at the hero size, unless the hero
          // already wears that face.
          if (face case final face?) ...[
            FaceWidget(state: face),
            const SizedBox(height: Spacing.s4),
          ],
          Text(
            entry.topic,
            style: AppTypography.monoBold(colors.ink, fontSize: 22),
          ),
          const SizedBox(height: Spacing.s2),
          Text(historyMetaText(entry), style: AppTypography.small(colors.ink3)),
          const SizedBox(height: Spacing.s4),
          AppKeyValueRow(
            label: LocaleKeys.history_detail_started_label.tr(),
            value: DateFormat.Hm(currentFormatLocale()).format(entry.startedAt),
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
  final formatted = DateLabel.weekdayDayMonth(day);

  if (day == today) {
    return LocaleKeys.history_day_today.tr(namedArgs: {'date': formatted});
  }
  return formatted;
}
