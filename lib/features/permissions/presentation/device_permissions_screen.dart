import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen reachable from settings displaying device permissions:
/// Notifications, Full-screen intent, and Battery optimization exemption.
/// Automatically refreshes permissions on app resume.
class DevicePermissionsScreen extends StatelessWidget {
  const DevicePermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<DevicePermissionsCubit>();
        unawaited(cubit.loadPermissions());
        return cubit;
      },
      child: const _DevicePermissionsView(),
    );
  }
}

class _DevicePermissionsView extends StatefulWidget {
  const _DevicePermissionsView();

  @override
  State<_DevicePermissionsView> createState() => _DevicePermissionsViewState();
}

class _DevicePermissionsViewState extends State<_DevicePermissionsView>
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<DevicePermissionsCubit>().loadPermissions());
    }
  }

  // Placeholder server data. The cubit does not report a server connection
  // yet, so these stand in for the real host, check time and last delivery
  // until that data exists.
  static const _placeholderHost = 'api.critalarm.app';
  static const _placeholderCheckedAt = '09:45:02';
  static const _placeholderDeliveryTopic = 'prod-db';
  static const _placeholderDeliveryTiming = '03:12:04, 1.2 s';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicePermissionsCubit, DevicePermissionsState>(
      builder: (context, state) {
        final cubit = context.read<DevicePermissionsCubit>();

        final fullScreenItem = state.permissionByType(
          DevicePermissionType.fullScreenIntent,
        );
        final fullScreenOff =
            fullScreenItem != null && !fullScreenItem.status.isGranted;

        final stageFace = state.allGranted
            ? FaceState.calm
            : fullScreenOff
            ? FaceState.worried
            : FaceState.alarmed;
        final stageSub = fullScreenOff
            ? LocaleKeys.device_permissions_stage_sub_full_screen_off.tr()
            : state.allGranted
            ? LocaleKeys.device_permissions_stage_sub_all_granted.tr()
            : LocaleKeys.device_permissions_stage_sub_required.tr();

        return AppScreenScaffold(
          onRefresh: cubit.refresh,
          topBar: AppTopBar(
            title: LocaleKeys.device_permissions_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.device_permissions_back_aria_label.tr(),
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
              child: AppStage.horizontal(
                faceState: stageFace,
                sub: stageSub,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 16),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSectionHeader(
                        LocaleKeys.device_permissions_permissions_header.tr(),
                      ),
                      for (final item in state.permissions) ...[
                        _PermissionRow(
                          item: item,
                          onTurnOn: () {
                            AppHaptics.capture();
                            unawaited(cubit.openSettings(item.type));
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      AppSectionHeader(
                        LocaleKeys.device_permissions_server_header.tr(),
                      ),
                      AppKeyValueRow(
                        value: _placeholderHost,
                        trailing: _LowChip(
                          label: LocaleKeys.device_permissions_badge_reachable
                              .tr(),
                          glyph: GlyphType.wifi,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppKeyValueRow(
                        label: LocaleKeys.device_permissions_checked_label.tr(),
                        value: _placeholderCheckedAt,
                      ),
                      const SizedBox(height: 8),
                      AppKeyValueRow(
                        label: LocaleKeys.device_permissions_last_delivery_label
                            .tr(),
                        value:
                            '$_placeholderDeliveryTopic, '
                            '$_placeholderDeliveryTiming',
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: LocaleKeys.device_permissions_test_alarm_button
                            .tr(),
                        variant: AppButtonVariant.ghost,
                        isFullWidth: true,
                        onPressed: AppHaptics.capture,
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

/// One row under "Device permissions": a granted permission shows its name
/// and a status chip, an off permission shows its off-since line and a
/// "Turn on" button, matching index.html .kv and .row.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.item,
    required this.onTurnOn,
  });

  final DevicePermissionItem item;
  final VoidCallback onTurnOn;

  // Placeholder date. DevicePermissionItem does not carry the date a
  // permission was turned off, so this stands in until it does.
  static const _placeholderOffSinceDate = '12 September';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (!item.status.isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
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
                    LocaleKeys
                        .device_permissions_item_full_screen_intent_off_since
                        .tr(namedArgs: {'date': _placeholderOffSinceDate}),
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
            const SizedBox(width: 8),
            AppButton(
              label: LocaleKeys.device_permissions_turn_on_button.tr(),
              size: AppButtonSize.sm,
              onPressed: onTurnOn,
            ),
          ],
        ),
      );
    }

    final chipLabel = item.type == DevicePermissionType.batteryOptimization
        ? LocaleKeys.device_permissions_badge_unrestricted.tr()
        : LocaleKeys.device_permissions_badge_allowed.tr();

    return AppKeyValueRow(
      value: item.title,
      isMono: false,
      trailing: _LowChip(label: chipLabel, glyph: GlyphType.check),
    );
  }
}

/// Small pill matching index.html .chip.chip-low: quiet ash background,
/// used for a permission or server status that needs no attention.
class _LowChip extends StatelessWidget {
  const _LowChip({
    required this.label,
    required this.glyph,
  });

  final String label;
  final GlyphType glyph;

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
          AppGlyph(glyph, size: 12, color: colors.ink2, strokeWidth: 2.4),
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
