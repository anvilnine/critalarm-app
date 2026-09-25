import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/components/jumping_text.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/history/presentation/widgets/history_filter_sheet.dart';
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
        final longest = state.longestRing;
        final summary = state.filter.isActive
            // The unfiltered line reads "in 30 days", which a filter makes
            // untrue. Say what the filter is doing instead of lying.
            ? LocaleKeys.history_filter_badge.plural(state.filter.activeCount)
            : longest == null
            ? LocaleKeys.history_summary_empty.tr()
            : LocaleKeys.history_summary.plural(
                state.alarmCount,
                namedArgs: {'longest': formatRingDuration(longest)},
              );

        return NotificationListener<ScrollNotification>(
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
                    buttonLabel: null,
                  )
                : _IncidentDetail(
                    key: ValueKey(_selected?.id),
                    entry: _selected!,
                  ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: Spacing.s2),
                    _HistoryStage(summary: summary),
                    const SizedBox(height: Spacing.s3),
                  ],
                ),
              ),
              // Loading and failure both used to fall through to the list
              // branch, which drew an empty card with no spinner, no message
              // and no way to try again. `errorMessage` was never rendered.
              if (state.status == HistoryStatus.failure)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
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
              else if (state.isLoading && state.days.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  sliver: SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: LocaleKeys.history_loading_title.tr(),
                      description: '',
                      buttonLabel: null,
                    ),
                  ),
                )
              else if (state.isEmptyAfterFilter)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  sliver: SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: LocaleKeys.history_empty_filtered_title.tr(),
                      description: LocaleKeys.history_empty_filtered_body.tr(),
                      buttonLabel: LocaleKeys.history_filter_reset.tr(),
                      onButtonPressed: () =>
                          context.read<HistoryCubit>().clearFilter(),
                      isLive: false,
                    ),
                  ),
                )
              else if (state.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  sliver: SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: LocaleKeys.history_empty_title.tr(),
                      description: LocaleKeys.history_empty_body.tr(),
                      buttonLabel: null,
                      faceState: FaceState.calm,
                      isLive: false,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverToBoxAdapter(
                    child: AppSheet(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final day in state.days) ...[
                            AppSectionHeader(_dayLabel(day.day)),
                            for (final entry in day.entries) ...[
                              AppListRow(
                                name: entry.topic,
                                meta: historyMetaText(entry),
                                isSelected:
                                    size.isExpanded &&
                                    entry.id == _selected?.id,
                                faceState: entry.faceState,
                                timeText: DateFormat.Hm().format(
                                  entry.startedAt,
                                ),
                                onTap: () {
                                  if (size.isExpanded) {
                                    AppHaptics.selection();
                                    setState(() => _selected = entry);
                                  } else {
                                    unawaited(
                                      context.push(
                                        '/history/topics/${entry.topic}',
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (state.olderCount > 0)
                            _OlderAlarmsFooter(count: state.olderCount),
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
            unawaited(context.push('/paywall?source=history_older'));
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
/// The small face and summary line at the top of History. The face is too
/// small for its expression to carry a refresh alone, so while a pull to
/// refresh runs the line beside it says what is going on.
///
/// When the refresh ends, the result and the summary come in together as one
/// line ("Up to date. No alarms in the last 30 days."), then the result
/// leaves and the summary slides into place.
class _HistoryStage extends StatefulWidget {
  const _HistoryStage({required this.summary});

  final String summary;

  @override
  State<_HistoryStage> createState() => _HistoryStageState();
}

class _HistoryStageState extends State<_HistoryStage> {
  /// How long the result stays in front of the summary.
  static const Duration _resultHold = Duration(milliseconds: 1600);

  RefreshFaceController? _refresh;
  RefreshFacePhase _phase = RefreshFacePhase.idle;
  String? _result;
  Timer? _clearResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = RefreshFaceScope.maybeOf(context);
    if (refresh == _refresh) return;
    _refresh?.removeListener(_onRefresh);
    _refresh = refresh?..addListener(_onRefresh);
  }

  @override
  void dispose() {
    _refresh?.removeListener(_onRefresh);
    _clearResult?.cancel();
    super.dispose();
  }

  void _onRefresh() {
    final phase = _refresh!.phase;
    if (phase == _phase) return;
    _phase = phase;

    final result = switch (phase) {
      RefreshFacePhase.success => LocaleKeys.history_refresh_done.tr(),
      RefreshFacePhase.failed => LocaleKeys.history_refresh_failed.tr(),
      _ => null,
    };
    if (result != null) {
      _clearResult?.cancel();
      _clearResult = Timer(_resultHold, () {
        if (mounted) setState(() => _result = null);
      });
      setState(() => _result = result);
    } else if (phase == RefreshFacePhase.working) {
      _clearResult?.cancel();
      setState(() => _result = null);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_refresh == null) {
      return AppStage.horizontal(
        faceState: FaceState.acked,
        sub: widget.summary,
      );
    }

    final colors = context.appColors;
    final text = _phase == RefreshFacePhase.working
        ? LocaleKeys.history_refresh_checking.tr()
        : _result == null
        ? widget.summary
        : '$_result ${widget.summary}';

    return AppStage.horizontal(
      faceState: FaceState.acked,
      subWidget: JumpingText(
        text,
        style: AppStage.horizontalSubStyle(colors),
        gradient: [colors.cobalt, colors.crit, colors.high],
        wave: _phase == RefreshFacePhase.working,
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.filter});

  final HistoryFilter filter;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    final chosen = await showHistoryFilterSheet(context, filter);
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
