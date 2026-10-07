import 'dart:async';

import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Home says this phone missed an alarm: how many, the newest one's topic
/// and time, and the reason in a few words.
///
/// The card is drawn in Home's notice slot. `InAppNoticeCubit` decides when
/// it shows. Closing it keeps those alarms off Home for good. With several
/// missed alarms the line says which one the reason is about. The button
/// depends on the reason (`missedAlarmAction`): the test alarm screen, or
/// the newest missed alarm. It closes nothing. It is a card: it rings
/// nothing and posts no notification.
class MissedAlarmNoticeCard extends StatelessWidget {
  const MissedAlarmNoticeCard({required this.notice, super.key});

  final MissedAlarmNotice notice;

  /// Ring a test opens the test alarm screen, as the Reliability screen's
  /// own button does. See the alarm opens the newest missed alarm, which
  /// is first in [MissedAlarmNotice.incidentIds].
  void _open(BuildContext context) {
    switch (missedAlarmAction(notice.reason)) {
      case MissedAlarmAction.ringTest:
        unawaited(context.pushNamed<void>(AppRoute.testRing));
      case MissedAlarmAction.seeAlarm:
        openAppPath(context, AppLinkRoutes.incident(notice.incidentIds.first));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<InAppNoticeCubit>();
    final title = notice.count == 1
        ? LocaleKeys.notices_missed_alarm_title.tr()
        : LocaleKeys.notices_missed_alarm_title_many.tr(
            namedArgs: {'count': '${notice.count}'},
          );
    final when = missedAlarmWhenKey(count: notice.count).tr(
      namedArgs: {
        'topic': notice.topic,
        'time': missedAlarmTime(notice.at, now: DateTime.now()),
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: AppHighlightCard(
        tone: AppHighlightTone.choice,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: FaceWidget(
                    state: missedAlarmFace(notice.reason),
                    size: 32,
                  ),
                ),
                const SizedBox(width: Spacing.s3),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.body(
                        colors.onCanvas,
                      ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ),
                AppIconButton(
                  glyph: GlyphType.close,
                  ariaLabel: LocaleKeys.notices_missed_alarm_dismiss.tr(),
                  glyphSize: 14,
                  color: colors.onCanvasMuted,
                  onPressed: () => unawaited(cubit.dismissCurrent()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(when, style: AppTypography.small(colors.onCanvas)),
                  Text(
                    missedAlarmReasonKey(notice.reason).tr(),
                    style: AppTypography.small(colors.onCanvasMuted),
                  ),
                  const SizedBox(height: Spacing.s3),
                  AppButton(
                    label: missedAlarmButtonKey(notice.reason).tr(),
                    size: AppButtonSize.sm,
                    isFullWidth: true,
                    onPressed: () => _open(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
