import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/ask_sheet_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Opens the Pro sheet at a moment that earned the ask.
///
/// Opening it is what starts the quiet period, not the button the user
/// picks. Tapping "See Pro plans", swiping the sheet away and tapping
/// outside it are all answers, and none of them should bring it straight
/// back. "Not now" does one thing more: it counts, and the second one turns
/// the sheet off for good. "Remind me later" also waits 30 days but never
/// counts, and with Offers on the ask comes back as a notification instead.
///
/// Ask `ProAskRules.shouldAsk` before calling this.
Future<void> showProAskSheet({
  required BuildContext context,
  required InAppNoticeRepository repository,
}) {
  final analytics = getIt.isRegistered<LocalReminderAnalytics>()
      ? getIt<LocalReminderAnalytics>()
      : null;
  unawaited(repository.markProAsked());
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => ProAskSheet(
      onSeePlans: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proAskAnswered(answer: LocalReminderAnalytics.seePlans),
        );
        openAppPath(context, '/paywall');
      },
      onRemindLater: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proAskAnswered(answer: LocalReminderAnalytics.remindLater),
        );
        unawaited(repository.remindProAskLater());
      },
      onNotNow: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proAskAnswered(answer: LocalReminderAnalytics.notNow),
        );
        unawaited(repository.dismissProAsk());
      },
    ),
  );
}

/// The body of the Pro sheet: the happy face, what Pro gives, and the three
/// ways out.
class ProAskSheet extends StatelessWidget {
  const ProAskSheet({
    this.onSeePlans,
    this.onRemindLater,
    this.onNotNow,
    super.key,
  });

  final VoidCallback? onSeePlans;
  final VoidCallback? onRemindLater;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: FaceWidget(state: FaceState.laughing, size: 88),
        ),
        const SizedBox(height: Spacing.s3),
        AskSheetTitle(LocaleKeys.home_pro_prompt_title.tr()),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.home_pro_prompt_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink2),
        ),
        const SizedBox(height: 14),
        AskSheetBullet(LocaleKeys.home_pro_prompt_bullet_topics.tr()),
        const SizedBox(height: 6),
        AskSheetBullet(
          LocaleKeys.home_pro_prompt_bullet_support.tr(),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: colors.hairline),
        const SizedBox(height: 12),
        Text(
          LocaleKeys.home_pro_prompt_fed.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink3, fontSize: 12),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.home_pro_prompt_button.tr(),
          isFullWidth: true,
          onPressed: onSeePlans,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.home_pro_prompt_later.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: onRemindLater,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.common_not_now.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: onNotNow,
        ),
      ],
    );
  }
}
