import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
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

        return AppScreenScaffold(
          onRefresh: () => context.read<HistoryCubit>().refresh(),
          topBar: AppTopBar(
            title: LocaleKeys.history_title.tr(),
            trailing: _FilterButton(filter: state.filter),
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
                  AppStage.horizontal(
                    faceState: FaceState.acked,
                    sub: summary,
                  ),
                  const SizedBox(height: Spacing.s3),
                ],
              ),
            ),
            if (state.isEmptyAfterFilter)
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
                                  size.isExpanded && entry.id == _selected?.id,
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
                                    context.push('/topics/${entry.topic}'),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
          ariaLabel: LocaleKeys.history_filter_aria_label.tr(),
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
