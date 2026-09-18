import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dismissible engagement prompt encouraging signed-out users to back up
/// topics. Snoozes for 7 days when dismissed.
class AccountPromptCard extends StatelessWidget {
  const AccountPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.lgAll,
          border: Border.all(color: colors.hairline, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const FaceWidget(state: FaceState.calm, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.home_account_prompt_title.tr(),
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.ink,
                    ),
                  ),
                ),
                AppIconButton(
                  glyph: GlyphType.close,
                  size: 28,
                  glyphSize: 12,
                  ariaLabel: LocaleKeys.common_close.tr(),
                  onPressed: () =>
                      context.read<HomePromptCubit>().dismissCurrent(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.home_account_prompt_body.tr(),
              style: AppTypography.small(colors.ink2),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: LocaleKeys.home_account_prompt_button.tr(),
              size: AppButtonSize.sm,
              isFullWidth: true,
              onPressed: () => openAppPath(context, '/settings/account'),
            ),
          ],
        ),
      ),
    );
  }
}
