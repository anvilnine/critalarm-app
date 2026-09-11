import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// SettingsScreen matching docs/design-system/index.html mobile mockup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load());
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
          'Disconnect server?',
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontFamilyFallback: AppTypography.fontDisplayFallbacks,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to disconnect? You will stop receiving '
          'critical alarms until you reconnect.',
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
              'Cancel',
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
              'Disconnect',
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
                            'Edit server connection',
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
                          ariaLabel: 'Close',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'SERVER URL',
                      controller: urlController,
                      placeholder: 'https://api.critalarm.app',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'ADMIN TOKEN',
                      controller: tokenController,
                      placeholder: 'ad_...',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Cancel',
                            variant: AppButtonVariant.ghost,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Save',
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
                  'Connected',
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
                  'Self-hosted',
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
                    label: 'Edit',
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.paper,
                    onPressed: () =>
                        _showEditServerSheet(context, cubit, state),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Disconnect',
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
                'Disconnected',
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
            'No server connected. Connect to a server to receive '
            'critical alerts.',
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Connect server',
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
    final colors = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();

        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                AppSliverTopBar(
                  title: 'Settings',
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: 'Back',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: Spacing.s2),
                      AppStage.horizontal(
                        faceState: FaceState.acked,
                        sub: 'Quiet hours on. Critical still rings.',
                      ),
                      SizedBox(height: Spacing.s3),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        16 + bottomInset,
                      ),
                      child: AppSheet(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSectionHeader('Quiet hours'),
                            AppToggleRow(
                              title: '22:00 to 07:00',
                              subtitle: 'default and low stay silent',
                              value: state.quietHoursEnabled,
                              onChanged: (val) =>
                                  cubit.toggleQuietHours(isEnabled: val),
                            ),
                            const SizedBox(height: 8),
                            AppToggleRow(
                              title: 'Critical rings through quiet hours',
                              subtitle: 'and through the silent switch',
                              value: state.criticalRingsQuietHours,
                              onChanged: (val) =>
                                  cubit.toggleCriticalRingsQuietHours(
                                    isEnabled: val,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            const AppSectionHeader('Escalation'),
                            AppToggleRow(
                              title: 'Call after 5 min',
                              subtitle:
                                  'Repeats every 30 s first. +63 917 xxx 4821',
                              value: state.escalationCallEnabled,
                              onChanged: (val) =>
                                  cubit.toggleEscalationCall(isEnabled: val),
                            ),
                            const SizedBox(height: 14),
                            const AppSectionHeader('Per-topic priority'),
                            for (final topic in state.topics) ...[
                              AppKeyValueRow(
                                value: topic.name,
                                trailing: _buildPriorityChip(topic.priority),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 6),
                            const AppSectionHeader('Server connection'),
                            _buildServerCard(context, cubit, state),
                            const SizedBox(height: 14),
                            const AppSectionHeader('Device permissions'),
                            AppListRow(
                              name: 'Device permissions',
                              meta: 'Notifications, lock screen, battery',
                              trailing: AppGlyph(
                                GlyphType.arrow,
                                color: colors.ink3,
                                size: 16,
                              ),
                              onTap: () =>
                                  context.push('/settings/permissions'),
                            ),
                            const SizedBox(height: 14),
                            const AppSectionHeader('Theme'),
                            BlocBuilder<ThemeCubit, AppThemeMode>(
                              builder: (context, themeMode) {
                                return AppSegmentedControl<AppThemeMode>(
                                  items: AppThemeMode.values,
                                  selectedItem: themeMode,
                                  labelBuilder: (mode) => switch (mode) {
                                    AppThemeMode.system => 'System',
                                    AppThemeMode.light => 'Light',
                                    AppThemeMode.dark => 'Dark',
                                  },
                                  onChanged: (mode) {
                                    unawaited(
                                      context.read<ThemeCubit>().setMode(mode),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            const AppSectionHeader('Privacy'),
                            AppToggleRow(
                              title: 'Share anonymous usage analytics',
                              subtitle:
                                  'Shares anonymous feature usage and screen '
                                  'views to improve app stability.',
                              value: state.analyticsEnabled,
                              onChanged: (val) =>
                                  cubit.toggleAnalytics(isEnabled: val),
                            ),
                            const SizedBox(height: 8),
                            AppToggleRow(
                              title: 'Send crash reports',
                              subtitle:
                                  'Sends anonymized stack traces and device '
                                  'info when an unexpected error occurs.',
                              value: state.crashReportingEnabled,
                              onChanged: (val) =>
                                  cubit.toggleCrashReporting(isEnabled: val),
                            ),
                            const SizedBox(height: 14),
                            const AppSectionHeader('About'),
                            const AppKeyValueRow(
                              label: 'Version',
                              value: 'v$appVersion',
                            ),
                            const SizedBox(height: 8),
                            const AppKeyValueRow(
                              label: 'License',
                              value: 'GPL-3.0 License',
                              isMono: false,
                            ),
                            const SizedBox(height: 8),
                            const _AboutLinkRow(
                              label: 'Documentation',
                              url: 'https://docs.critalarm.app',
                            ),
                            const SizedBox(height: 8),
                            const _AboutLinkRow(
                              label: 'GitHub',
                              url: 'https://github.com/critalarm/critalarm',
                            ),
                            const SizedBox(height: 8),
                            const _AboutLinkRow(
                              label: 'Issue Tracker',
                              url:
                                  'https://github.com/critalarm/critalarm/issues',
                            ),
                            const SizedBox(height: 16),
                            AppButton(
                              label: 'Upgrade to Pro',
                              isFullWidth: true,
                              trailingIcon: AppGlyph(
                                GlyphType.arrow,
                                color: colors.onHighlight,
                                size: 16,
                              ),
                              onPressed: () => context.push('/paywall'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              content: Text('Copied $url'),
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
