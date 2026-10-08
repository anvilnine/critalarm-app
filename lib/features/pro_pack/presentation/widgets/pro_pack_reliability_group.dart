import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_views.dart';
import 'package:critalarm/features/reliability/presentation/widgets/reliability_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Draws what sits under the title of the weekly delivery check row once
/// the install holds the pack.
typedef WeeklyCheckBodyBuilder = Widget Function(BuildContext context);

/// The Pro rows on the Reliability screen, under the free ones. One row
/// today: the weekly delivery check.
///
/// Without the pack the row is locked: one line on what it does, and a tap
/// opens the Pro sheet. With the pack it draws [weeklyCheckBody], which
/// by default is one line saying it is ready to switch on. The weekly check
/// passes its own builder. The title and the badge stay.
class ProPackReliabilityGroup extends StatelessWidget {
  const ProPackReliabilityGroup({
    this.weeklyCheckBody = weeklyCheckReadyBody,
    this.isSelfHosted = false,
    super.key,
  });

  final WeeklyCheckBodyBuilder weeklyCheckBody;

  /// The phone is on a server of its own. The caller hands in the fact it
  /// already has. A locked row then says the check covers the push relay
  /// and not that server, and the Pro sheet it opens says the same.
  final bool isSelfHosted;

  @override
  Widget build(BuildContext context) {
    final access = getIt<FeatureAccess>();
    return StreamBuilder<AppFeature>(
      stream: access.changes.where(
        (feature) => feature == AppFeature.weeklyCheck,
      ),
      builder: (context, _) {
        // The stream only carries changes, so the value is read each build.
        // A purchase still being confirmed keeps the row locked, as the
        // relay would refuse the check until it has the pack.
        final view = weeklyCheckRowView(
          isHeld: access.decide(AppFeature.weeklyCheck) is FeatureOpen,
          isSelfHosted: isSelfHosted,
        );
        return WeeklyCheckRow(
          view: view,
          body: weeklyCheckBody,
          onOpenPro: () => unawaited(
            openPaywallFor(
              context,
              access.decideHoldingNothing(AppFeature.weeklyCheck),
              LockSource.reliability,
              isSelfHosted: isSelfHosted,
            ),
          ),
        );
      },
    );
  }
}

/// The body of the unlocked row until the check itself exists.
Widget weeklyCheckReadyBody(BuildContext context) => Text(
  LocaleKeys.pro_pack_weekly_ready_line.tr(),
  style: AppTypography.small(context.appColors.ink3, fontSize: 13),
);

/// The weekly delivery check row: the title with the Pro badge, and either
/// the locked line or the unlocked body. A plain row with no face.
///
/// A locked row is a button: it opens the Pro sheet.
class WeeklyCheckRow extends StatelessWidget {
  const WeeklyCheckRow({
    required this.view,
    required this.body,
    required this.onOpenPro,
    super.key,
  });

  final WeeklyCheckRowView view;
  final WeeklyCheckBodyBuilder body;
  final VoidCallback onOpenPro;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = LocaleKeys.pro_pack_weekly_title.tr();
    final badge = LocaleKeys.pro_pack_badge.tr();
    final selfHostedLine = view.selfHostedLineKey?.tr();

    if (!view.isLocked) {
      // The body is a widget of the caller's, under the title.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: Spacing.s2,
              runSpacing: Spacing.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                ),
                ProBadge(label: badge),
              ],
            ),
            const SizedBox(height: 2),
            body(context),
          ],
        ),
      );
    }

    final line = view.lineKey.tr();
    return ReliabilityPlainRow(
      title: title,
      badge: ProBadge(label: badge),
      lines: [line, ?selfHostedLine],
      label: [title, badge, line, ?selfHostedLine].join(', '),
      hint: LocaleKeys.pro_pack_weekly_locked_hint.tr(),
      onTap: onOpenPro,
      trailing: AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
    );
  }
}
