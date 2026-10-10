import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/widgets/reliability_row.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The way to the list of rounds: a plain row that only opens another
/// screen, so it has no face.
class WeeklyCheckRoundsRow extends StatelessWidget {
  const WeeklyCheckRoundsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = LocaleKeys.weekly_check_rounds_link.tr();
    return ReliabilityPlainRow(
      title: title,
      label: title,
      onTap: () =>
          unawaited(context.pushNamed<void>(AppRoute.weeklyCheckRounds)),
      trailing: AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
    );
  }
}

/// The decision the locked weekly check row is drawn from. The row is locked
/// while a Hosted purchase is still being confirmed, because the relay
/// refuses the check until then. So the lock drawn is the one for holding
/// nothing. A plan that could not be read sells nothing: its own answer
/// stands.
FeatureDecision _lockedWeeklyDecision(FeatureAccess access) {
  final decision = access.decide(AppFeature.weeklyCheck);
  return decision is FeatureConfirming
      ? access.decideHoldingNothing(AppFeature.weeklyCheck)
      : decision;
}

/// The weekly delivery check inside the dark proof card.
///
/// It draws the weekly check on the dark ground, by what `FeatureAccess`
/// answers for the feature:
///
/// - Hosted held: the title, a mono line with the next round and the real
///   switch. A tap the relay refused says why under the row.
/// - Hosted not held: the title, one line and a "See Hosted" button. There is
///   no switch. The button is the only thing in the row that opens the
///   paywall. Until the plan is read there is no button.
/// - A server of the user's own: one line saying the check is not available
///   there. No button and no paywall.
///
/// A check that needs a look is a row in the screen's list of problems, with
/// its own fix, so this row draws no chip and no fix button.
class WeeklyCheckCardRow extends StatefulWidget {
  const WeeklyCheckCardRow({super.key});

  @override
  State<WeeklyCheckCardRow> createState() => _WeeklyCheckCardRowState();
}

class _WeeklyCheckCardRowState extends State<WeeklyCheckCardRow> {
  StreamSubscription<AppFeature>? _accessChanges;

  @override
  void initState() {
    super.initState();
    unawaited(getIt<WeeklyCheckCubit>().load());
    // Gaining or losing Hosted, or moving to another kind of server,
    // changes whether the check counts.
    _accessChanges = getIt<FeatureAccess>().changes
        .where((feature) => feature == AppFeature.weeklyCheck)
        .listen((_) => unawaited(_recount()));
  }

  @override
  void dispose() {
    unawaited(_accessChanges?.cancel());
    super.dispose();
  }

  WeeklyCheckStanding _standing(WeeklyCheckRowState state) =>
      weeklyCheckStanding(
        check: state.check,
        access: weeklyCheckAccessFor(
          getIt<FeatureAccess>().decide(AppFeature.weeklyCheck),
        ),
        missedByClock: state.missedByClock,
      );

  /// The screen reads its checks again, so its header and its order follow
  /// what the row now shows. No relay call: the sources read the phone.
  Future<void> _recount() => getIt<ReliabilityCubit>().refresh();

  @override
  Widget build(BuildContext context) {
    final access = getIt<FeatureAccess>();
    return BlocProvider.value(
      value: getIt<WeeklyCheckCubit>(),
      child: BlocConsumer<WeeklyCheckCubit, WeeklyCheckRowState>(
        listenWhen: (before, after) => _standing(before) != _standing(after),
        listener: (context, state) => unawaited(_recount()),
        builder: (context, state) => StreamBuilder<AppFeature>(
          stream: access.changes.where(
            (feature) => feature == AppFeature.weeklyCheck,
          ),
          builder: (context, _) {
            final standing = _standing(state);
            final title = LocaleKeys.weekly_check_title.tr();
            return switch (weeklyCheckCardKindFor(standing)) {
              WeeklyCheckCardKind.notOffered => _CardWords(
                title: title,
                line: LocaleKeys.weekly_check_own_server_line.tr(),
              ),
              WeeklyCheckCardKind.locked => _CardLockedRow(title: title),
              WeeklyCheckCardKind.held => _CardHeldRow(
                title: title,
                view: weeklyCheckCardView(
                  standing: standing,
                  check: state.check,
                  now: DateTime.now(),
                ),
                isBusy: state.isBusy,
                switchLineKey: weeklyCheckSwitchLineKey(state.switchOutcome),
                onSwitch: (value) {
                  AppHaptics.capture();
                  unawaited(
                    context.read<WeeklyCheckCubit>().setEnabled(enabled: value),
                  );
                },
              ),
            };
          },
        ),
      ),
    );
  }
}

