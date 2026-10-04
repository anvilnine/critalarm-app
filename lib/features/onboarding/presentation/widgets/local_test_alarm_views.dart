import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The countdown of the alarm the phone set for itself.
class LocalTestCountdownCard extends StatelessWidget {
  const LocalTestCountdownCard({
    required this.seconds,
    required this.line,
    required this.semanticLabel,
    super.key,
  });

  final int seconds;

  /// What to do while it counts. The seconds are the big number above it,
  /// so this line does not repeat them.
  final String line;

  /// The whole sentence, seconds included, for a screen reader.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: _card(colors),
    );
  }

  Widget _card(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onCanvas, width: 2),
        boxShadow: AppShadows.lightLg,
      ),
      child: Column(
        children: [
          Text(
            '${seconds}s',
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontFamilyFallback: AppTypography.fontDisplayFallbacks,
              fontWeight: FontWeight.w800,
              fontSize: 54,
              letterSpacing: -2,
              color: colors.crit,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Says why the phone did not set its own test alarm, and offers the one tap
/// that fixes it. Without this a refused alarm left the button looking dead.
///
/// [alarm] is what the phone answered about alarm access on that try.
Future<void> explainLocalTestAlarmFailure(
  BuildContext context,
  AlarmAuthorization alarm,
) async {
  if (alarm == AlarmAuthorization.notDetermined) {
    final allow = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.onboarding_connect_hook_not_asked_title.tr(),
      body: LocaleKeys.onboarding_connect_hook_not_asked_body.tr(),
      actions: [
        AppDialogAction(
          label: LocaleKeys.common_not_now.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: LocaleKeys.onboarding_connect_hook_not_asked_button.tr(),
          value: true,
        ),
      ],
    );
    if (allow == true && context.mounted) {
      await context.push('/permissions/ask');
    }
    return;
  }
  if (alarm == AlarmAuthorization.denied) {
    final open = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.onboarding_connect_hook_alarms_off_title.tr(),
      body: LocaleKeys.onboarding_connect_hook_alarms_off_body.tr(),
      actions: [
        AppDialogAction(
          label: LocaleKeys.common_not_now.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: LocaleKeys.onboarding_connect_hook_open_settings.tr(),
          value: true,
        ),
      ],
    );
    if (open == true) {
      await getIt<OpenPermissionSettingsUsecase>()(
        DevicePermissionType.alarms,
      );
    }
    return;
  }
  // An iPhone below iOS 26 has no alarm to set at all. Anything else is the
  // phone refusing, which on Android means Alarms & reminders is off.
  final oldIphone = RingClaim.forPhone(alarm) == RingClaim.timeSensitive;
  await showAppDialog<void>(
    context: context,
    title: oldIphone
        ? LocaleKeys.onboarding_connect_hook_no_alarm_title.tr()
        : LocaleKeys.onboarding_connect_hook_failed_title.tr(),
    body: oldIphone
        ? LocaleKeys.onboarding_connect_hook_no_alarm_body.tr()
        : LocaleKeys.onboarding_connect_hook_failed_body.tr(),
    actions: [
      AppDialogAction(
        label: LocaleKeys.onboarding_connect_hook_ok.tr(),
      ),
    ],
  );
}
