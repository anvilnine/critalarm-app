import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The server this phone is paged by: which host, and the admin token used
/// to talk to it.
class ServerSettingsScreen extends StatelessWidget {
  const ServerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _ServerSettingsView(),
    );
  }
}

class _ServerSettingsView extends StatelessWidget {
  const _ServerSettingsView();

  Future<void> _confirmDisconnect(
    BuildContext context,
    SettingsCubit cubit,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.settings_disconnect_dialog_title.tr(),
      body: LocaleKeys.settings_disconnect_dialog_content.tr(),
      actions: [
        AppDialogAction(
          label: LocaleKeys.common_cancel.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: LocaleKeys.settings_disconnect_dialog_confirm.tr(),
          value: true,
          variant: AppButtonVariant.crit,
        ),
      ],
    );

    if (confirmed == true) {
      AppHaptics.destructive();
      await cubit.disconnectServer();
    }
  }

  void _showEditServerSheet(
    BuildContext context,
    SettingsCubit cubit,
    SettingsState state,
  ) {
    final urlController = TextEditingController(text: state.serverUrl);
    final tokenController = TextEditingController(text: state.adminToken ?? '');
    final colors = context.appColors;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        // Same reason as the dialog: the sheet must sit above the floating
        // tab bar, which the shell draws over every branch screen.
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
          final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                16 + bottomInset + viewInsetsBottom,
              ),
              child: AppSheet(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.settings_edit_server_title.tr(),
                            style: TextStyle(
                              fontFamily: AppTypography.fontDisplay,
                              fontFamilyFallback:
                                  AppTypography.fontDisplayFallbacks,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                        ),
                        AppIconButton(
                          glyph: GlyphType.back,
                          size: 32,
                          glyphSize: 14,
                          ariaLabel: LocaleKeys.common_close.tr(),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: LocaleKeys.settings_server_url_label.tr(),
                      controller: urlController,
                      placeholder: 'https://api.critalarm.app',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: LocaleKeys.settings_admin_token_label.tr(),
                      controller: tokenController,
                      placeholder: LocaleKeys.settings_admin_token_placeholder
                          .tr(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: LocaleKeys.common_cancel.tr(),
                            variant: AppButtonVariant.ghost,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: LocaleKeys.common_save.tr(),
                            onPressed: () {
                              final newUrl = urlController.text.trim();
                              final newToken = tokenController.text.trim();
                              if (newUrl.isNotEmpty) {
                                unawaited(
                                  cubit.saveConnection(
                                    serverUrl: newUrl,
                                    adminToken: newToken,
                                  ),
                                );
                                Navigator.of(sheetContext).pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerCard(
    BuildContext context,
    SettingsCubit cubit,
    SettingsState state,
  ) {
    final colors = context.appColors;

    if (state.isConnected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.cobalt,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  LocaleKeys.settings_server_status_connected.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink3,
                  ),
                ),
                const Spacer(),
                if (state.serverMode == ServerMode.selfhosted)
                  Text(
                    LocaleKeys.settings_server_self_hosted.tr(),
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.ink3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              state.serverUrl.isNotEmpty
                  ? state.serverUrl
                  : 'api.critalarm.app',
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: LocaleKeys.settings_server_edit_button.tr(),
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.paper,
                    onPressed: () {
                      AppHaptics.capture();
                      _showEditServerSheet(context, cubit, state);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: LocaleKeys.settings_server_disconnect_button.tr(),
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    isLoading: state.isDisconnecting,
                    onPressed: () => _confirmDisconnect(context, cubit),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.ink3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                LocaleKeys.settings_server_status_disconnected.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.settings_server_disconnected_description.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.settings_server_connect_button.tr(),
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: () => context.push('/onboarding/connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.settings_server_connection_header.tr(),
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
                      _buildServerCard(context, cubit, state),
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
