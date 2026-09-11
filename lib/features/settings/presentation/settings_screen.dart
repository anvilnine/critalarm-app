import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
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
                            const AppSectionHeader('Server & Account'),
                            AppKeyValueRow(
                              label: 'Server',
                              value: state.serverUrl,
                            ),
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
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
