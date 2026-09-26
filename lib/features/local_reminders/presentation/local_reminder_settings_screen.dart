import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Settings > Reminders. From install: Reminders on, Offers off.
class LocalReminderSettingsScreen extends StatelessWidget {
  const LocalReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<LocalReminderSettingsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _LocalReminderSettingsContent(),
    );
  }
}

class _LocalReminderSettingsContent extends StatefulWidget {
  const _LocalReminderSettingsContent();

  @override
  State<_LocalReminderSettingsContent> createState() =>
      _LocalReminderSettingsContentState();
}

class _LocalReminderSettingsContentState
    extends State<_LocalReminderSettingsContent>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from system settings: the OS state may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<LocalReminderSettingsCubit>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalReminderSettingsCubit, LocalReminderSettingsState>(
      builder: (context, state) {
        final colors = context.appColors;
        final cubit = context.read<LocalReminderSettingsCubit>();

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.reminders_screen_title.tr(),
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
                        title: LocaleKeys.reminders_switch_reminders_title.tr(),
                        subtitle: LocaleKeys.reminders_switch_reminders_subtitle
                            .tr(),
                        value: state.switches.reminders,
                        onChanged: (value) =>
                            unawaited(cubit.setReminders(isOn: value)),
                      ),
                      if (state.showsOffers) ...[
                        const SizedBox(height: 8),
                        AppToggleRow(
                          title: LocaleKeys.reminders_switch_offers_title.tr(),
                          subtitle: LocaleKeys.reminders_switch_offers_subtitle
                              .tr(),
                          value: state.switches.offers,
                          onChanged: (value) =>
                              unawaited(cubit.setOffers(isOn: value)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        LocaleKeys.reminders_rules_note.tr(),
                        style: AppTypography.small(colors.ink3, fontSize: 12),
                      ),
                      if (state.isLoaded && !state.notificationsAllowed) ...[
                        const SizedBox(height: 14),
                        AppListRow(
                          name: LocaleKeys.reminders_os_off_title.tr(),
                          meta: LocaleKeys.reminders_os_off_body.tr(),
                          faceState: FaceState.worried,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          onTap: () => unawaited(
                            getIt<OpenNotificationSettingsUsecase>()(
                              const NoParams(),
                            ),
                          ),
                        ),
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
