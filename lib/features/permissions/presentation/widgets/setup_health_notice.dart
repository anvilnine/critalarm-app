import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Says so, on the screen the user actually opens, when a device setting is
/// off and a page would not reach them.
///
/// The dot on the Settings tab is easy to miss and says nothing about what is
/// wrong. This names it and hands over a way to fix it.
class SetupHealthNotice extends StatelessWidget {
  const SetupHealthNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, ShellHealth>(
      builder: (context, health) {
        if (health.isHealthy) return const SizedBox.shrink();
        return _Notice(health: health);
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.health});

  final ShellHealth health;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isWarningOnly = health.hasWarningsOnly;
    final isBatteryOnly = health.isBatteryOnlyWarning;

    final bannerColor = isWarningOnly ? colors.highCanvas : colors.critCanvas;
    final bannerStroke = isWarningOnly ? colors.highStroke : colors.critStroke;
    final faceState = isWarningOnly ? FaceState.watching : FaceState.worried;

    final title = isWarningOnly
        ? LocaleKeys.setup_health_banner_warning_title.tr()
        : LocaleKeys.setup_health_banner_title.tr();

    final String detail;
    if (isBatteryOnly) {
      detail = LocaleKeys.setup_health_banner_warning_battery.tr();
    } else {
      final relevantList = isWarningOnly
          ? health.warningMissing
          : health.criticalMissing;
      final effectiveList = relevantList.isNotEmpty
          ? relevantList
          : health.missing;
      detail = effectiveList.length == 1
          ? LocaleKeys.setup_health_banner_one.tr(
              namedArgs: {'name': effectiveList.first.title},
            )
          : LocaleKeys.setup_health_banner_many.tr(
              namedArgs: {'count': '${effectiveList.length}'},
            );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: Radii.lgAll,
          border: Border.all(color: bannerStroke, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                FaceWidget(state: faceState, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
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
              // This banner draws on Home but the fix lives on the
              // Settings tab, so opening it moves the tab bar too.
              onPressed: () => openAppPath(context, '/settings/permissions'),
            ),
          ],
        ),
      ),
    );
  }
}
