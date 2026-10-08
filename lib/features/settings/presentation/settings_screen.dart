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
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:critalarm/features/settings/presentation/settings_readiness_card.dart';
import 'package:critalarm/features/settings/presentation/settings_row_values.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Settings tab: a dark card on top that answers "will it wake me?", then
/// a white sheet of rows.
///
/// Everything with more than one control behind it lives on its own screen
/// under /settings. What stays here is the readiness card, the rows that lead
/// to those screens, and the plan. There is no face scene: a list gets none.
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

  /// One row that leads to a screen under /settings. [value] is what the row
  /// is set to, when that is already known, and sits before the arrow.
  Widget _buildNavRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String path,
    String? value,
  }) {
    final colors = context.appColors;
    return AppListRow(
      name: title,
      meta: subtitle,
      // No face. A face reports how something is doing, and these rows only
      // open another screen. The readiness card above keeps one because it
      // does report something.
      faceState: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            // The value is chrome: it stops growing with the text size so it
            // never squeezes the row's title out.
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: kChromeMaxTextScale),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(colors.ink3, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
        ],
      ),
      onTap: () => context.push(path),
    );
  }

  /// A phone on a server of its own has no plan, so this says so and offers
  /// nothing to buy. The second line is plain text, not a link.
  Widget _buildSelfHostedPlanRow(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsPlanCard(
          title: LocaleKeys.settings_plan_selfhosted_title.tr(),
          usage: LocaleKeys.settings_plan_selfhosted_subtitle.tr(),
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
    // A purchase the store confirmed counts as Hosted before the server has
    // registered it.
    final isHosted = state.holdsHosted;
    final access = state.access;
    final limit = access.caps?.criticalTopics;
    return SettingsPlanCard(
      title: isHosted
          ? LocaleKeys.settings_plan_pro.tr()
          : !access.isKnown
          ? LocaleKeys.account_plan_unavailable.tr()
          : LocaleKeys.settings_plan_free.tr(),
      usage: state.criticalUsage,
      // The bar is the free allowance. Hosted, a purchase still being
      // confirmed (held already) and an unknown plan have none to show.
      fraction: isHosted || !access.isKnown
          ? null
          : planUsageFraction(
              used: access.criticalCount(state.topics),
              limit: limit,
            ),
      actionLabel: !isHosted
          ? LocaleKeys.settings_card_plan_upgrade.tr()
          : !buildSkipsPaywall
          // The store's own subscription page, through the RevenueCat
          // customer centre. A build that skips the paywall never
          // configures RevenueCat, and has no subscription to manage.
          ? LocaleKeys.settings_plan_manage_button.tr()
          : null,
      onAction: !isHosted
          ? () {
              AppHaptics.capture();
              unawaited(
                context.push(
                  hostedPaywallLocation(PaywallSource.settingsPlan),
                ),
              );
            }
          : !buildSkipsPaywall
          ? () {
              AppHaptics.capture();
              unawaited(getIt<PaywallCubit>().presentCustomerCenter());
            }
          : null,
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
            // The dark card. It reads the same checks as the Topics card and
            // opens the screen that lists them.
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FeatureGuideAnchor(
                  id: FeatureGuideAnchorId.settingsHealth,
                  child: SettingsReadinessCard(),
                ),
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
                          value: settingsStorageValueKey(
                            state.storage.retention,
                          ).tr(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_server_row_title.tr(),
                        subtitle: LocaleKeys.settings_server_row_subtitle.tr(),
                        path: '/settings/server',
                        value: settingsServerValueKey(
                          status: state.status,
                          isConnected: state.isConnected,
                          mode: state.serverMode,
                        )?.tr(),
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
                      BlocBuilder<ThemeCubit, AppThemeMode>(
                        bloc: getIt<ThemeCubit>(),
                        builder: (context, mode) => _buildNavRow(
                          context,
                          title: LocaleKeys.settings_appearance_row_title.tr(),
                          subtitle: LocaleKeys.settings_appearance_row_subtitle
                              .tr(),
                          path: '/settings/appearance',
                          value: settingsThemeValueKey(mode).tr(),
                        ),
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
