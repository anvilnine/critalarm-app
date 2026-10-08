import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/feature_guides/presentation/widgets/feature_guide_picker_sheet.dart';
import 'package:critalarm/features/feedback/presentation/help_section.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/settings_reliability_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// SettingsScreen matching docs/design-system/index.html mobile mockup.
///
/// Everything with more than one control behind it lives on its own screen
/// under /settings. What stays here is the health summary, the rows that lead
/// to those screens, and the one single control (plan).
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

  /// A phone on a server of its own has no plan, so this says so and offers
  /// nothing to buy. The second line is plain text, not a link.
  Widget _buildSelfHostedPlanRow(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prose, so the title is set in the body face and wraps. AppListRow
        // sets every name in mono, which is for topic names and the like.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.mdAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.settings_plan_selfhosted_title.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                LocaleKeys.settings_plan_selfhosted_subtitle.tr(),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(
            LocaleKeys.settings_plan_selfhosted_cloud_note.tr(),
            style: AppTypography.small(colors.ink3, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRow(BuildContext context, SettingsState state) {
    if (isOwnServerMode(state.serverMode)) {
      return _buildSelfHostedPlanRow(context);
    }
    final colors = context.appColors;
    final isPro = state.holdsHosted;
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        // A purchase the store confirmed counts as Pro before
                        // the server has registered it.
                        isPro
                            ? LocaleKeys.settings_plan_pro.tr()
                            : !state.access.isKnown
                            ? LocaleKeys.account_plan_unavailable.tr()
                            : LocaleKeys.settings_plan_free.tr(),
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
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
                unawaited(
                  context.push(
                    hostedPaywallLocation(PaywallSource.settingsPlan),
                  ),
                );
              },
            ),
          ] else if (!buildSkipsPaywall) ...[
            // The store's own subscription page, through the RevenueCat
            // customer centre. A build that skips the paywall never
            // configures RevenueCat, and has no subscription to manage.
            const SizedBox(width: 8),
            AppButton(
              label: LocaleKeys.settings_plan_manage_button.tr(),
              size: AppButtonSize.sm,
              variant: AppButtonVariant.paper,
              onPressed: () {
                AppHaptics.capture();
                unawaited(getIt<PaywallCubit>().presentCustomerCenter());
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
            /*
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: Spacing.s2),
                  AppStage.horizontal(
                    faceState: FaceState.acked,
                    // Quiet hours is off by default and its rows are off the
                    // alarm screen, so the line only shows when it is on.
                    sub: state.quietHoursEnabled
                        ? LocaleKeys.settings_stage_sub.tr()
                        : null,
                  ),
                  const SizedBox(height: Spacing.s3),
                ],
              ),
            ),
            */
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The first row. It reads the reliability checks and
                      // opens the screen that lists them.
                      const FeatureGuideAnchor(
                        id: FeatureGuideAnchorId.settingsHealth,
                        child: SettingsReliabilityEntry(),
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_alarm_sound_row_title.tr(),
                        subtitle: LocaleKeys.settings_alarm_sound_row_subtitle
                            .tr(),
                        path: '/sounds',
                      ),
                      // A browser has no push and no alarm to describe.
                      if (getIt<PlatformCapabilities>().canRunAlarm) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_priorities_row_title.tr(),
                          subtitle: LocaleKeys.settings_priorities_row_subtitle
                              .tr(),
                          path: '/settings/priorities',
                        ),
                      ],
                      // Storage is the only thing left of the old Alarms
                      // page, and it only shows on a paid tier or a
                      // self-hosted server.
                      if (state.hasStorageSection) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_storage_row_title.tr(),
                          subtitle: LocaleKeys.settings_storage_row_subtitle
                              .tr(),
                          path: '/settings/alarms',
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_server_row_title.tr(),
                        subtitle: LocaleKeys.settings_server_row_subtitle.tr(),
                        path: '/settings/server',
                      ),
                      if (state.hasAccounts) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.account_row_title.tr(),
                          subtitle: LocaleKeys.account_row_subtitle.tr(),
                          path: '/settings/account',
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_app_header.tr(),
                      ),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.personalize_title.tr(),
                        subtitle: LocaleKeys.personalize_row_subtitle.tr(),
                        path: '/settings/personalize',
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_appearance_row_title.tr(),
                        subtitle: LocaleKeys.settings_appearance_row_subtitle
                            .tr(),
                        path: '/settings/appearance',
                      ),
                      // Web has no local notifications, so no reminders.
                      if (getIt<PlatformCapabilities>()
                          .hasLocalNotifications) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.local_reminders_settings_row_title
                              .tr(),
                          subtitle: LocaleKeys
                              .local_reminders_settings_row_subtitle
                              .tr(),
                          path: '/settings/local-reminders',
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_plan_header.tr(),
                      ),
                      _buildPlanRow(context, state),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_setup_header.tr(),
                      ),
                      FeatureGuideAnchor(
                        id: FeatureGuideAnchorId.settingsFeatureGuides,
                        child: AppListRow(
                          name: LocaleKeys.settings_feature_guides_row_title
                              .tr(),
                          meta: LocaleKeys.settings_feature_guides_row_subtitle
                              .tr(),
                          faceState: null,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          onTap: () =>
                              unawaited(showFeatureGuidePickerSheet(context)),
                        ),
                      ),
                      // Debug and developer-flag builds only (the same flags
                      // that show Developer options). A store user gets the
                      // Feature Guides above.
                      if (kDebugMode ||
                          buildSkipsPaywall ||
                          buildHasPaywallLab) ...[
                        const SizedBox(height: 8),
                        AppListRow(
                          name: LocaleKeys.settings_redo_onboarding_title.tr(),
                          meta: LocaleKeys.settings_redo_onboarding_subtitle
                              .tr(),
                          faceState: null,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          // From Settings this is a look at the screens, not
                          // a real run, so no step is skipped for being
                          // granted.
                          onTap: () => context.pushNamed(
                            AppRoute.onboardingWelcome,
                            queryParameters: const {'demo': 'true'},
                          ),
                        ),
                      ],
                      if (buildSkipsPaywall || buildHasPaywallLab) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_developer_row_title.tr(),
                          subtitle: LocaleKeys.settings_developer_row_subtitle
                              .tr(),
                          path: '/settings/developer',
                        ),
                      ],
                      const SizedBox(height: 14),
                      const HelpSection(),
                      const SizedBox(height: 8),
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
