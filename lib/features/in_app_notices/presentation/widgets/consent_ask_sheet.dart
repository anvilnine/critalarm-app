import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Asks once whether to send crash reports and usage analytics.
///
/// Like the Pro sheet, opening it is the ask. "Not now", a swipe and a tap
/// outside all leave both off, and the sheet never opens again. Only
/// "Share" calls [onShare], with whichever switches are still on.
///
/// Ask `HomeAskRules.next` before calling this.
Future<void> showConsentAskSheet({
  required BuildContext context,
  required InAppNoticeRepository repository,
  required Future<void> Function({
    required bool crashReports,
    required bool analytics,
  })
  onShare,
}) {
  unawaited(repository.markConsentAsked());
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => ConsentAskSheet(
      onShare: ({required crashReports, required analytics}) {
        Navigator.of(sheetContext).pop();
        unawaited(onShare(crashReports: crashReports, analytics: analytics));
      },
      onNotNow: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// The body of the consent sheet: a face, the question, two switches and
/// the two ways out.
class ConsentAskSheet extends StatefulWidget {
  const ConsentAskSheet({this.onShare, this.onNotNow, super.key});

  final void Function({required bool crashReports, required bool analytics})?
  onShare;
  final VoidCallback? onNotNow;

  @override
  State<ConsentAskSheet> createState() => _ConsentAskSheetState();
}

class _ConsentAskSheetState extends State<ConsentAskSheet> {
  bool _crashReports = true;
  bool _analytics = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onShare = widget.onShare;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: FaceWidget(state: FaceState.watching, size: 88),
        ),
        const SizedBox(height: Spacing.s3),
        Text(
          LocaleKeys.asks_consent_title.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontFamilyFallback: AppTypography.fontDisplayFallbacks,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.02 * 19,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 16),
        AppToggleRow(
          title: LocaleKeys.asks_consent_crash.tr(),
          value: _crashReports,
          onChanged: (value) => setState(() => _crashReports = value),
        ),
        const SizedBox(height: 8),
        AppToggleRow(
          title: LocaleKeys.asks_consent_analytics.tr(),
          value: _analytics,
          onChanged: (value) => setState(() => _analytics = value),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.asks_consent_share.tr(),
          isFullWidth: true,
          onPressed: onShare == null
              ? null
              : () => onShare(
                  crashReports: _crashReports,
                  analytics: _analytics,
                ),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.common_not_now.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: widget.onNotNow,
        ),
      ],
    );
  }
}
