import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dismissible monetization prompt showing bulleted Pro benefits.
/// Snoozes for 7 days when dismissed.
class ProPromptCard extends StatelessWidget {
  const ProPromptCard({super.key});

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
          border: Border.all(color: colors.cobalt, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.cobalt.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          LocaleKeys.home_pro_prompt_title.tr(),
                          style: TextStyle(
                            fontFamily: AppTypography.fontDisplay,
                            fontFamilyFallback:
                                AppTypography.fontDisplayFallbacks,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cobalt,
                          borderRadius: Radii.fullAll,
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.4,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
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
              LocaleKeys.home_pro_prompt_subtitle.tr(),
              style: AppTypography.small(colors.ink2),
            ),
            const SizedBox(height: 10),
            _buildBullet(
              context,
              LocaleKeys.home_pro_prompt_bullet_topics.tr(),
            ),
            const SizedBox(height: 6),
            _buildBullet(
              context,
              LocaleKeys.home_pro_prompt_bullet_rings.tr(),
            ),
            const SizedBox(height: 6),
            _buildBullet(
              context,
              LocaleKeys.home_pro_prompt_bullet_support.tr(),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: LocaleKeys.home_pro_prompt_button.tr(),
              size: AppButtonSize.sm,
              isFullWidth: true,
              onPressed: () => openAppPath(context, '/paywall'),
            ),
          ],
        ),
      ),
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
