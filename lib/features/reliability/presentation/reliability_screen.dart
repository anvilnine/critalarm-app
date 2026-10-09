import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/reliability/domain/attention_order.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/domain/wake_answer.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/proof_card.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/reliability/presentation/wake_header.dart';
import 'package:critalarm/features/reliability/presentation/wake_path.dart';
import 'package:critalarm/features/reliability/presentation/wake_problem_list.dart';
import 'package:critalarm/features/reliability/presentation/widgets/reliability_row.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/widgets/weekly_check_group.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Settings, "Will it wake me?": one word (Yes, Maybe or No) with a line and
/// the face, the path an alarm takes with the stop that is not fine in red,
/// then either one chip (every check passes) or a white list of what to fix
/// with a folded row for the checks that pass, then the dark proof card with
/// the last eight weeks and the weekly delivery check. One button is pinned
/// at the bottom.
///
/// The bar's title shows only once the header has scrolled under the bar. At
/// rest the header's own label says the same thing.
///
/// What to draw comes from `ReliabilityCubit`. The word, the path and the
/// numbers they are drawn from are the pure functions in
/// `domain/wake_answer.dart`. Which rows, in what order, with which words, is
/// decided by the pure functions in `reliability_rows.dart`.
///
/// To add a row for a new check: add the id to `ReliabilityCheckIds`, add its
/// source to the list in `di.dart`, then give it a title and its reason lines
/// in `reliability_rows.dart` and the strings. Until the words exist, the row
/// still draws, with the id as its title. Give it a stop on the path in
/// `wakeStopOf`, or it sits on This phone. Nothing here knows the list of
/// checks: the order, the word and the pinned button all come from each
/// check's state, reason and fix, so a check from a new source sorts and
/// draws like the rest.
///
/// The weekly delivery check is a check like the others when it needs a look:
/// it has a row in the list with its fix. Its switch lives in the proof card.
class ReliabilityScreen extends StatelessWidget {
  const ReliabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ReliabilityCubit>(),
      child: _ReliabilityView(runner: getIt<ReliabilityFixRunner>()),
    );
  }
}

class _ReliabilityView extends StatefulWidget {
  const _ReliabilityView({required this.runner});

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

  final ScrollController _scroll = ScrollController();

