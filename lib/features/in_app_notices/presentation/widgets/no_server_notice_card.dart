import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Critical blocker notice displayed on the home page when onboarding server
/// configuration was skipped or no server is connected.
class NoServerNoticeCard extends StatelessWidget {
  const NoServerNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.critCanvas,
          borderRadius: Radii.lgAll,
          border: Border.all(color: colors.critStroke, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const FaceWidget(state: FaceState.worried, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.home_server_banner_title.tr(),
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.onCanvas,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.home_server_banner_body.tr(),
              style: AppTypography.small(colors.onCanvasMuted),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: LocaleKeys.home_server_banner_button.tr(),
              size: AppButtonSize.sm,
              isFullWidth: true,
              onPressed: () => openAppPath(context, '/onboarding/connect'),
            ),
          ],
        ),
      ),
    );
  }
}
