import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What the first row on Settings says: the overall state of the reliability
/// checks, with the face and line the Reliability screen opens with.
///
/// It lives apart from the widget so it can be unit tested.
@immutable
class SettingsReliabilityRow {
  const SettingsReliabilityRow._({
    required this.headline,
    required this.faceState,
    required this.subtitleKey,
    required this.issueCount,
  });

  factory SettingsReliabilityRow.from(ReliabilitySnapshot snapshot) {
    final headline = reliabilityHeadline(snapshot);
    final view = reliabilityHeadlineView(headline);
    return SettingsReliabilityRow._(
      headline: headline,
      faceState: view.face,
      subtitleKey: view.lineKey,
      issueCount: headline == ReliabilityHeadline.loading
          ? 0
          : reliabilityIssueCount(snapshot.checks),
    );
  }

  final ReliabilityHeadline headline;
  final FaceState faceState;

  /// A `LocaleKeys` key for the one line under the title.
  final String subtitleKey;

  /// Checks that are not fine. The row shows a count while it is above zero.
  final int issueCount;

  bool get hasIssues => issueCount > 0;
}

/// The Settings row that opens the Reliability screen. It reads the overall
/// state from `ReliabilityCubit` and asks it to read again when Settings
/// opens, when the app comes back to the front and when the screen is closed.
class SettingsReliabilityEntry extends StatefulWidget {
  const SettingsReliabilityEntry({super.key});

  @override
  State<SettingsReliabilityEntry> createState() =>
      _SettingsReliabilityEntryState();
}

class _SettingsReliabilityEntryState extends State<SettingsReliabilityEntry>
    with WidgetsBindingObserver {
  final ReliabilityCubit _cubit = getIt<ReliabilityCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cubit.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<ReliabilityCubit, ReliabilitySnapshot>(
      bloc: _cubit,
      builder: (context, snapshot) {
        final row = SettingsReliabilityRow.from(snapshot);
        return AppListRow(
          name: LocaleKeys.reliability_title.tr(),
          meta: row.subtitleKey.tr(),
          faceState: row.faceState,
          // The title is the question this package answers, so it may take
          // two lines instead of being cut at large text sizes.
          nameMaxLines: 2,
          // The chip and the arrow narrow the text column at large sizes, so
          // the line under the title gets a third line rather than a cut.
          metaMaxLines: 3,
          // The count chip sits before the arrow, never in its place: the
          // arrow is what says the row opens a screen.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (row.hasIssues) ...[
                _IssuesChip(count: row.issueCount),
                const SizedBox(width: 8),
              ],
              AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
            ],
          ),
          onTap: () async {
            await context.push<void>('/settings/reliability');
            if (!_cubit.isClosed) await _cubit.refresh();
          },
        );
      },
    );
  }
}

/// A dot and the number of checks that are not fine. Only the number, so the
/// title keeps its room. A screen reader gets the words.
class _IssuesChip extends StatelessWidget {
  const _IssuesChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: LocaleKeys.settings_health_badge_issues.plural(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26, minWidth: 26),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.high,
          borderRadius: Radii.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.inkFixed,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
                color: colors.inkFixed,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
