import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return BlocBuilder<DevicePermissionsCubit, DevicePermissionsState>(
      builder: (context, state) {
        final cubit = context.read<DevicePermissionsCubit>();

        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                AppSliverTopBar(
                  title: 'Device Permissions',
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: 'Back',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    },
                  ),
                  trailing: AppIconButton(
                    glyph: GlyphType.repeat,
                    ariaLabel: 'Refresh',
                    onPressed: () => unawaited(cubit.refresh()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: Spacing.s2),
                      AppStage.horizontal(
                        faceState: state.allGranted
                            ? FaceState.calm
                            : FaceState.alarmed,
                        sub: state.allGranted
                            ? 'All permissions active. '
                                  'Ready to wake you at 3am.'
                            : 'Permissions required for '
                                  'alarm delivery through DND.',
                      ),
                      const SizedBox(height: Spacing.s3),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        16 + bottomInset,
                      ),
                      child: AppSheet(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSectionHeader(
                              'Critical Alarm Capabilities',
                            ),
                            for (
                              var i = 0;
                              i < state.permissions.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _PermissionCard(
                                item: state.permissions[i],
                                onFix: () => unawaited(
                                  cubit.openSettings(state.permissions[i].type),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const AppNote(
                              text:
                                  'Crit Alarm relies on direct system level '
                                  'access so critical alerts break through '
                                  'silent switches, lock screens, and battery '
                                  'restrictions.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.item,
    required this.onFix,
  });

  final DevicePermissionItem item;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.lgAll,
        border: Border.all(
          color: item.status.isGranted
              ? colors.hairline
              : colors.crit.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01 * 16,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PermissionStatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (item.canFix)
            AppButton(
              label: 'Fix in Settings',
              size: AppButtonSize.sm,
              isFullWidth: true,
              trailingIcon: AppGlyph(
                GlyphType.arrow,
                color: colors.onHighlight,
              ),
              onPressed: onFix,
            )
          else
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E7D32),
                  ),
                  alignment: Alignment.center,
                  child: const AppGlyph(
                    GlyphType.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Permission granted',
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Status badge: Granted in green/calm, Denied in red/alarmed, Restricted in yellow/warning.
class _PermissionStatusBadge extends StatelessWidget {
  const _PermissionStatusBadge({required this.status});

  final DevicePermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, faceState, bg, fg, border) = switch (status) {
      DevicePermissionStatus.granted => (
        'Granted',
        FaceState.calm,
        isDark ? const Color(0xFF1B381E) : const Color(0xFFE8F5E9),
        isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
        Border.all(
          color: isDark ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7),
          width: 1.5,
        ),
      ),
      DevicePermissionStatus.denied => (
        'Denied',
        FaceState.alarmed,
        colors.critTint,
        colors.crit,
        Border.all(color: colors.crit, width: 1.5),
      ),
      DevicePermissionStatus.restricted => (
        'Restricted',
        FaceState.worried,
        colors.yellow.withValues(alpha: 0.3),
        colors.high,
        Border.all(color: colors.high, width: 1.5),
      ),
      DevicePermissionStatus.notDetermined => (
        'Not Set',
        FaceState.watching,
        colors.ash,
        colors.ink2,
        Border.all(color: colors.hairline, width: 1.5),
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.fullAll,
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaceWidget(
            state: faceState,
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
