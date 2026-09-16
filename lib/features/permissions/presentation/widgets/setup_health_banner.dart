import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Says so, on the screen the user actually opens, when a device setting is
/// off and a page would not reach them.
///
/// The dot on the Settings tab is easy to miss and says nothing about what is
/// wrong. This names it and hands over a way to fix it.
class SetupHealthBanner extends StatelessWidget {
  const SetupHealthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, ShellHealth>(
      builder: (context, health) {
        if (health.isHealthy) return const SizedBox.shrink();
        return _Banner(health: health);
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.health});

  final ShellHealth health;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final missing = health.missing;

    final detail = missing.length == 1
        ? LocaleKeys.setup_health_banner_one.tr(
            namedArgs: {'name': missing.first.title},
          )
        : LocaleKeys.setup_health_banner_many.tr(
            namedArgs: {'count': '${missing.length}'},
          );

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
                    LocaleKeys.setup_health_banner_title.tr(),
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
              detail,
              style: AppTypography.small(colors.onCanvasMuted),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: LocaleKeys.setup_health_banner_button.tr(),
              size: AppButtonSize.sm,
              isFullWidth: true,
              onPressed: () => context.push('/settings/permissions'),
            ),
          ],
        ),
      ),
    );
  }
}