  /// When the newest test alarm or weekly check rang on this phone, for the
  /// line under Yes. Null when none ever did.
  DateTime? _lastTestAt;
  StreamSubscription<void>? _proofChanges;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readLastTest();
    _proofChanges = getIt<ProofLog>().changes.listen((_) => _readLastTest());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_proofChanges?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from a system settings page is the usual way a fix ends.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    _readLastTest();
    await context.read<ReliabilityCubit>().refresh();
  }

  void _readLastTest() {
    try {
      final at = getIt<ProofLog>().newestRangAt();
      if (at != _lastTestAt) {
        if (mounted) setState(() => _lastTestAt = at);
      }
    } on Object {
      // The line then nudges to ring a test, which is true enough.
    }
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
    // The weekly check's row in the card reads the relay's answer again.
    if (check.id == WeeklyCheckSource.id) {
      await getIt<WeeklyCheckCubit>().load(force: true);
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
        final isLoading = !snapshot.loaded;
        final ordered = orderReliabilityChecks(snapshot.checks);
        // Every check has its own row. The weekly delivery check's switch is
        // in the proof card, so no group draws it here.
        final layout = reliabilityScreenLayout(ordered, const []);
        final now = DateTime.now();
        final split = splitReliabilityRows(layout.rows);
        final answer = wakeAnswerForSnapshot(
          snapshot.checks,
          incomplete: snapshot.incomplete,
        );
        final line = wakeLineFor(
          snapshot.checks,
          incomplete: snapshot.incomplete,
          now: now,
          lastTestAt: _lastTestAt,
        );
        final stops = wakePathFor(snapshot.checks);
        final passCount = split.calm.length;

        return AppScreenScaffold(
          hasTabBar: false,
          onRefresh: _refresh,
          // The bar has one fixed height, so its text stops growing at the
          // chrome limit instead of being cut off by it.
          scrollController: _scroll,
          topBar: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: kChromeMaxTextScale),
            ),
            child: AppTopBar(
              titleWidget: _BarTitle(
                controller: _scroll,
                title: LocaleKeys.reliability_title.tr(),
              ),
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
          bottomBar: _bottomBar(context, ordered),
          slivers: [
            SliverToBoxAdapter(
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.only(top: Spacing.s6),
                      child: AppWaitingFace(
                        message: LocaleKeys.reliability_loading.tr(),
                      ),
                    )
                  : WakeClock(
                      builder: (context, clock, {required isStill}) => Stack(
                        // The disc runs up behind the top bar and off the
                        // right edge. It is first, so it is behind the rest.
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -150,
                            top: -40,
                            child: IgnorePointer(
                              child: WakeDisc(
                                answer: answer,
                                clock: clock,
                                isStill: isStill,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: Spacing.s2),
                              WakeHeader(
                                answer: answer,
                                line: wakeLineText(line),
                                clock: clock,
                                isStill: isStill,
                              ),
                              const SizedBox(height: Spacing.s5),
                              WakePath(
                                stops: stops,
                                clock: clock,
                                isStill: isStill,
                              ),
                              const SizedBox(height: Spacing.s4),
                              if (split.attention.isEmpty)
                                if (passCount > 0)
                                  WakeAllPassChip(count: passCount)
                                else
                                  const SizedBox.shrink()
                              else
                                WakeProblemList(
                                  problems: [
                                    for (final row in split.attention)
                                      _problem(context, row, now),
                                  ],
                                  passing: [
                                    for (final row in split.calm)
                                      _row(context, row, now),
                                  ],
                                  passCount: passCount,
                                ),
                              const SizedBox(height: Spacing.s3),
                              ProofCard(
                                log: getIt<ProofLog>(),
                                weeklyCheck: const WeeklyCheckCardRow(),
                              ),
                              // The way to the weekly check's past rounds,
                              // once the relay has sent this phone a check.
                              const WeeklyCheckRoundsLink(),
                              const SizedBox(height: Spacing.s4),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// The one button pinned at the bottom.
  ///
  /// - Nothing to fix: ring a test.
  /// - One thing with a fix: that fix, in its own words.
  /// - Several: "Fix N things", which runs the first fix in attention
  ///   order. The screen refreshes when it ends, and the next tap takes the
  ///   next one.
  Widget _bottomBar(BuildContext context, List<ReliabilityCheck> ordered) {
    final fixable = [
      for (final check in ordered)
        if (needsAttention(check.state) && check.fix != null) check,
    ];
    final String label;
    final VoidCallback onPressed;
    var isBusy = false;
    if (fixable.isEmpty) {
      label = LocaleKeys.reliability_ring_test_title.tr();
      onPressed = () => unawaited(_openTest());
    } else if (fixable.length == 1) {
      final only = fixable.first;
      label = _actionLabel(only) ?? LocaleKeys.reliability_ring_test_title.tr();
      isBusy = _busy.contains(only.id);
      onPressed = () => unawaited(_runFix(only));
    } else {
      final first = fixable.first;
      label = LocaleKeys.wake_fix_many.tr(
        namedArgs: {'count': '${fixable.length}'},
      );
      isBusy = _busy.contains(first.id);
      onPressed = () => unawaited(_runFix(first));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: AppButton(
        label: label,
        size: AppButtonSize.lg,
        isFullWidth: true,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
    );
  }

  /// One problem in the white list.
  Widget _problem(BuildContext context, ReliabilityListRow row, DateTime now) {
    final check = row.check;
    return WakeProblemRow(
      check: check,
      now: now,
      actionLabel: _actionLabel(check),
      isBusy: _busy.contains(check.id),
      onAction: () => unawaited(_runFix(check)),
      clearLabel: reliabilityClearLabelKey(check.fix)?.tr(),
      isClearing: _clearing.contains(check.id),
      onClear: () => unawaited(_clear(check)),
      onTap: _onRowTap(check),
    );
  }

  /// One row of a check that passes.
  Widget _row(BuildContext context, ReliabilityListRow row, DateTime now) {
    return ReliabilityRow(
      check: row.check,
      now: now,
      actionLabel: _actionLabel(row.check),
      actionVariant: AppButtonVariant.ghost,
      isBusy: _busy.contains(row.check.id),
      onAction: () => unawaited(_runFix(row.check)),
      clearLabel: reliabilityClearLabelKey(row.check.fix)?.tr(),
      isClearing: _clearing.contains(row.check.id),
      onClear: () => unawaited(_clear(row.check)),
      onTap: _onRowTap(row.check),
    );
  }

  String? _actionLabel(ReliabilityCheck check) {
    final fix = check.fix;
    if (fix == null) return null;
    return reliabilityFixLabelKey(fix, testRouteName: AppRoute.testRing).tr();
  }
}

/// The bar's title. It is clear while the header sits under the bar with its
/// own label, and comes in once the header has scrolled up under the bar. It
/// follows the scroll position, so reduced motion has nothing to turn off.
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.controller, required this.title});

  final ScrollController controller;
  final String title;

  /// The scroll distance over which the title comes in. The header label
  /// is under the bar a little after the first.
  static const double _from = 12;
  static const double _span = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final shown = ((offset - _from) / _span).clamp(0.0, 1.0);
        return ExcludeSemantics(
          excluding: shown < 1,
          child: Semantics(
            header: true,
            child: Opacity(
              opacity: shown,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headline(
                  colors.onCanvas,
                  fontSize: 18,
                ).copyWith(letterSpacing: -0.02 * 18),
              ),
            ),
          ),
        );
      },
    );
  }
}
