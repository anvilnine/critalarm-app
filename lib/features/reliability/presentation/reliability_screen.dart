import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
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
/// each check, the ones that need attention first, then the test alarm.
///
/// What to draw comes from `ReliabilityCubit`. Which rows, in what order, with
/// which words, is decided by the pure functions in `reliability_rows.dart`.
///
/// To add a row for a new check: add the id to `ReliabilityCheckIds`, add its
/// source to the list in `di.dart`, then give it a title and its reason lines
/// in `reliability_rows.dart` and the strings. Until the words exist, the row
/// still draws, with the id as its title.
///
/// To add a group of rows: append a builder to `reliabilityExtraGroups`.
class ReliabilityScreen extends StatelessWidget {
  const ReliabilityScreen({
    this.extraGroups = reliabilityExtraGroups,
    super.key,
  });

  final List<ReliabilityGroupBuilder> extraGroups;

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

  final List<ReliabilityGroupBuilder> extraGroups;
  final ReliabilityFixRunner runner;

  @override
  State<_ReliabilityView> createState() => _ReliabilityViewState();
}

class _ReliabilityViewState extends State<_ReliabilityView>
    with WidgetsBindingObserver {
  /// Checks whose fix is running, so their button shows progress.
  final Set<ReliabilityCheckId> _busy = {};

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
    if (fix is OpenRouteFix) {
      await context.pushNamed<void>(fix.routeName);
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

  Future<void> _openPermissions() async {
    await context.push<void>('/settings/permissions');
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
        final faces = reliabilityRowFaces(ordered);

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
                      if (!isLoading) ...[
                        for (var i = 0; i < ordered.length; i++) ...[
                          ReliabilityRow(
                            check: ordered[i],
                            face: faces[i],
                            actionLabel: _actionLabel(ordered[i]),
                            isBusy: _busy.contains(ordered[i].id),
                            onAction: () => unawaited(_runFix(ordered[i])),
                            onTap: isPermissionCheck(ordered[i].id)
                                ? () => unawaited(_openPermissions())
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                        for (final group in widget.extraGroups) ...[
                          group(context, snapshot),
                          const SizedBox(height: 8),
                        ],
                      ],
                      ReliabilityTestRow(onTap: () => unawaited(_openTest())),
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

  String? _actionLabel(ReliabilityCheck check) {
    final fix = check.fix;
    if (fix == null) return null;
    return reliabilityFixLabelKey(fix, testRouteName: AppRoute.testRing).tr();
  }
}
