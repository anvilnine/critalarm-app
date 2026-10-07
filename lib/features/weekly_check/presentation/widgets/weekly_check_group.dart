import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/presentation/widgets/pro_pack_reliability_group.dart';
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
class WeeklyCheckGroup extends StatefulWidget {
  const WeeklyCheckGroup({super.key});

  @override
  State<WeeklyCheckGroup> createState() => _WeeklyCheckGroupState();
}

class _WeeklyCheckGroupState extends State<WeeklyCheckGroup> {
  @override
  void initState() {
    super.initState();
    unawaited(getIt<WeeklyCheckCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final access = getIt<ProPackAccess>();
    return BlocProvider.value(
      value: getIt<WeeklyCheckCubit>(),
      child: BlocBuilder<WeeklyCheckCubit, WeeklyCheckRowState>(
        builder: (context, state) {
          final view = weeklyCheckBodyView(
            check: state.check,
            isSelfHosted: state.isSelfHosted,
            now: DateTime.now(),
          );
          return StreamBuilder<bool>(
            stream: access.stream,
            initialData: access.isHeld,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ProPackReliabilityGroup(
                  unlockedFace: view.face,
                  weeklyCheckBody: (context) =>
                      WeeklyCheckBody(view: view, state: state),
                ),
                // The list of rounds needs no pack. A locked row is one
                // button to the Pro sheet, so the link sits under it, and
                // only on a phone that has had the check on.
                if (!access.isHeld && state.check?.lastSentAt != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: Spacing.s1),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: WeeklyCheckRoundsLink(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What sits under the title of the unlocked row: one line and the switch,
/// when the next check is due, and the way to the list of rounds.
class WeeklyCheckBody extends StatelessWidget {
  const WeeklyCheckBody({required this.view, required this.state, super.key});

  final WeeklyCheckBodyView view;
  final WeeklyCheckRowState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final quiet = AppTypography.small(colors.ink3, fontSize: 13);
    final when = view.lineWhen;
    final line = when == null
        ? view.lineKey.tr()
        : view.lineKey.tr(namedArgs: {'when': when});
    final nextDueKey = view.nextDueKey;
    final nextDueWhen = view.nextDueWhen;
    final cubit = context.read<WeeklyCheckCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(line, style: quiet)),
            const SizedBox(width: Spacing.s2),
            AppSwitch(
              value: view.isOn,
              semanticLabel: LocaleKeys.pro_pack_weekly_title.tr(),
              semanticHint: line,
              onChanged: state.isBusy
                  ? null
                  : (value) {
                      AppHaptics.capture();
                      unawaited(cubit.setEnabled(enabled: value));
                    },
            ),
          ],
        ),
        if (nextDueKey != null)
          Text(
            nextDueWhen == null
                ? nextDueKey.tr()
                : nextDueKey.tr(namedArgs: {'when': nextDueWhen}),
            style: quiet,
          ),
        if (view.showsSelfHostedLine)
          Text(LocaleKeys.weekly_check_self_hosted_line.tr(), style: quiet),
        if (state.didFail)
          Text(
            LocaleKeys.weekly_check_switch_failed.tr(),
            style: AppTypography.small(colors.ink, fontSize: 13),
          ),
        const SizedBox(height: Spacing.s1),
        const WeeklyCheckRoundsLink(),
      ],
    );
  }
}

/// Opens the list of rounds.
class WeeklyCheckRoundsLink extends StatelessWidget {
  const WeeklyCheckRoundsLink({super.key});

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
                    colors.ink,
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Spacing.s1),
              AppGlyph(GlyphType.arrow, color: colors.ink3, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}
