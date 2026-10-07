import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_views.dart';
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
/// passes its own builder and, through [unlockedFace], the face for the
/// state the check is in. The title and the badge stay.
class ProPackReliabilityGroup extends StatelessWidget {
  const ProPackReliabilityGroup({
    this.weeklyCheckBody = weeklyCheckReadyBody,
    this.unlockedFace,
    super.key,
  });

  final WeeklyCheckBodyBuilder weeklyCheckBody;

  /// The face of the unlocked row. Null keeps the one `weeklyCheckRowView`
  /// picks. A locked row never uses it.
  final FaceState? unlockedFace;

  @override
  Widget build(BuildContext context) {
    final access = getIt<ProPackAccess>();
    return StreamBuilder<bool>(
      stream: access.stream,
      initialData: access.isHeld,
      builder: (context, held) {
        // The stream only carries changes, so the value is read each build.
        final view = weeklyCheckRowView(isHeld: access.isHeld);
        final face = unlockedFace;
        return WeeklyCheckRow(
          view: face == null || view.isLocked
              ? view
              : WeeklyCheckRowView(
                  isLocked: false,
                  face: face,
                  lineKey: view.lineKey,
                ),
          body: weeklyCheckBody,
          onOpenPro: () => unawaited(
            openProPackSheet(context, ProPackSheetSource.reliability),
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

/// The weekly delivery check row: a face, the title with the Pro badge, and
/// either the locked line or the unlocked body.
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
    // At large text the face stands above the words, as on the other rows.
    final isStacked = MediaQuery.textScalerOf(context).scale(15) >= 15 * 1.8;

    final face = ExcludeSemantics(
      child: FaceWidget(state: view.face, size: 36),
    );
    final arrow = AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16);

    final words = Column(
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
        if (view.isLocked)
          Text(
            view.lineKey.tr(),
            style: AppTypography.small(colors.ink3, fontSize: 13),
          )
        else
          body(context),
      ],
    );

    final Widget content = isStacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  face,
                  if (view.isLocked) ...[const Spacer(), arrow],
                ],
              ),
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
              if (view.isLocked) ...[
                const SizedBox(width: Spacing.s2),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: arrow,
                ),
              ],
            ],
          );

    final row = AppHighlightCard(
      tone: AppHighlightTone.pending,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: content,
    );

    if (!view.isLocked) return row;
    return Semantics(
      container: true,
      button: true,
      label: '$title, $badge, ${view.lineKey.tr()}',
      hint: LocaleKeys.pro_pack_weekly_locked_hint.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenPro,
        child: row,
      ),
    );
  }
}
