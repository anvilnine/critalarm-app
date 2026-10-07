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
            // The list of rounds needs no pack, and only a phone the relay
            // has sent a check to has one.
            final showsRounds = weeklyCheckShowsRounds(state.check);
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
                  // A locked row is one button to the Pro sheet, so the
                  // way to the rounds is a row of its own under it.
                  if (showsRounds) ...const [
                    ReliabilityRowDivider(),
                    WeeklyCheckRoundsRow(),
                  ],
                ],
              );
            }
            final check = widget.check;
            final fix = check != null && standing.needsLook ? check.fix : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                WeeklyCheckUnlockedRow(
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
                      context.read<WeeklyCheckCubit>().setEnabled(
                        enabled: value,
                      ),
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
                ),
                // A row of its own, so the weekly row keeps its title and
                // one line.
                if (showsRounds) ...[
                  const ReliabilityRowDivider(),
                  WeeklyCheckRoundsRow(onCard: standing.needsLook),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The weekly check row once the install holds the pack.
///
/// While the check is fine, off or waiting it is a plain row: the title with
/// the Pro badge, one line and the switch. It has no face.
///
/// A check that needs a look is drawn like the free rows that do: the face
/// and the "Look" chip of that state, the switch on the title line, one
/// button when there is something to do. It sits inside the card those rows
/// share.
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
    final title = LocaleKeys.pro_pack_weekly_title.tr();
    final when = view.lineWhen;
    final line = when == null
        ? view.lineKey.tr()
        : view.lineKey.tr(namedArgs: {'when': when});
    final selfHostedLine = view.showsSelfHostedLine
        ? LocaleKeys.weekly_check_self_hosted_line.tr()
        : null;
    final failedLine = didSwitchFail
        ? LocaleKeys.weekly_check_switch_failed.tr()
        : null;
    final toggle = AppSwitch(
      value: view.isOn,
      semanticLabel: title,
      semanticHint: line,
      onChanged: isSwitchBusy ? null : onSwitch,
    );
    final badge = ProBadge(label: LocaleKeys.pro_pack_badge.tr());

    if (!needsLook) {
      return ReliabilityPlainRow(
        title: title,
        badge: badge,
        lines: [line, ?selfHostedLine, ?failedLine],
        trailing: toggle,
      );
    }

    final onSurface = colors.onCanvas;
    final quiet = AppTypography.small(colors.onCanvasMuted, fontSize: 13);
    final label = actionLabel;
    final face = reliabilityStateFace(ReliabilityState.needsLook);
    // At large text the face stands above the words, as on the other rows.
    final isStacked = MediaQuery.textScalerOf(context).scale(15) >= 15 * 1.8;

    final faceWidget = face == null
        ? null
        : ExcludeSemantics(child: FaceWidget(state: face, size: 36));
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
        badge,
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
        if (selfHostedLine != null) Text(selfHostedLine, style: quiet),
        if (failedLine != null)
          Text(
            failedLine,
            style: AppTypography.small(onSurface, fontSize: 13),
          ),
        if (label != null) ...[
          const SizedBox(height: Spacing.s2),
          ReliabilityFixButton(
            label: label,
            checkTitle: title,
            variant: isActionPrimary
                ? AppButtonVariant.primary
                : AppButtonVariant.ghost,
            isBusy: isActionBusy,
            onPressed: onAction,
          ),
        ],
      ],
    );

    final Widget content = faceWidget == null
        ? words
        : isStacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [faceWidget, const Spacer(), toggle]),
              const SizedBox(height: Spacing.s2),
              words,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              faceWidget,
              const SizedBox(width: Spacing.s3),
              Expanded(child: words),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: content,
    );
  }
}

/// The way to the list of rounds: a plain row that only opens another
/// screen, so it has no face.
class WeeklyCheckRoundsRow extends StatelessWidget {
  const WeeklyCheckRoundsRow({this.onCard = false, super.key});

  /// The row sits on the cream card of rows that need action.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = LocaleKeys.weekly_check_rounds_link.tr();
    return ReliabilityPlainRow(
      title: title,
      label: title,
      onCard: onCard,
      onTap: () =>
          unawaited(context.pushNamed<void>(AppRoute.weeklyCheckRounds)),
      trailing: AppGlyph(
        GlyphType.arrow,
        color: onCard ? colors.onCanvasMuted : colors.ink3,
        size: 16,
      ),
    );
  }
}