TextStyle _cardTitleStyle(AppColors colors) => AppTypography.body(
  colors.onPanel,
  fontSize: 15,
).copyWith(fontWeight: FontWeight.w700, height: 1.3);

TextStyle _cardLineStyle(AppColors colors) => AppTypography.mono(
  colors.onPanelMuted,
  fontSize: 12,
).copyWith(height: 1.4, letterSpacing: 0);

/// A title with one mono line under it.
class _CardWords extends StatelessWidget {
  const _CardWords({required this.title, required this.line});

  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _cardTitleStyle(colors)),
        const SizedBox(height: 2),
        Text(line, style: _cardLineStyle(colors)),
      ],
    );
  }
}

class _CardHeldRow extends StatelessWidget {
  const _CardHeldRow({
    required this.title,
    required this.view,
    required this.isBusy,
    required this.switchLineKey,
    required this.onSwitch,
  });

  final String title;
  final WeeklyCheckBodyView view;
  final bool isBusy;
  final String? switchLineKey;
  final ValueChanged<bool> onSwitch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final when = view.lineWhen;
    final line = when == null
        ? view.lineKey.tr()
        : view.lineKey.tr(namedArgs: {'when': when});
    final failedLine = switchLineKey?.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // The switch carries the title and the line for a screen reader.
            Expanded(
              child: ExcludeSemantics(
                child: _CardWords(title: title, line: line),
              ),
            ),
            const SizedBox(width: Spacing.s2),
            AppSwitch(
              value: view.isOn,
              variant: AppSwitchVariant.panel,
              semanticLabel: title,
              semanticHint: line,
              onChanged: isBusy ? null : onSwitch,
            ),
          ],
        ),
        if (failedLine != null) ...[
          const SizedBox(height: Spacing.s2),
          Text(
            failedLine,
            style: AppTypography.small(colors.onPanel, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// The locked row: the lock supplies the plan word and the one way to open
/// the paywall, and nothing in the row but the button uses it.
class _CardLockedRow extends StatelessWidget {
  const _CardLockedRow({required this.title});

  final String title;

  /// The text scale and the width below which the button drops under the
  /// line.
  static const double _stackFromScale = 1.25;
  static const double _stackBelowWidth = 300;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AccessLock.inline(
      feature: AppFeature.weeklyCheck,
      source: LockSource.reliability,
      unlockTap: LockTapKind.seePlan,
      decide: _lockedWeeklyDecision,
      child: Builder(
        builder: (context) {
          final scope = FeatureLockScope.maybeOf(context);
          final line = LocaleKeys.proof_card_locked_line.tr();
          final plan = scope?.planWord;
          final unlock = scope?.unlock;
          final words = _CardWords(title: title, line: line);
          // One spoken piece for the words, with no tap and no role.
          final spoken = Semantics(
            container: true,
            label: [title, line, ?plan].join(', '),
            excludeSemantics: true,
            child: words,
          );
          if (plan == null ||
              !weeklyCheckCardShowsSeePlan(
                planWord: plan,
                canUnlock: unlock != null,
              )) {
            return spoken;
          }
          final pill = AppButton(
            label: LocaleKeys.personalize_passes_widgets_see_plan.tr(
              namedArgs: {'plan': plan},
            ),
            variant: AppButtonVariant.ghost,
            // The small size keeps the title on one line beside the pill at
            // 390 wide, as the fix buttons in the problem list do.
            size: AppButtonSize.sm,
            foregroundColor: colors.yellow,
            icon: AppGlyph(GlyphType.lock, size: 16, color: colors.yellow),
            onPressed: unlock,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final stacks =
                  scale >= _stackFromScale ||
                  constraints.maxWidth < _stackBelowWidth;
              if (stacks) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    spoken,
                    const SizedBox(height: Spacing.s3),
                    pill,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: spoken),
                  const SizedBox(width: Spacing.s2),
                  pill,
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The way to the list of rounds, as a plain row under the proof card. It
/// draws nothing until the relay has sent this phone a check.
class WeeklyCheckRoundsLink extends StatelessWidget {
  const WeeklyCheckRoundsLink({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeeklyCheckCubit, WeeklyCheckRowState>(
      bloc: getIt<WeeklyCheckCubit>(),
      builder: (context, state) => weeklyCheckShowsRounds(state.check)
          ? const Padding(
              padding: EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
              child: AppSheet(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: WeeklyCheckRoundsRow(),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
