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
                      // Quiet hours, "critical still rings" and the
                      // escalation call are off this screen until they do
                      // something. Nothing saved these, nothing read them, and
                      // `SettingsCubit` is a factory, so leaving the screen
                      // reset all three to off. The escalation row also
                      // advertised a phone call, with a placeholder number, to
                      // a server that has no such route: api.md accepts `call`
                      // and ignores it.
                      //
                      // Quiet hours is written up as its own task. It needs
                      // the same window check in two places, because on the
                      // extension path the alarm is scheduled in Swift before
                      // Dart hears about the push at all
                      // (`incident_alarm_controller.dart`). The state and the
                      // cubit methods stay, and so do the strings, so that
                      // task is a wiring job rather than a rebuild.
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
