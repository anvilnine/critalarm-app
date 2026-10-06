import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/ask_sheet_parts.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
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
  required HostedAskTrigger trigger,
}) {
  final analytics = getIt.isRegistered<LocalReminderAnalytics>()
      ? getIt<LocalReminderAnalytics>()
      : null;
  unawaited(repository.markProAsked());
  unawaited(analytics?.hostedAskShown(trigger: trigger));
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => ProAskSheet(
      trigger: trigger,
      onSeePlans: () {
        Navigator.of(sheetContext).pop();
        unawaited(
          analytics?.proAskAnswered(answer: LocalReminderAnalytics.seePlans),
        );
        openAppPath(context, paywallLocation(PaywallSource.askSheet));
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

/// The body of the Pro sheet: the face, what Hosted adds, what Free keeps,
/// and the three ways out.
///
/// It scrolls once the text is too large for the screen, and sits at its own
/// height before that.
class ProAskSheet extends StatelessWidget {
  const ProAskSheet({
    required this.trigger,
    this.onSeePlans,
    this.onRemindLater,
    this.onNotNow,
    super.key,
  });

  final HostedAskTrigger trigger;
  final VoidCallback? onSeePlans;
  final VoidCallback? onRemindLater;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A refusal does not get a laughing face. The plan notices use
            // the same neutral one.
            Center(
              child: FaceWidget(
                state: trigger == HostedAskTrigger.capRefused
                    ? FaceState.watching
                    : FaceState.laughing,
                size: 64,
              ),
            ),
            const SizedBox(height: Spacing.s3),
            if (trigger == HostedAskTrigger.capRefused) ...[
              Text(
                LocaleKeys.asks_pro_cap_refused.tr(
                  namedArgs: {
                    'free_critical_topics':
                        '${AccountCaps.free.criticalTopics}',
                  },
                ),
                textAlign: TextAlign.center,
                style: AppTypography.small(colors.ink2),
              ),
              const SizedBox(height: Spacing.s3),
            ],
            AskSheetTitle(LocaleKeys.asks_pro_title.tr()),
            const SizedBox(height: 12),
            for (final line in hostedBenefitLines(HostedSurface.askSheet)) ...[
              AskSheetBullet(line),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 8),
            Text(
              LocaleKeys.asks_pro_free_keeps.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.small(colors.ink2),
            ),
            const SizedBox(height: 4),
            if (HostedSurface.askSheet.ownServerLine case final line?)
              Text(
                line,
                textAlign: TextAlign.center,
                style: AppTypography.small(colors.ink3, fontSize: 12),
              ),
            const SizedBox(height: 16),
            AppButton(
              label: LocaleKeys.asks_pro_button.tr(),
              isFullWidth: true,
              onPressed: onSeePlans,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: LocaleKeys.asks_pro_later.tr(),
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
        ),
      ),
    );
  }
}
