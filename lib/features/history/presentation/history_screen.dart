import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
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
        final summary = longest == null
            ? LocaleKeys.history_summary_empty.tr()
            : LocaleKeys.history_summary.plural(
                state.alarmCount,
                namedArgs: {'longest': _formatRingDuration(longest)},
              );

        return AppScreenScaffold(
          onRefresh: () => context.read<HistoryCubit>().refresh(),
          topBar: AppTopBar(
            title: LocaleKeys.history_title.tr(),
            trailing: AppIconButton(
              glyph: GlyphType.filter,
              ariaLabel: LocaleKeys.history_filter_aria_label.tr(),
              // Filtering is not wired up yet.
              onPressed: () {},
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
              child: AppStage.horizontal(
                faceState: FaceState.acked,
                sub: summary,
              ),
            ),
            if (state.isEmpty)
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
                              meta: _metaText(entry),
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
          Text(_metaText(entry), style: AppTypography.small(colors.ink3)),
          const SizedBox(height: Spacing.s4),
          AppKeyValueRow(
            label: LocaleKeys.history_detail_started_label.tr(),
            value: DateFormat.Hm().format(entry.startedAt),
          ),
          const SizedBox(height: 10),
          AppKeyValueRow(
            label: LocaleKeys.history_detail_ring_label.tr(),
            value: _formatRingDuration(entry.ringDuration ?? Duration.zero),
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

/// "6 min 02 s", or just "44 s" under a minute.
String _formatRingDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;

  if (minutes <= 0) return '$seconds s';
  return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
}

String _metaText(HistoryEntry entry) {
  final duration = _formatRingDuration(entry.ringDuration ?? Duration.zero);
  final key = switch (entry.state) {
    IncidentState.acked => LocaleKeys.history_meta_acknowledged,
    IncidentState.closed => LocaleKeys.history_meta_resolved,
    IncidentState.expired => LocaleKeys.history_meta_expired,
    IncidentState.open => LocaleKeys.history_meta_open,
  };
  return key.tr(namedArgs: {'duration': duration});
}
