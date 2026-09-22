import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/widgets/prompt_sheet_parts.dart';
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
/// Ask `ProPromptRules.shouldAsk` before calling this.
Future<void> showProPromptSheet({
  required BuildContext context,
  required HomePromptRepository repository,
}) {
  final analytics = getIt.isRegistered<ReminderAnalytics>()
      ? getIt<ReminderAnalytics>()
      : null;
  unawaited(repository.markProPromptAsked());
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => ProPromptSheet(
      onSeePlans: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proPromptAnswered(answer: ReminderAnalytics.seePlans),
        );
        openAppPath(context, '/paywall');
      },
      onRemindLater: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proPromptAnswered(answer: ReminderAnalytics.remindLater),
        );
        unawaited(repository.remindProPromptLater());
      },
      onNotNow: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proPromptAnswered(answer: ReminderAnalytics.notNow),
        );
        unawaited(repository.dismissProPrompt());
      },
    ),
  );
}

/// The body of the Pro sheet: the happy face, what Pro gives, and the three
/// ways out.
class ProPromptSheet extends StatelessWidget {
  const ProPromptSheet({
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
        PromptSheetTitle(LocaleKeys.home_pro_prompt_title.tr()),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.home_pro_prompt_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink2),
        ),
        const SizedBox(height: 14),
        PromptSheetBullet(LocaleKeys.home_pro_prompt_bullet_topics.tr()),
        const SizedBox(height: 6),
        PromptSheetBullet(
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
