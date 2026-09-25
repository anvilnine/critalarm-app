import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// How the app looks, moves and feels: theme, reduce motion and haptics.
///
/// All three are app-wide, so the cubits come from the app root rather than
/// from this screen.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      topBar: AppTopBar(
        title: LocaleKeys.settings_appearance_header.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: AppSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSectionHeader(
                    LocaleKeys.settings_appearance_theme_header.tr(),
                  ),
                  const _ThemeControl(),
                  const SizedBox(height: 14),
                  AppSectionHeader(
                    LocaleKeys.settings_appearance_motion_header.tr(),
                  ),
                  const _MotionAndHaptics(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeControl extends StatelessWidget {
  const _ThemeControl();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, AppThemeMode>(
      builder: (context, themeMode) {
        return AppSegmentedControl<AppThemeMode>(
          items: AppThemeMode.values,
          selectedItem: themeMode,
          labelBuilder: (mode) => switch (mode) {
            AppThemeMode.system => LocaleKeys.settings_theme_system.tr(),
            AppThemeMode.light => LocaleKeys.settings_theme_light.tr(),
            AppThemeMode.dark => LocaleKeys.settings_theme_dark.tr(),
          },
          onChanged: (mode) {
            AppHaptics.selection();
            unawaited(context.read<ThemeCubit>().setMode(mode));
          },
        );
      },
    );
  }
}

class _MotionAndHaptics extends StatelessWidget {
  const _MotionAndHaptics();

  @override
  Widget build(BuildContext context) {
    // The OS setting, read past the app's own override: when the device
    // already asks for less motion, the switch shows on and cannot be turned
    // off here.
    final systemReduces = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.disableAnimations;

    return BlocBuilder<AppearanceCubit, AppearanceSettings>(
      builder: (context, settings) {
        final cubit = context.read<AppearanceCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppToggleRow(
              title: LocaleKeys.settings_reduce_motion_title.tr(),
              subtitle: systemReduces
                  ? LocaleKeys.settings_reduce_motion_system_subtitle.tr()
                  : LocaleKeys.settings_reduce_motion_subtitle.tr(),
              value: systemReduces || settings.reduceMotion,
              onChanged: systemReduces
                  ? null
                  : (value) {
                      AppHaptics.selection();
                      unawaited(cubit.setReduceMotion(enabled: value));
                    },
            ),
            // Web has no haptics, so there is nothing to switch.
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              AppToggleRow(
                title: LocaleKeys.settings_haptics_title.tr(),
                subtitle: LocaleKeys.settings_haptics_subtitle.tr(),
                value: settings.hapticsEnabled,
                onChanged: (value) {
                  // The cubit applies the choice at once, so this tick is
                  // felt when haptics go on and not when they go off.
                  unawaited(cubit.setHapticsEnabled(enabled: value));
                  AppHaptics.selection();
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
