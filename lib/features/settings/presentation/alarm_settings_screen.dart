import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// How an alarm rings: the default sound, quiet hours, and the call that
/// follows a page nobody answered.
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
        final cubit = context.read<SettingsCubit>();

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
