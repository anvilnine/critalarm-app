import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// How every alarm rings on this phone: the two ring switches, then the
/// default sound and what each priority does.
///
/// The default sound has one home, the Sound pass in Personalize. The row
/// here opens that same page. A browser has no alarm to ring, so it gets the
/// sound row alone.
class RingingSettingsScreen extends StatelessWidget {
  const RingingSettingsScreen({super.key, this.cubit});

  /// The Settings screen's own cubit, when the page draws in its detail
  /// pane. A pushed page leaves it null and loads its own.
  final SettingsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final shared = cubit;
    if (shared != null) {
      return BlocProvider.value(value: shared, child: const _RingingView());
    }
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _RingingView(),
    );
  }
}

class _RingingView extends StatelessWidget {
  const _RingingView();

  @override
  Widget build(BuildContext context) {
    final canRunAlarm = getIt<PlatformCapabilities>().canRunAlarm;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.settings_ringing_title.tr(),
            leading: settingsBackButton(context),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Every ring, every topic, every plan. The volume has no
                    // switch: every ring starts at full.
                    if (canRunAlarm) ...[
                      AppTitledCard(
                        title: LocaleKeys.settings_group_alarm_screen.tr(),
                        children: [
                          AppCardRow(
                            key: const ValueKey('settings-ring-bright-screen'),
                            title: LocaleKeys.settings_ring_bright_screen_title
                                .tr(),
                            detail: LocaleKeys
                                .settings_ring_bright_screen_subtitle
                                .tr(),
                            toggleValue: state.ring.brightScreen,
                            onToggle: (on) {
                              AppHaptics.selection();
                              unawaited(cubit.setRingBrightScreen(on: on));
                            },
                          ),
                          AppCardRow(
                            key: const ValueKey('settings-ring-vibrate'),
                            title: LocaleKeys.settings_ring_vibrate_title.tr(),
                            detail: LocaleKeys.settings_ring_vibrate_subtitle
                                .tr(),
                            toggleValue: state.ring.vibrate,
                            onToggle: (on) {
                              AppHaptics.selection();
                              unawaited(cubit.setRingVibrate(on: on));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    AppTitledCard(
                      title: LocaleKeys.settings_group_sound_priorities.tr(),
                      children: [
                        AppCardRow(
                          title: LocaleKeys.settings_alarm_sound_row_title.tr(),
                          detail: LocaleKeys.settings_alarm_sound_row_subtitle
                              .tr(),
                          onTap: () => unawaited(
                            context.push(SettingsLinks.defaultSound),
                          ),
                        ),
                        if (canRunAlarm)
                          AppCardRow(
                            title: LocaleKeys.settings_priorities_row_title
                                .tr(),
                            detail: LocaleKeys.settings_priorities_row_subtitle
                                .tr(),
                            onTap: () => unawaited(
                              context.push(SettingsLinks.priorities),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
