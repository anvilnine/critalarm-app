import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_rounds_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The weekly check rounds, newest first: each with a face, how it ended in
/// a few words, and when it opened. The list is the relay's, and reading it
/// needs no pack.
class WeeklyCheckRoundsScreen extends StatelessWidget {
  const WeeklyCheckRoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<WeeklyCheckRoundsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _RoundsView(),
    );
  }
}

class _RoundsView extends StatelessWidget {
  const _RoundsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<WeeklyCheckRoundsCubit, WeeklyCheckRoundsState>(
      builder: (context, state) {
        final cubit = context.read<WeeklyCheckRoundsCubit>();
        final rounds = state.rounds;
        final now = DateTime.now();
        return AppScreenScaffold(
          onRefresh: cubit.load,
          topBar: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: kChromeMaxTextScale),
            ),
            child: AppTopBar(
              title: LocaleKeys.weekly_check_rounds_title.tr(),
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.weekly_check_rounds_back.tr(),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/settings/reliability');
                  }
                },
              ),
            ),
          ),
          slivers: [
            if (rounds == null && !state.didFail)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Spacing.s6),
                  child: AppWaitingFace(
                    message: LocaleKeys.weekly_check_rounds_loading.tr(),
                  ),
                ),
              )
            else if (rounds == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s6, 12, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ExcludeSemantics(
                        child: FaceWidget(state: FaceState.confused, size: 80),
                      ),
                      const SizedBox(height: Spacing.s3),
                      Text(
                        LocaleKeys.weekly_check_rounds_failed.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.body(colors.onCanvas),
                      ),
                      const SizedBox(height: Spacing.s3),
                      AppButton(
                        label: LocaleKeys.weekly_check_rounds_retry.tr(),
                        size: AppButtonSize.sm,
                        onPressed: () => unawaited(cubit.load()),
                      ),
                    ],
                  ),
                ),
              )
            else if (rounds.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s6, 12, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ExcludeSemantics(
                        child: FaceWidget(state: FaceState.sleepy, size: 80),
                      ),
                      const SizedBox(height: Spacing.s3),
                      Text(
                        LocaleKeys.weekly_check_rounds_empty.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.body(colors.onCanvas),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 16),
                  child: AppSheet(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < rounds.length; i++) ...[
                          if (i > 0) const AppSectionDivider(),
                          _RoundRow(round: rounds[i], now: now),
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

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round, required this.now});

  final WeeklyCheckRound round;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final view = weeklyCheckRoundView(round, now: now);
    final isMiss =
        round.result == WeeklyCheckResult.missed ||
        round.result == WeeklyCheckResult.refused;
    final wordTime = view.wordTime;
    final word = wordTime == null
        ? view.wordKey.tr()
        : view.wordKey.tr(namedArgs: {'time': wordTime});
    final when = view.when;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ExcludeSemantics(child: FaceWidget(state: view.face, size: 28)),
            const SizedBox(width: Spacing.s3),
            Expanded(
              // The time drops under the word when the text is large, so
              // neither is cut.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.s3,
                runSpacing: Spacing.s1,
                children: [
                  Text(
                    word,
                    style: AppTypography.body(colors.ink, fontSize: 15)
                        .copyWith(
                          fontWeight: isMiss
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                  ),
                  if (when != null)
                    Text(when, style: AppTypography.mono(colors.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
