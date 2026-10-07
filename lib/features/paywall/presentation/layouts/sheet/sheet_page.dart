import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The screen the sheet is drawn over, by what the lead benefit is.
enum SheetPageKind {
  /// The new topic form, with the Critical switch lit.
  newTopic,
  history,
  widgets,
  reliability,

  /// A plain settings list, for a benefit with no screen of its own here.
  settings,
}

/// The screen a user reaches [benefit] from. Null draws the settings list.
SheetPageKind sheetPageKindFor(PaywallBenefitId? benefit) => switch (benefit) {
  PaywallBenefitId.topics => SheetPageKind.newTopic,
  PaywallBenefitId.history => SheetPageKind.history,
  PaywallBenefitId.widgets => SheetPageKind.widgets,
  PaywallBenefitId.reliabilityChecks => SheetPageKind.reliability,
  PaywallBenefitId.pushes ||
  PaywallBenefitId.appIcons ||
  PaywallBenefitId.wakeUpChallenges ||
  PaywallBenefitId.customSounds ||
  PaywallBenefitId.customAlarmScreens ||
  null => SheetPageKind.settings,
};

/// Horizontal inset of the screen behind.
const double _side = Spacing.s4;

/// One quiet row. A topic name and a time are a machine's strings and are
/// set in mono. A field's name is prose.
typedef _Row = ({
  String label,
  String? value,
  bool labelIsMono,
  bool valueIsMono,
  bool opens,
});

_Row _link(String label, [String? value]) => (
  label: label,
  value: value,
  labelIsMono: false,
  valueIsMono: false,
  opens: true,
);

_Row _log(String topic, String time) => (
  label: topic,
  value: time,
  labelIsMono: true,
  valueIsMono: true,
  opens: false,
);

/// The quiet rows of one screen: those above the lit row, nearest the title
/// first, and those under it.
({List<_Row> above, List<_Row> below}) _rowsFor(SheetPageKind kind) {
  final sound = _link(
    LocaleKeys.paywall_sheet_page_sound.tr(),
    LocaleKeys.paywall_sheet_page_sound_value.tr(),
  );
  final test = _link(LocaleKeys.paywall_sheet_page_test_alarm.tr());
  final quiet = _link(LocaleKeys.paywall_sheet_page_quiet_hours.tr());
  final notifications = _link(LocaleKeys.paywall_sheet_page_notifications.tr());
  final appearance = _link(LocaleKeys.paywall_sheet_page_appearance.tr());

  return switch (kind) {
    SheetPageKind.newTopic => (
      above: [
        (
          label: LocaleKeys.paywall_sheet_page_name.tr(),
          value: 'nas-backup', // l10n-ok: a made-up topic name
          labelIsMono: false,
          valueIsMono: true,
          opens: false,
        ),
        quiet,
      ],
      below: [sound, test, notifications],
    ),
    // Made-up topic names and times, as the history list shows them.
    SheetPageKind.history => (
      above: [_log('prod-db', '02:10'), _log('uptime-kuma', '23:41')],
      below: [
        _log('nas-backup', '18:05'),
        _log('home-ha', '07:30'),
        _log('prod-db', '04:52'),
      ],
    ),
    SheetPageKind.widgets ||
    SheetPageKind.reliability ||
    SheetPageKind.settings => (
      above: [test, notifications],
      below: [sound, quiet, appearance],
    ),
  };
}

/// A picture of the screen the user was on: a back row, a title and a quiet
/// list with a gap where the lit row goes. It is not the live screen and
/// nothing on it can be tapped.
class SheetPage extends StatelessWidget {
  const SheetPage({required this.plan, required this.kind, super.key});

  final SheetPlan plan;
  final SheetPageKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = _rowsFor(kind);
    final step = plan.rowHeight + plan.rowGap;
    final below = [
      for (final (i, row) in rows.below.indexed)
        if (plan.litBottom + plan.rowGap + (i + 1) * step <=
            MediaQuery.sizeOf(context).height)
          row,
    ];

    final (back, title) = switch (kind) {
      SheetPageKind.newTopic => (
        LocaleKeys.paywall_sheet_page_back_topics.tr(),
        LocaleKeys.paywall_sheet_page_title_new_topic.tr(),
      ),
      SheetPageKind.history => (
        LocaleKeys.paywall_sheet_page_back_topics.tr(),
        LocaleKeys.paywall_sheet_page_title_history.tr(),
      ),
      SheetPageKind.widgets => (
        LocaleKeys.paywall_sheet_page_back_settings.tr(),
        LocaleKeys.paywall_sheet_page_title_widgets.tr(),
      ),
      SheetPageKind.reliability => (
        LocaleKeys.paywall_sheet_page_back_settings.tr(),
        LocaleKeys.paywall_sheet_page_title_reliability.tr(),
      ),
      SheetPageKind.settings => (
        null,
        LocaleKeys.paywall_sheet_page_title_settings.tr(),
      ),
    };

