import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// How an alarm rings, the default sound and quiet hours, and how long old
/// alarms stay on the phone.
class AlarmSettingsScreen extends StatelessWidget {
  const AlarmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _AlarmSettingsView(),
    );
  }
}

class _AlarmSettingsView extends StatelessWidget {
  const _AlarmSettingsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final colors = context.appColors;

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.settings_alarms_header.tr(),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppListRow(
                        name: LocaleKeys.settings_alarm_sound_row_title.tr(),
                        meta: LocaleKeys.settings_alarm_sound_row_subtitle.tr(),
                        faceState: null,
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.push('/settings/alarms/sounds'),
                      ),
                      // The quiet hours rows are off this screen for now:
                      // the toggle, the start and end window, and the
                      // critical-rings-through switch. `QuietHours`,
                      // `QuietHoursStore`, the cubit methods, the state
                      // fields and the strings all stay where they are.
                      // The window now defaults to off, so nothing holds
                      // a ring while there is no way to change it.
                      // The escalation call row is still off this screen. It
                      // advertised a phone call, with a placeholder number, to
                      // a server that has no such route: api.md accepts `call`
                      // and ignores it. Putting it back needs a contract
                      // change first. Its state, cubit method and strings all
                      // stay where they are.
                      if (state.hasStorageSection) ...[
                        const SizedBox(height: 14),
                        AppSectionHeader(
                          LocaleKeys.settings_storage_header.tr(),
                        ),
                        _StorageSection(state: state),
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

/// The two Storage rows. Shown on a paid tier and on a self-hosted server.
///
/// The phone keeps every alarm by default (api.md §4.2). These rows are the
/// user asking it to stop, and the switch keeps P5 alarms out of that.
class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.state});

  final SettingsState state;

  static String _label(HistoryRetention retention) => switch (retention) {
    HistoryRetention.never => LocaleKeys.settings_storage_delete_never.tr(),
    HistoryRetention.oneMonth => LocaleKeys.settings_storage_delete_1m.tr(),
    HistoryRetention.threeMonths =>
      LocaleKeys.settings_storage_delete_3m.tr(),
    HistoryRetention.oneYear => LocaleKeys.settings_storage_delete_1y.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeader(
          LocaleKeys.settings_storage_delete_after_title.tr(),
        ),
        AppSegmentedControl<HistoryRetention>(
          items: HistoryRetention.values,
          selectedItem: state.storage.retention,
          labelBuilder: _label,
          onChanged: (retention) {
            AppHaptics.selection();
            unawaited(cubit.setRetention(retention));
          },
        ),
        const SizedBox(height: 8),
        AppToggleRow(
          title: LocaleKeys.settings_storage_keep_critical_title.tr(),
          subtitle: LocaleKeys.settings_storage_keep_critical_subtitle.tr(),
          value: state.storage.keepCriticalForever,
          onChanged: (keep) =>
              unawaited(cubit.setKeepCriticalForever(keep: keep)),
        ),
      ],
    );
  }
}
