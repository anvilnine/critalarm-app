import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/ask_sheet_parts.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminders_sheet_choice.dart';
import 'package:critalarm/features/local_reminders/domain/self_hosted_matrix.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Asks once whether reminders are welcome. Shown after the first test
/// alarm is acknowledged, and once on the first open after the update for
/// installs that already tested.
///
/// Opening it is what marks it shown. A swipe keeps the defaults (Reminders
/// on, Offers off). The Offers box starts unticked: promotions need an
/// explicit yes (App Store 4.5.4).
Future<void> showLocalRemindersSheet({
  required BuildContext context,
  required LocalReminderStore store,
  required bool isSelfHosted,
  bool isPaid = false,
  Future<void> Function()? onAnswered,
}) {
  final analytics = getIt.isRegistered<LocalReminderAnalytics>()
      ? getIt<LocalReminderAnalytics>()
      : null;
  unawaited(store.markSheetShown());
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => LocalRemindersSheet(
      isSelfHosted: isSelfHosted,
      isPaid: isPaid,
      onTurnOn: ({required offers}) {
        Navigator.of(sheetContext).pop();
        unawaited(analytics?.sheetAnswered(answer: 'on', offers: offers));
        unawaited(
          store
              .writeSwitches(
                LocalRemindersSheetChoice.turnOn(
                  offersTicked: offers,
                  isSelfHosted: isSelfHosted,
                  isPaid: isPaid,
                ),
              )
              .then((_) => onAnswered?.call()),
        );
      },
      onNoThanks: () {
        Navigator.of(sheetContext).pop();
        unawaited(analytics?.sheetAnswered(answer: 'off', offers: false));
        unawaited(
          store
              .writeSwitches(LocalRemindersSheetChoice.noThanks)
              .then((_) => onAnswered?.call()),
        );
      },
    ),
  );
}

/// The body of the Reminders sheet, in the Pro sheet's style.
class LocalRemindersSheet extends StatefulWidget {
  const LocalRemindersSheet({
    required this.isSelfHosted,
    this.isPaid = false,
    this.onTurnOn,
    this.onNoThanks,
    super.key,
  });

  /// Hides the backup bullet and the Offers box: neither exists there.
  final bool isSelfHosted;

  /// Hides the Offers box: Pro offers mean nothing to someone who has Pro.
  final bool isPaid;
  final void Function({required bool offers})? onTurnOn;
  final VoidCallback? onNoThanks;

  @override
  State<LocalRemindersSheet> createState() => _LocalRemindersSheetState();
}

class _LocalRemindersSheetState extends State<LocalRemindersSheet> {
  bool _offers = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showsOffers =
        !widget.isPaid &&
        (!widget.isSelfHosted || SelfHostedMatrix.showsOffers);
    final onTurnOn = widget.onTurnOn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: FaceWidget(state: FaceState.watching, size: 88)),
        const SizedBox(height: Spacing.s3),
        AskSheetTitle(LocaleKeys.reminders_sheet_title.tr()),
        const SizedBox(height: 14),
        AskSheetBullet(LocaleKeys.reminders_sheet_bullet_test.tr()),
        const SizedBox(height: 6),
        AskSheetBullet(LocaleKeys.reminders_sheet_bullet_silent.tr()),
        if (!widget.isSelfHosted) ...[
          const SizedBox(height: 6),
          AskSheetBullet(LocaleKeys.reminders_sheet_bullet_backup.tr()),
        ],
        const SizedBox(height: 6),
        AskSheetBullet(LocaleKeys.reminders_sheet_bullet_asks.tr()),
        if (showsOffers) ...[
          const SizedBox(height: 12),
          // One node for screen readers: the label and the box together.
          MergeSemantics(
            child: InkWell(
              onTap: () => setState(() => _offers = !_offers),
              child: Row(
                children: [
                  Checkbox(
                    value: _offers,
                    activeColor: colors.cobalt,
                    onChanged: (value) =>
                        setState(() => _offers = value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      LocaleKeys.reminders_sheet_offers_checkbox.tr(),
                      style: AppTypography.small(colors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.reminders_sheet_turn_on.tr(),
          isFullWidth: true,
          onPressed: onTurnOn == null ? null : () => onTurnOn(offers: _offers),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.reminders_sheet_no_thanks.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: widget.onNoThanks,
        ),
        const SizedBox(height: 12),
        Text(
          LocaleKeys.reminders_sheet_hint.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink3, fontSize: 12),
        ),
      ],
    );
  }
}
