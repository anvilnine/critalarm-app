import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/design.dart';
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

class _HistoryScreenContent extends StatelessWidget {
  const _HistoryScreenContent();

  @override
  Widget build(BuildContext context) {
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
                              faceState: entry.faceState,
                              timeText: DateFormat.Hm().format(
                                entry.startedAt,
                              ),
                              onTap: () =>
                                  context.push('/topics/${entry.topic}'),
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
