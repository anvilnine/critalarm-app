import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_views.dart';
import 'package:critalarm/features/pro_pack/presentation/widgets/pro_pack_reliability_group.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/reliability/presentation/widgets/reliability_row.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The weekly delivery check on the Reliability screen: the Pro row, with
/// the switch and what the relay last said once the install holds the pack.
///
/// The row never says a received check proves that alarms work. It shows
/// nothing when a check arrives: native code answers it with no screen.
///
/// The Reliability screen hands it [check], the check `WeeklyCheckSource`
/// gave the screen, and [isPrimary], whether this row's button is the
/// screen's one primary button. The row's button is that check's fix and
/// nothing decided here, so the header, the count in Settings and the row
/// read one answer.
class WeeklyCheckGroup extends StatefulWidget {
  const WeeklyCheckGroup({this.check, this.isPrimary = false, super.key});

  /// Null when the weekly check does not count: locked, never on, or off.
  final ReliabilityCheck? check;
  final bool isPrimary;

  @override
  State<WeeklyCheckGroup> createState() => _WeeklyCheckGroupState();
}

class _WeeklyCheckGroupState extends State<WeeklyCheckGroup> {
  bool _isFixing = false;
  StreamSubscription<bool>? _packChanges;

  @override
  void initState() {
    super.initState();
    unawaited(getIt<WeeklyCheckCubit>().load());
    // Gaining or losing the pack changes whether the check counts.
    _packChanges = getIt<ProPackAccess>().stream.listen(
      (_) => unawaited(_recount()),
    );
  }

  @override
  void dispose() {
    unawaited(_packChanges?.cancel());
    super.dispose();
  }

  WeeklyCheckStanding _standing(WeeklyCheckRowState state) =>
      weeklyCheckStanding(
        check: state.check,
        isPackHeld: getIt<ProPackAccess>().isHeld,
        missedByClock: state.missedByClock,
      );

  /// The screen reads its checks again, so its header and its order follow
  /// what the row now shows. No relay call: the sources read the phone.
  Future<void> _recount() => getIt<ReliabilityCubit>().refresh();

  Future<void> _runFix(ReliabilityFix fix) async {
    if (_isFixing) return;
    AppHaptics.capture();
    if (fix is OpenRouteFix) {
      await context.pushNamed<void>(fix.routeName);
    } else {
      setState(() => _isFixing = true);
      try {
        await getIt<ReliabilityFixRunner>().run(fix);
      } finally {
        if (mounted) setState(() => _isFixing = false);
      }
    }
    await getIt<WeeklyCheckCubit>().load(force: true);
    await _recount();
  }

  @override
  Widget build(BuildContext context) {
    final access = getIt<ProPackAccess>();
    return BlocProvider.value(
      value: getIt<WeeklyCheckCubit>(),
      child: BlocConsumer<WeeklyCheckCubit, WeeklyCheckRowState>(
        listenWhen: (before, after) => _standing(before) != _standing(after),
        listener: (context, state) => unawaited(_recount()),
        builder: (context, state) => StreamBuilder<bool>(
          stream: access.stream,
          initialData: access.isHeld,
          builder: (context, _) {
            final standing = _standing(state);
            final showsRounds = state.check?.lastSentAt != null;
            if (standing == WeeklyCheckStanding.locked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (access.isHeld)
                    // The relay says the pack is gone and the packs list
                    // has not caught up. The row locks now.
                    WeeklyCheckRow(
                      view: weeklyCheckRowView(
                        isHeld: false,
                        isSelfHosted: state.isSelfHosted,
                      ),
                      body: weeklyCheckReadyBody,
                      onOpenPro: () => unawaited(
                        openProPackSheet(
                          context,
                          ProPackSheetSource.reliability,
                          isSelfHosted: state.isSelfHosted,
                        ),
                      ),
                    )
                  else
                    ProPackReliabilityGroup(isSelfHosted: state.isSelfHosted),
                  // The list of rounds needs no pack. A locked row is one
                  // button to the Pro sheet, so the link sits under it,
                  // and only on a phone the relay has sent a check to.
                  if (showsRounds)
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: Spacing.s1),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: WeeklyCheckRoundsLink(),
                      ),
                    ),
                ],
              );
            }
            final check = widget.check;
            final fix = check != null && standing.needsLook ? check.fix : null;
            return WeeklyCheckUnlockedRow(
              view: weeklyCheckBodyView(
                standing: standing,
                check: state.check,
                isSelfHosted: state.isSelfHosted,
                now: DateTime.now(),
              ),
              needsLook: standing.needsLook,
              isSwitchBusy: state.isBusy,
              didSwitchFail: state.didFail,
              onSwitch: (value) {
                AppHaptics.capture();
                unawaited(
                  context.read<WeeklyCheckCubit>().setEnabled(enabled: value),
                );
              },
              actionLabel: fix == null
                  ? null
                  : reliabilityFixLabelKey(
                      fix,
                      testRouteName: AppRoute.testRing,
                    ).tr(),
              isActionPrimary: widget.isPrimary,
              isActionBusy: _isFixing,
              onAction: fix == null ? null : () => unawaited(_runFix(fix)),
            );
          },
        ),
      ),
    );
  }
}

