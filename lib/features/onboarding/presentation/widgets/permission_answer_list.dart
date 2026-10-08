import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What a user who came back to the permissions step sees: every permission
/// of this phone with its answer, allowed or not allowed.
///
/// An allowed one shows a check and the word. One that is not allowed says
/// so in words and has a button, which is the only thing here that asks for
/// anything.
class PermissionAnswerList extends StatelessWidget {
  const PermissionAnswerList({
    required this.permissions,
    required this.granted,
    required this.promptSpent,
    required this.onAllow,
    super.key,
  });

  /// The steps of this phone that have a permission behind them, in order.
  final List<PermissionSetupStep> permissions;
  final Set<PermissionSetupStep> granted;
  final Set<PermissionSetupStep> promptSpent;

  /// Null while a system prompt is open, which greys the buttons.
  final ValueChanged<PermissionSetupStep>? onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final allAllowed = permissions.every(granted.contains);
    return Column(
      children: [
        SetupFace(
          state: allAllowed ? FaceState.success : FaceState.calm,
          gap: Spacing.s4,
        ),
        AppFittedTitle(
          LocaleKeys.onboarding_permissions_came_back_title.tr(),
          minFontSize: setupTitleMinFontSize,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          allAllowed
              ? LocaleKeys.onboarding_permissions_came_back_all_allowed.tr()
              : LocaleKeys.onboarding_permissions_came_back_some_missing.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s5),
        AppSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, step) in permissions.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                _AnswerRow(
                  name: _nameOf(step),
                  isAllowed: granted.contains(step),
                  opensSettings: permissionAnswerOpensSettings(
                    step,
                    promptSpent: promptSpent.contains(step),
                  ),
                  onAllow: onAllow == null ? null : () => onAllow!(step),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The name Settings, Permissions gives the same permission.
  static String _nameOf(PermissionSetupStep step) => switch (step.permission) {
    DevicePermissionType.notifications =>
      LocaleKeys.device_permissions_item_notifications_title.tr(),
    DevicePermissionType.alarms =>
      LocaleKeys.device_permissions_item_alarms_title.tr(),
    DevicePermissionType.fullScreenIntent =>
      LocaleKeys.device_permissions_item_full_screen_intent_title.tr(),
    DevicePermissionType.batteryOptimization =>
      LocaleKeys.device_permissions_item_battery_optimization_title.tr(),
    DevicePermissionType.timeSensitive =>
      LocaleKeys.device_permissions_item_time_sensitive_title.tr(),
    null => '',
  };
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.name,
    required this.isAllowed,
    required this.opensSettings,
    required this.onAllow,
  });

  final String name;
  final bool isAllowed;
  final bool opensSettings;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (isAllowed) {
      return Semantics(
        label: LocaleKeys.onboarding_permissions_answer_allowed_aria.tr(
          namedArgs: {'name': name},
        ),
        child: ExcludeSemantics(
          child: AppKeyValueRow(
            value: name,
            isMono: false,
            trailing: _AllowedChip(
              label: LocaleKeys.onboarding_permissions_allowed_badge.tr(),
            ),
          ),
        ),
      );
    }

    final buttonLabel = opensSettings
        ? LocaleKeys.onboarding_permissions_denied_open_settings.tr()
        : LocaleKeys.device_permissions_allow_button.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: LocaleKeys.onboarding_permissions_answer_not_allowed_aria
                  .tr(namedArgs: {'name': name}),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LocaleKeys.onboarding_permissions_answer_not_allowed.tr(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Every row has the same button, so a screen reader hears which
          // permission this one is for.
          Semantics(
            button: true,
            enabled: onAllow != null,
            label: '$buttonLabel, $name',
            onTap: onAllow,
            child: ExcludeSemantics(
              child: AppButton(
                label: buttonLabel,
                size: AppButtonSize.sm,
                onPressed: onAllow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A check and a word in a quiet pill, the same one Settings, Permissions
/// uses for a permission that needs no attention.
class _AllowedChip extends StatelessWidget {
  const _AllowedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.ash,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(
            GlyphType.check,
            size: 12,
            color: colors.ink2,
            strokeWidth: 2.4,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              letterSpacing: 0.2,
              color: colors.ink2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
