import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
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

/// The weekly delivery check on the Reliability screen. It is one of
/// three rows, by what `FeatureAccess` answers for the feature:
///
/// - Hosted held: the switch and what the relay last said.
/// - Hosted not held: a locked row that opens the Hosted paywall through
///   the one lock.
/// - On a server of the user's own: one line saying the check is not
///   available there. No badge, no button and no paywall.
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

  /// Null when the weekly check does not count: not offered, locked, never
  /// on, or off.
  final ReliabilityCheck? check;
  final bool isPrimary;

  @override
  State<WeeklyCheckGroup> createState() => _WeeklyCheckGroupState();
}

class _WeeklyCheckGroupState extends State<WeeklyCheckGroup> {
  bool _isFixing = false;
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

  /// What the access layer says for the weekly check. A purchase still
  /// being confirmed does not open the row: the relay refuses the check
  /// until the account is on Hosted.
  WeeklyCheckAccess get _access => weeklyCheckAccessFor(
    getIt<FeatureAccess>().decide(AppFeature.weeklyCheck),
  );

  WeeklyCheckStanding _standing(WeeklyCheckRowState state) =>
      weeklyCheckStanding(
        check: state.check,
        access: _access,
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
            // The list of rounds needs no plan, and only a phone the relay
            // has sent a check to has one.
            final showsRounds = weeklyCheckShowsRounds(state.check);
            if (standing == WeeklyCheckStanding.notOffered ||
                standing == WeeklyCheckStanding.locked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (standing == WeeklyCheckStanding.notOffered)
                    const WeeklyCheckNotOfferedRow()
                  else
                    const WeeklyCheckLockedRow(),
                  // Neither row leads to the rounds, so the way to them
                  // is a row of its own under it.
                  if (showsRounds) ...const [
                    ReliabilityRowDivider(),
                    WeeklyCheckRoundsRow(),
                  ],
                ],
              );
            }
            final check = widget.check;
            final fix = check != null && standing.needsLook ? check.fix : null;
            // The card is the screen's: a row that the screen has not
            // counted yet stays a plain row until it has.
            final needsLook = check != null && standing.needsLook;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                WeeklyCheckUnlockedRow(
                  view: weeklyCheckBodyView(
                    standing: standing,
                    check: state.check,
                    now: DateTime.now(),
                  ),
                  needsLook: needsLook,
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
                // one line. While the screen holds this row in its card of
                // rows that need action, the way to the rounds is the
                // screen's to draw in the plain list ([WeeklyCheckRoundsTail]),
                // not the card's.
                if (showsRounds && check == null) ...const [
                  ReliabilityRowDivider(),
                  WeeklyCheckRoundsRow(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The weekly check row while Hosted is not held, on Crit Alarm Cloud: the
/// title with the locked Hosted badge and one line on what the check does.
/// A plain row with no face.
///
/// The row is a button. The badge and the way to the paywall both come
/// from the one lock, [AccessLock], which picks the product from the
/// feature table. Nothing here names a plan.
class WeeklyCheckLockedRow extends StatelessWidget {
  const WeeklyCheckLockedRow({super.key});

  @override
  Widget build(BuildContext context) {
    return AccessLock.inline(
      feature: AppFeature.weeklyCheck,
      source: LockSource.reliability,
      // The row is locked while a Hosted purchase is still being
      // confirmed, because the relay refuses the check until then. So the
      // lock drawn is the one for holding nothing. A plan that could not
      // be read sells nothing: its own answer stands.
      decide: (access) {
        final decision = access.decide(AppFeature.weeklyCheck);
        return decision is FeatureConfirming
            ? access.decideHoldingNothing(AppFeature.weeklyCheck)
            : decision;
      },
      child: Builder(
        builder: (context) {
          final scope = FeatureLockScope.maybeOf(context);
          final title = LocaleKeys.weekly_check_title.tr();
          final line = LocaleKeys.weekly_check_what_line.tr();
          final unlock = scope?.unlock;
          return ReliabilityPlainRow(
            title: title,
            badge: const FeatureLockBadge(staysWhenOpen: true),
            lines: [line],
            label: [title, ?scope?.planWord, line].join(', '),
            hint: unlock == null
                ? null
                : LocaleKeys.weekly_check_locked_hint.tr(),
            onTap: unlock,
            trailing: unlock == null
                ? null
                : AppGlyph(
                    GlyphType.arrow,
                    color: context.appColors.ink3,
                    size: 16,
                  ),
          );
        },
      ),
    );
  }
}

/// The weekly check row on a phone connected to a server of the user's
/// own: the title and one line saying the check is not available there.
///
/// It is not a lock. There is no plan to sell for such a server, so the
/// row has no badge, takes no tap and opens no paywall.
class WeeklyCheckNotOfferedRow extends StatelessWidget {
  const WeeklyCheckNotOfferedRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ReliabilityPlainRow(
      title: LocaleKeys.weekly_check_title.tr(),
      lines: [LocaleKeys.weekly_check_own_server_line.tr()],
    );
  }
}

/// The weekly check row once the install holds Hosted.
///
/// While the check is fine, off or waiting it is a plain row: the title with
/// the Hosted badge, one line and the switch. It has no face.
///
/// A check that needs a look is drawn like the free rows that do: the "Look"
/// chip of that state, the switch on the title line, one button when there
/// is something to do. It has no face. It sits inside the card those rows
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
    final title = LocaleKeys.weekly_check_title.tr();
    final when = view.lineWhen;
    final line = when == null
        ? view.lineKey.tr()
        : view.lineKey.tr(namedArgs: {'when': when});
    final failedLine = didSwitchFail
        ? LocaleKeys.weekly_check_switch_failed.tr()
        : null;
    final toggle = AppSwitch(
      value: view.isOn,
      semanticLabel: title,
      semanticHint: line,
      onChanged: isSwitchBusy ? null : onSwitch,
    );
    final badge = ProBadge(label: planWordFor(Holding.hosted));

    if (!needsLook) {
      return ReliabilityPlainRow(
        title: title,
        badge: badge,
        lines: [line, ?failedLine],
        trailing: toggle,
      );
    }

    final onSurface = colors.onCanvas;
    final quiet = AppTypography.small(colors.onCanvasMuted, fontSize: 13);
    final label = actionLabel;
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
        // The switch sits on the title line, so the lines under it keep the
        // whole width.
        Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: Spacing.s2),
            toggle,
          ],
        ),
        const SizedBox(height: 2),
        Text(line, style: quiet),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: words,
    );
  }
}

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

/// The way to the rounds for a weekly row that sits in the card of rows that
/// need action. The Reliability screen draws it at the end of its plain
/// list, with its own rule above, and it draws nothing until the relay has
/// sent this phone a check.
class WeeklyCheckRoundsTail extends StatelessWidget {
  const WeeklyCheckRoundsTail({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeeklyCheckCubit, WeeklyCheckRowState>(
      bloc: getIt<WeeklyCheckCubit>(),
      builder: (context, state) => weeklyCheckShowsRounds(state.check)
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [ReliabilityRowDivider(), WeeklyCheckRoundsRow()],
            )
          : const SizedBox.shrink(),
    );
  }
}