    return ColoredBox(
      color: colors.canvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_side, plan.topInset, _side, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: plan.navHeight,
              child: Row(
                children: [
                  if (back != null) ...[
                    AppGlyph(GlyphType.back, size: 16, color: colors.onCanvas),
                    const SizedBox(width: Spacing.s1),
                    Text(
                      back,
                      style: AppTypography.small(
                        colors.onCanvas,
                        fontSize: 15,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Spacer(),
                  if (kind == SheetPageKind.newTopic)
                    Text(
                      LocaleKeys.paywall_sheet_page_save.tr(),
                      style: AppTypography.small(
                        colors.onCanvas,
                        fontSize: 15,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: plan.titleBlock,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: AppTypography.headline(
                    colors.onCanvas,
                    fontSize: plan.titleSize,
                  ),
                ),
              ),
            ),
            for (final row in rows.above.take(plan.rowsAbove)) ...[
              _QuietRow(row: row, height: plan.rowHeight),
              SizedBox(height: plan.rowGap),
            ],
            // The lit row is drawn over the scrim, in this gap.
            SizedBox(height: plan.litHeight + plan.rowGap),
            for (final row in below) ...[
              _QuietRow(row: row, height: plan.rowHeight),
              SizedBox(height: plan.rowGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuietRow extends StatelessWidget {
  const _QuietRow({required this.row, required this.height});

  final _Row row;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final value = row.value;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        boxShadow: AppShadows.shadowSm(
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: row.labelIsMono
                  ? AppTypography.monoBold(colors.ink)
                  : AppTypography.small(
                      colors.ink,
                      fontSize: 15,
                    ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (value != null)
            Text(
              value,
              style: row.valueIsMono
                  ? AppTypography.monoBold(colors.ink)
                  : AppTypography.small(colors.ink3),
            ),
          if (row.opens) ...[
            const SizedBox(width: Spacing.s1),
            AppGlyph(GlyphType.chevron, size: 13, color: colors.ink3),
          ],
        ],
      ),
    );
  }
}

/// The row the user tapped, drawn above the scrim.
///
/// On the new topic form it is the Critical switch with the count under
/// it, and it plays the limit lifting: the switch turns on and the count
/// becomes "no limit". Anywhere else it is the benefit's own row with the
/// product's badge, which shakes its head once a loop.
class SheetLitRow extends StatelessWidget {
  const SheetLitRow({
    required this.plan,
    required this.kind,
    required this.lead,
    required this.badge,
    required this.clock,
    super.key,
  });

  final SheetPlan plan;
  final SheetPageKind kind;
  final PaywallBenefit? lead;

  /// The product's name, for the badge on a locked row.
  final String badge;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: plan.litHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: kind == SheetPageKind.newTopic
          ? _LimitRow(clock: clock)
          : _LockedRow(lead: lead, badge: badge, clock: clock),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.clock});

  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, t, _) {
        final lifted = SheetMotion.limitLifted(t);
        return Padding(
          padding: const EdgeInsets.all(Spacing.s1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppToggleRow(
                title: LocaleKeys.paywall_sheet_page_critical.tr(),
                subtitle: LocaleKeys.paywall_sheet_page_critical_line.tr(),
                value: lifted,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.s3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: context.motion(AppDurations.base),
                      switchInCurve: AppCurves.easeOut,
                      switchOutCurve: AppCurves.easeOut,
                      child: Text(
                        lifted
                            ? LocaleKeys.paywall_sheet_page_critical_lifted.tr()
                            : LocaleKeys.paywall_sheet_page_critical_used.tr(
                                namedArgs: HostedBenefit.args,
                              ),
                        key: ValueKey(lifted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small(
                          lifted ? colors.cobalt : colors.ink2,
                          fontSize: 13,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({
    required this.lead,
    required this.badge,
    required this.clock,
  });

  final PaywallBenefit? lead;
  final String badge;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final line = lead?.line;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead?.title ?? badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
                ),
                if (line != null)
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small(
                      colors.ink3,
                      fontSize: 12.5,
                    ).copyWith(height: 1.3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.s3),
          // The shake is a motion. It starts and ends upright.
          ValueListenableBuilder<double>(
            valueListenable: clock,
            builder: (context, t, child) {
              final shake = SheetMotion.lockedShake(t);
              return Transform.translate(
                offset: Offset(4 * shake, 0),
                child: Transform.rotate(angle: 0.09 * shake, child: child),
              );
            },
            child: ProBadge(label: badge),
          ),
        ],
      ),
    );
  }
}