/// The weekly check row once the install holds the pack: the face of its
/// state, the title with the Pro badge and the switch on one line, one
/// short line, and one button when there is something to do.
///
/// A row that needs a look is drawn like the free rows that do: the same
/// card, the same "Look" chip, the same size of button.
class WeeklyCheckUnlockedRow extends StatelessWidget {
  const WeeklyCheckUnlockedRow({
    required this.view,
    required this.needsLook,
    required this.onSwitch,
    this.isSwitchBusy = false,
    this.didSwitchFail = false,
    this.actionLabel,
    this.isActionPrimary = false,
    this.isActionBusy = false,
    this.onAction,
    super.key,
  });

  final WeeklyCheckBodyView view;

  /// The check counts toward the screen's overall state.
  final bool needsLook;
  final ValueChanged<bool> onSwitch;
  final bool isSwitchBusy;
  final bool didSwitchFail;

  /// The one thing to do, or null when there is nothing.
  final String? actionLabel;

  /// Primary when this is the first row on the screen with something to
  /// do, ghost otherwise.
  final bool isActionPrimary;
  final bool isActionBusy;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onSurface = needsLook ? colors.onCanvas : colors.ink;
    final muted = needsLook ? colors.onCanvasMuted : colors.ink3;
    final quiet = AppTypography.small(muted, fontSize: 13);
    final title = LocaleKeys.pro_pack_weekly_title.tr();
    final when = view.lineWhen;
    final line = when == null
        ? view.lineKey.tr()
        : view.lineKey.tr(namedArgs: {'when': when});
    final nextDue = view.nextDueWhen;
    final label = actionLabel;
    // At large text the face stands above the words, as on the other rows.
    final isStacked = MediaQuery.textScalerOf(context).scale(15) >= 15 * 1.8;

    final face = ExcludeSemantics(
      child: FaceWidget(state: view.face, size: 36),
    );
    final toggle = AppSwitch(
      value: view.isOn,
      semanticLabel: title,
      semanticHint: line,
      onChanged: isSwitchBusy ? null : onSwitch,
    );
    final heading = Wrap(
      spacing: Spacing.s2,
      runSpacing: Spacing.s1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: AppTypography.body(
            onSurface,
            fontSize: 15,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
        ),
        ProBadge(label: LocaleKeys.pro_pack_badge.tr()),
        if (needsLook)
          ReliabilityStateChip(
            state: ReliabilityState.needsLook,
            label: LocaleKeys.reliability_state_look.tr(),
          ),
      ],
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStacked)
          heading
        else
          // The switch sits on the title line, so the lines under it keep
          // the whole width.
          Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: Spacing.s2),
              toggle,
            ],
          ),
        const SizedBox(height: 2),
        Text(line, style: quiet),
        if (nextDue != null)
          Text(
            LocaleKeys.weekly_check_next_due.tr(namedArgs: {'when': nextDue}),
            style: quiet,
          ),
        if (view.showsSelfHostedLine)
          Text(LocaleKeys.weekly_check_self_hosted_line.tr(), style: quiet),
        if (didSwitchFail)
          Text(
            LocaleKeys.weekly_check_switch_failed.tr(),
            style: AppTypography.small(onSurface, fontSize: 13),
          ),
        if (label != null) ...[
          const SizedBox(height: Spacing.s2),
          AppButton(
            label: label,
            size: AppButtonSize.sm,
            variant: isActionPrimary
                ? AppButtonVariant.primary
                : AppButtonVariant.ghost,
            isLoading: isActionBusy,
            onPressed: onAction,
          ),
        ],
        if (view.showsRoundsLink) ...[
          const SizedBox(height: Spacing.s1),
          WeeklyCheckRoundsLink(color: onSurface, arrowColor: muted),
        ],
      ],
    );

    final Widget content = isStacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [face, const Spacer(), toggle]),
              const SizedBox(height: Spacing.s2),
              words,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              face,
              const SizedBox(width: Spacing.s3),
              Expanded(child: words),
            ],
          );

    if (needsLook) {
      // The card the free rows use when they need a look.
      return AppHighlightCard(
        tone: AppHighlightTone.choice,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: content,
      );
    }
    // The same light border as the locked row and the free test row.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.ink3.withValues(alpha: 0.4)),
      ),
      child: content,
    );
  }
}

/// Opens the list of rounds.
class WeeklyCheckRoundsLink extends StatelessWidget {
  const WeeklyCheckRoundsLink({this.color, this.arrowColor, super.key});

  /// The text colour. Null is the ink of a plain surface.
  final Color? color;
  final Color? arrowColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            unawaited(context.pushNamed<void>(AppRoute.weeklyCheckRounds)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  LocaleKeys.weekly_check_rounds_link.tr(),
                  style: AppTypography.small(
                    color ?? colors.ink,
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Spacing.s1),
              AppGlyph(
                GlyphType.arrow,
                color: arrowColor ?? colors.ink3,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
