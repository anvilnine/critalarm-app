import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// SettingsScreen matching docs/design-system/index.html mobile mockup.
///
/// Everything with more than one control behind it lives on its own screen
/// under /settings. What stays here is the health summary, the rows that lead
/// to those screens, and the two single controls (theme and plan).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.forceDisconnected = false,
  });

  final bool forceDisconnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load(forceDisconnected: forceDisconnected));
        return cubit;
      },
      child: const _SettingsScreenContent(),
    );
  }
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  Widget _buildHealthIssuesChip(BuildContext context, int issueCount) {
    final colors = context.appColors;

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.high,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(
            GlyphType.up,
            size: 12,
            color: colors.inkFixed,
            strokeWidth: 2.4,
          ),
          const SizedBox(width: 6),
          Text(
            LocaleKeys.settings_health_badge_issues.plural(issueCount),
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
              color: colors.inkFixed,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// One row that leads to a screen under /settings.
  Widget _buildNavRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String path,
  }) {
    return AppListRow(
      name: title,
      meta: subtitle,
      // No face. A face reports how something is doing, and these rows only
      // open another screen. The Health row above keeps one because it does
      // report something.
      faceState: null,
      trailing: AppGlyph(
        GlyphType.arrow,
        color: context.appColors.ink3,
        size: 16,
      ),
      onTap: () => context.push(path),
    );
  }

  Widget _buildPlanRow(BuildContext context, SettingsState state) {
    final colors = context.appColors;
    final isPro = state.access.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !state.access.isKnown
                      ? 'Plan unavailable'
                      : isPro
                      ? LocaleKeys.settings_plan_pro.tr()
                      : LocaleKeys.settings_plan_free.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.criticalUsage,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 12,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro) ...[
            const SizedBox(width: 8),
            AppButton(
              label: LocaleKeys.settings_upgrade_button.tr(),
              size: AppButtonSize.sm,
              onPressed: () {
                AppHaptics.capture();
                unawaited(context.push('/paywall'));
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final colors = context.appColors;

        return AppScreenScaffold(
          topBar: AppTopBar(title: LocaleKeys.settings_title.tr()),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: Spacing.s2),
                  AppStage.horizontal(
                    faceState: FaceState.acked,
                    sub: LocaleKeys.settings_stage_sub.tr(),
                  ),
                  const SizedBox(height: Spacing.s3),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppListRow(
                        name: LocaleKeys.settings_health_row_title.tr(),
                        meta: LocaleKeys.settings_health_row_subtitle_issue
                            .tr(),
                        faceState: FaceState.worried,
                        trailing: _buildHealthIssuesChip(context, 1),
                        onTap: () => context.push('/settings/permissions'),
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_alarms_row_title.tr(),
                        subtitle: LocaleKeys.settings_alarms_row_subtitle.tr(),
                        path: '/settings/alarms',
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_server_row_title.tr(),
                        subtitle: LocaleKeys.settings_server_row_subtitle.tr(),
                        path: '/settings/server',
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_app_header.tr(),
                      ),
                      BlocBuilder<ThemeCubit, AppThemeMode>(
                        builder: (context, themeMode) {
                          return AppSegmentedControl<AppThemeMode>(
                            items: AppThemeMode.values,
                            selectedItem: themeMode,
                            labelBuilder: (mode) => switch (mode) {
                              AppThemeMode.system =>
                                LocaleKeys.settings_theme_system.tr(),
                              AppThemeMode.light =>
                                LocaleKeys.settings_theme_light.tr(),
                              AppThemeMode.dark =>
                                LocaleKeys.settings_theme_dark.tr(),
                            },
                            onChanged: (mode) {
                              AppHaptics.selection();
                              unawaited(
                                context.read<ThemeCubit>().setMode(mode),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_privacy_row_title.tr(),
                        subtitle: LocaleKeys.settings_privacy_row_subtitle.tr(),
                        path: '/settings/privacy',
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_about_row_title.tr(),
                        subtitle: LocaleKeys.settings_about_row_subtitle.tr(),
                        path: '/settings/about',
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_plan_header.tr(),
                      ),
                      _buildPlanRow(context, state),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_setup_header.tr(),
                      ),
                      AppListRow(
                        name: LocaleKeys.settings_redo_onboarding_title.tr(),
                        meta: LocaleKeys.settings_redo_onboarding_subtitle.tr(),
                        faceState: null,
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.pushNamed(AppRoute.onboarding),
                      ),
                      if (buildSkipsPaywall) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_developer_row_title.tr(),
                          subtitle: LocaleKeys.settings_developer_row_subtitle
                              .tr(),
                          path: '/settings/developer',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
