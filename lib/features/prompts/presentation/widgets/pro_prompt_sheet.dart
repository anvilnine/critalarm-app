import 'dart:async';

import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Opens the Pro sheet. It asks once, at a moment that earned the ask, and
/// "Not now" is stored so the next ask waits or never comes.
///
/// Ask `ProPromptRules.shouldAsk` before calling this.
Future<void> showProPromptSheet({
  required BuildContext context,
  required HomePromptRepository repository,
}) {
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => ProPromptSheet(
      onSeePlans: () {
        Navigator.of(sheetContext).pop();
        openAppPath(context, '/paywall');
      },
      onNotNow: () {
        Navigator.of(sheetContext).pop();
        unawaited(repository.dismissProPrompt());
      },
    ),
  );
}

/// The body of the Pro sheet: the happy face, what Pro gives, and the two
/// ways out.
///
/// `home_prompt_slot.dart` still names this widget, but the cubit never asks
/// for a Pro prompt any more, so the slot never builds it.
class ProPromptSheet extends StatelessWidget {
  const ProPromptSheet({this.onSeePlans, this.onNotNow, super.key});

  final VoidCallback? onSeePlans;
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
        Text(
          LocaleKeys.home_pro_prompt_title.tr(),
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
        const SizedBox(height: 6),
        Text(
          LocaleKeys.home_pro_prompt_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink2),
        ),
        const SizedBox(height: 14),
        _buildBullet(context, LocaleKeys.home_pro_prompt_bullet_topics.tr()),
        const SizedBox(height: 6),
        _buildBullet(context, LocaleKeys.home_pro_prompt_bullet_rings.tr()),
        const SizedBox(height: 6),
        _buildBullet(context, LocaleKeys.home_pro_prompt_bullet_support.tr()),
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
          label: LocaleKeys.common_not_now.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: onNotNow,
        ),
      ],
    );
  }

  Widget _buildBullet(BuildContext context, String text) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppGlyph(
            GlyphType.check,
            size: 13,
            color: colors.cobalt,
            strokeWidth: 2.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
