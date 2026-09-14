import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// SettingsScreen matching docs/design-system/index.html mobile mockup.
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

  Widget _buildPriorityChip(PriorityLevel priority) => switch (priority) {
    PriorityLevel.critical => const AppPriorityChip.critical(),
    PriorityLevel.high => const AppPriorityChip.high(),
    PriorityLevel.defaultPriority => const AppPriorityChip.defaultPriority(),
    PriorityLevel.low => const AppPriorityChip.low(),
    PriorityLevel.min => const AppPriorityChip.min(),
  };

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

  Widget _buildPlanRow(BuildContext context) {
    final colors = context.appColors;
    // SettingsState carries no subscription or topic count yet, so the plan
    // reads as the free tier until it does.
    const topicsUsed = 4;
    const topicsLimit = 5;

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
                  LocaleKeys.settings_plan_free.tr(),
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
                  LocaleKeys.settings_plan_topics_used.tr(
                    namedArgs: {
                      'used': '$topicsUsed',
                      'limit': '$topicsLimit',
                    },
                  ),
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
      ),
    );
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    SettingsCubit cubit,
  ) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text(
          LocaleKeys.settings_disconnect_dialog_title.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontFamilyFallback: AppTypography.fontDisplayFallbacks,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        content: Text(
          LocaleKeys.settings_disconnect_dialog_content.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 14,
            color: colors.ink2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              LocaleKeys.common_cancel.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                color: colors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              LocaleKeys.settings_disconnect_dialog_confirm.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                color: colors.crit,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AppHaptics.destructive();
      await cubit.disconnectServer();
    }
  }

  void _showEditServerSheet(
    BuildContext context,
    SettingsCubit cubit,
    SettingsState state,
  ) {
    final urlController = TextEditingController(text: state.serverUrl);
    final tokenController = TextEditingController(text: state.adminToken ?? '');
    final colors = context.appColors;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        // Same reason as the dialog: the sheet must sit above the floating
        // tab bar, which the shell draws over every branch screen.
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
          final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                16 + bottomInset + viewInsetsBottom,
              ),
              child: AppSheet(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.settings_edit_server_title.tr(),
                            style: TextStyle(
                              fontFamily: AppTypography.fontDisplay,
                              fontFamilyFallback:
                                  AppTypography.fontDisplayFallbacks,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                        ),
                        AppIconButton(
                          glyph: GlyphType.back,
                          size: 32,
                          glyphSize: 14,
                          ariaLabel: LocaleKeys.common_close.tr(),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: LocaleKeys.settings_server_url_label.tr(),
                      controller: urlController,
                      placeholder: 'https://api.critalarm.app',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: LocaleKeys.settings_admin_token_label.tr(),
                      controller: tokenController,
                      placeholder: LocaleKeys.settings_admin_token_placeholder
                          .tr(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: LocaleKeys.common_cancel.tr(),
                            variant: AppButtonVariant.ghost,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: LocaleKeys.common_save.tr(),
                            onPressed: () {
                              final newUrl = urlController.text.trim();
                              final newToken = tokenController.text.trim();
                              if (newUrl.isNotEmpty) {
                                unawaited(
                                  cubit.saveConnection(
                                    serverUrl: newUrl,
                                    adminToken: newToken,
                                  ),
                                );
                                Navigator.of(sheetContext).pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerCard(
    BuildContext context,
    SettingsCubit cubit,
    SettingsState state,
  ) {
    final colors = context.appColors;

    if (state.isConnected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.cobalt,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  LocaleKeys.settings_server_status_connected.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink3,
                  ),
                ),
                const Spacer(),
                Text(
                  LocaleKeys.settings_server_self_hosted.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              state.serverUrl.isNotEmpty
                  ? state.serverUrl
                  : 'api.critalarm.app',
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: LocaleKeys.settings_server_edit_button.tr(),
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.paper,
                    onPressed: () {
                      AppHaptics.capture();
                      _showEditServerSheet(context, cubit, state);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: LocaleKeys.settings_server_disconnect_button.tr(),
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    isLoading: state.isDisconnecting,
                    onPressed: () => _confirmDisconnect(context, cubit),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.ink3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                LocaleKeys.settings_server_status_disconnected.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.settings_server_disconnected_description.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.settings_server_connect_button.tr(),
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: () => context.push('/onboarding/connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final colors = context.appColors;
        final cubit = context.read<SettingsCubit>();

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
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_alarms_header.tr(),
                      ),
                      AppListRow(
                        name: LocaleKeys.settings_alarm_sound_row_title.tr(),
                        meta: LocaleKeys.settings_alarm_sound_row_subtitle.tr(),
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.push('/settings/sounds'),
                      ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.settings_quiet_hours_label.tr(),
                        subtitle: LocaleKeys.settings_quiet_hours_subtitle.tr(),
                        value: state.quietHoursEnabled,
                        onChanged: (val) =>
                            cubit.toggleQuietHours(isEnabled: val),
                      ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.settings_critical_rings_title.tr(),
                        subtitle: LocaleKeys.settings_critical_rings_subtitle
                            .tr(),
                        value: state.criticalRingsQuietHours,
                        onChanged: (val) => cubit.toggleCriticalRingsQuietHours(
                          isEnabled: val,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_escalation_header.tr(),
                      ),
                      AppToggleRow(
                        title: LocaleKeys.settings_escalation_call_title.tr(),
                        subtitle: LocaleKeys.settings_escalation_call_subtitle
                            .tr(),
                        value: state.escalationCallEnabled,
                        onChanged: (val) =>
                            cubit.toggleEscalationCall(isEnabled: val),
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_per_topic_priority_header.tr(),
                      ),
                      for (final topic in state.topics) ...[
                        AppKeyValueRow(
                          value: topic.name,
                          trailing: _buildPriorityChip(topic.priority),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 6),
                      AppSectionHeader(
                        LocaleKeys.settings_server_connection_header.tr(),
                      ),
                      _buildServerCard(context, cubit, state),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_device_permissions_header.tr(),
                      ),
                      AppListRow(
                        name: LocaleKeys.settings_device_permissions_row_title
                            .tr(),
                        meta: LocaleKeys
                            .settings_device_permissions_row_subtitle
                            .tr(),
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.push('/settings/permissions'),
                      ),
                      const SizedBox(height: 8),
                      AppListRow(
                        name: LocaleKeys.settings_redo_onboarding_title.tr(),
                        meta: LocaleKeys.settings_redo_onboarding_subtitle.tr(),
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.pushNamed(AppRoute.onboarding),
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
                      AppSectionHeader(
                        LocaleKeys.settings_privacy_header.tr(),
                      ),
                      AppToggleRow(
                        title: LocaleKeys.settings_analytics_title.tr(),
                        subtitle: LocaleKeys.settings_analytics_subtitle.tr(),
                        value: state.analyticsEnabled,
                        onChanged: (val) =>
                            cubit.toggleAnalytics(isEnabled: val),
                      ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.settings_crash_reports_title.tr(),
                        subtitle: LocaleKeys.settings_crash_reports_subtitle
                            .tr(),
                        value: state.crashReportingEnabled,
                        onChanged: (val) =>
                            cubit.toggleCrashReporting(isEnabled: val),
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_about_header.tr(),
                      ),
                      AppKeyValueRow(
                        label: LocaleKeys.settings_about_version_label.tr(),
                        value: 'v$appVersion',
                      ),
                      const SizedBox(height: 8),
                      AppKeyValueRow(
                        label: LocaleKeys.settings_about_license_label.tr(),
                        value: LocaleKeys.settings_about_license_value.tr(),
                        isMono: false,
                      ),
                      const SizedBox(height: 8),
                      _AboutLinkRow(
                        label: LocaleKeys.settings_about_docs_label.tr(),
                        url: 'https://docs.critalarm.app',
                      ),
                      const SizedBox(height: 8),
                      _AboutLinkRow(
                        label: LocaleKeys.settings_about_github_label.tr(),
                        url: 'https://github.com/critalarm/critalarm',
                      ),
                      const SizedBox(height: 8),
                      _AboutLinkRow(
                        label: LocaleKeys.settings_about_issues_label.tr(),
                        url: 'https://github.com/critalarm/critalarm/issues',
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_plan_header.tr(),
                      ),
                      _buildPlanRow(context),
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

class _AboutLinkRow extends StatelessWidget {
  const _AboutLinkRow({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$label: $url',
      button: true,
      child: GestureDetector(
        onTap: () {
          unawaited(Clipboard.setData(ClipboardData(text: url)));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocaleKeys.settings_copied_toast.tr(namedArgs: {'url': url}),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.cream,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
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
                      url,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppGlyph(
                GlyphType.arrow,
                color: colors.ink3,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
