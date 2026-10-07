import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/reliability_groups.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/reliability/presentation/widgets/reliability_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Settings, "Will it wake me?": one overall state with a face, then a row for
/// each check, the ones that need attention first, then the test alarm, then
/// the extra groups.
///
/// What to draw comes from `ReliabilityCubit`. Which rows, in what order, with
/// which words, is decided by the pure functions in `reliability_rows.dart`.
///
/// To add a row for a new check: add the id to `ReliabilityCheckIds`, add its
/// source to the list in `di.dart`, then give it a title and its reason lines
/// in `reliability_rows.dart` and the strings. Until the words exist, the row
/// still draws, with the id as its title. Nothing here knows the list of
/// checks: the order, the face and the one primary button all come from each
/// check's state, reason and fix, so a check from a new source sorts and
/// draws like the rest.
///
/// To add a group of rows: append one to `reliabilityExtraGroups`. A group
/// that draws a check of its own names the check's id, and the screen then
/// draws no plain row for it (`reliabilityScreenLayout`).
class ReliabilityScreen extends StatelessWidget {
  const ReliabilityScreen({
    this.extraGroups = reliabilityExtraGroups,
    super.key,
  });

  final List<ReliabilityGroup> extraGroups;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ReliabilityCubit>(),
      child: _ReliabilityView(
        extraGroups: extraGroups,
        runner: getIt<ReliabilityFixRunner>(),
      ),
    );
  }
}

class _ReliabilityView extends StatefulWidget {
  const _ReliabilityView({required this.extraGroups, required this.runner});

  final List<ReliabilityGroup> extraGroups;
  final ReliabilityFixRunner runner;

  @override
  State<_ReliabilityView> createState() => _ReliabilityViewState();
}

class _ReliabilityViewState extends State<_ReliabilityView>
    with WidgetsBindingObserver {
  /// Checks whose fix is running, so their button shows progress.
  final Set<ReliabilityCheckId> _busy = {};

  /// Checks whose entry is being closed.
  final Set<ReliabilityCheckId> _clearing = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from a system settings page is the usual way a fix ends.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<ReliabilityCubit>().refresh();
  }

  Future<void> _runFix(ReliabilityCheck check) async {
    final fix = check.fix;
    if (fix == null) return;
    AppHaptics.capture();
    // A fix that opens a screen of the app is the screen's to run.
    final routeName = switch (fix) {
      OpenRouteFix(:final routeName) => routeName,
      MissedAlarmFix(:final testRouteName) => testRouteName,
      // The prompt screen the permissions screen opens for a permission
      // that was never asked.
      AskPermissionFix() => AppRoute.askPermissions,
      OpenSystemSettingsFix() || RunFix() => null,
    };
    if (routeName != null) {
      await context.pushNamed<void>(routeName);
      await _refresh();
      return;
    }
    setState(() => _busy.add(check.id));
    try {
      await widget.runner.run(fix);
    } finally {
      if (mounted) setState(() => _busy.remove(check.id));
    }
    await _refresh();
  }

  /// Closes a missed alarm's entry. It writes the one record Home's notice
  /// writes when it is closed, so the entry goes from both.
  Future<void> _clear(ReliabilityCheck check) async {
    final fix = check.fix;
    if (fix is! MissedAlarmFix || _clearing.contains(check.id)) return;
    AppHaptics.capture();
    setState(() => _clearing.add(check.id));
    try {
      await getIt<MissedAlarmReader>().dismiss(fix.incidentIds);
    } finally {
      if (mounted) setState(() => _clearing.remove(check.id));
    }
    await _refresh();
  }

  /// What a tap on the row itself does, or null for a plain display.
  VoidCallback? _onRowTap(ReliabilityCheck check) =>
      switch (reliabilityRowTarget(check.id)) {
        ReliabilityRowTarget.none => null,
        ReliabilityRowTarget.permissions => () => unawaited(
          _open(AppRoute.devicePermissions),
        ),
        ReliabilityRowTarget.makerGuide => () => unawaited(
          _open(AppRoute.makerGuide),
        ),
      };

  Future<void> _open(String routeName) async {
    await context.pushNamed<void>(routeName);
    await _refresh();
  }

  Future<void> _openTest() async {
    await context.pushNamed<void>(AppRoute.testRing);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReliabilityCubit, ReliabilitySnapshot>(
      builder: (context, snapshot) {
        final headline = reliabilityHeadline(snapshot);
        final view = reliabilityHeadlineView(headline);
        final isLoading = headline == ReliabilityHeadline.loading;
        final ordered = orderReliabilityChecks(snapshot.checks);
        // A check a group draws gets no plain row, and its group moves up
        // to the check's place while it needs attention.
        final layout = reliabilityScreenLayout(ordered, [
          for (final group in widget.extraGroups) group.checkId,
        ]);
        final now = DateTime.now();

        return AppScreenScaffold(
          onRefresh: _refresh,
          // The bar has one fixed height, so its text stops growing at the
          // chrome limit instead of being cut off by it.
          topBar: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: kChromeMaxTextScale),
            ),
            child: AppTopBar(
              title: LocaleKeys.reliability_title.tr(),
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.reliability_back_aria_label.tr(),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/settings');
                  }
                },
              ),
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.only(top: Spacing.s6),
                      child: AppWaitingFace(
                        message: LocaleKeys.reliability_loading.tr(),
                      ),
                    )
                  : AppStage(
                      faceState: view.face,
                      faceSize: 104,
                      wordFontSize: 34,
                      word: view.wordKey.tr(),
                      sub: view.lineKey.tr(),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 16),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLoading)
                        for (final row in layout.rows) ...[
                          if (row.group case final group?)
                            _group(context, snapshot, group, row)
                          else
                            ReliabilityRow(
                              check: row.check,
                              face: reliabilityRowFace(row.check),
                              now: now,
                              actionLabel: _actionLabel(row.check),
                              // One primary button on the screen: the
                              // first row with something to do.
                              actionVariant: row.isPrimary
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.ghost,
                              isBusy: _busy.contains(row.check.id),
                              onAction: () => unawaited(_runFix(row.check)),
                              clearLabel: reliabilityClearLabelKey(
                                row.check.fix,
                              )?.tr(),
                              isClearing: _clearing.contains(row.check.id),
                              onClear: () => unawaited(_clear(row.check)),
                              onTap: _onRowTap(row.check),
                            ),
                          const SizedBox(height: 8),
                        ],
                      // The free test comes before anything that costs
                      // money.
                      ReliabilityTestRow(onTap: () => unawaited(_openTest())),
                      if (!isLoading)
                        for (final below in layout.below) ...[
                          const SizedBox(height: 8),
                          _group(context, snapshot, below.group, null),
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

  /// One group, keyed by its position so it keeps its state when it moves
  /// between its place in the list and its place under the test row.
  Widget _group(
    BuildContext context,
    ReliabilitySnapshot snapshot,
    int index,
    ReliabilityListRow? row,
  ) => KeyedSubtree(
    key: ValueKey('reliability_group_$index'),
    child: widget.extraGroups[index].builder(
      context,
      snapshot,
      check: row?.check,
      isPrimary: row?.isPrimary ?? false,
    ),
  );

  String? _actionLabel(ReliabilityCheck check) {
    final fix = check.fix;
    if (fix == null) return null;
    return reliabilityFixLabelKey(fix, testRouteName: AppRoute.testRing).tr();
  }
}
