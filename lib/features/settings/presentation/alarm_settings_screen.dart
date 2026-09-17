import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// How an alarm rings: the default sound and quiet hours.
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

  static TimeOfDay _timeOf(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  /// The window in whatever clock the phone is set to, 24 hour or 12 hour.
  static String _label(BuildContext context, int minutes) =>
      _timeOf(minutes).format(context);

  /// Start first, then end. Either step can be backed out of, and nothing is
  /// saved until both are answered.
  Future<void> _pickWindow(
    BuildContext context,
    SettingsCubit cubit,
    SettingsState state,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _timeOf(state.quietHoursStartMinutes),
      helpText: LocaleKeys.settings_quiet_hours_start_picker_help.tr(),
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: _timeOf(state.quietHoursEndMinutes),
      helpText: LocaleKeys.settings_quiet_hours_end_picker_help.tr(),
    );
    if (end == null) return;

    await cubit.setQuietHoursWindow(
      startMinutes: start.hour * 60 + start.minute,
      endMinutes: end.hour * 60 + end.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final colors = context.appColors;
        final cubit = context.read<SettingsCubit>();
        final window = <String, String>{
          'start': _label(context, state.quietHoursStartMinutes),
          'end': _label(context, state.quietHoursEndMinutes),
        };

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
                        onTap: () => context.pushNamed(AppRoute.soundPicker),
                      ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.settings_quiet_hours_label.tr(),
                        subtitle: LocaleKeys.settings_quiet_hours_subtitle.tr(
                          namedArgs: window,
                        ),
                        value: state.quietHoursEnabled,
                        onChanged: (val) => unawaited(
                          cubit.toggleQuietHours(isEnabled: val),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppListRow(
                        name: LocaleKeys.settings_quiet_hours_window_row_title
                            .tr(),
                        meta: LocaleKeys.settings_quiet_hours_schedule.tr(
                          namedArgs: window,
                        ),
                        faceState: null,
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () =>
                            unawaited(_pickWindow(context, cubit, state)),
                      ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.settings_critical_rings_title.tr(),
                        subtitle: LocaleKeys.settings_critical_rings_subtitle
                            .tr(),
                        value: state.criticalRingsQuietHours,
                        onChanged: (val) => unawaited(
                          cubit.toggleCriticalRingsQuietHours(isEnabled: val),
                        ),
                      ),
                      // The escalation call row is still off this screen. It
                      // advertised a phone call, with a placeholder number, to
                      // a server that has no such route: api.md accepts `call`
                      // and ignores it. Putting it back needs a contract
                      // change first. Its state, cubit method and strings all
                      // stay where they are.
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
