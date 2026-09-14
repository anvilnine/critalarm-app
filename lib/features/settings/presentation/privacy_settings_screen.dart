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

/// What, if anything, the app sends back: usage analytics and crash reports.
/// Both are off until the user turns them on.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _PrivacySettingsView(),
    );
  }
}

class _PrivacySettingsView extends StatelessWidget {
  const _PrivacySettingsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.settings_privacy_header.tr(),
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
