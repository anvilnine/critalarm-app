import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The label next to the connected dot, one per mode. The screen used to
/// print "Self-hosted" whatever the server said, which hid a stale mode.
String serverModeLabelKey(ServerMode mode) => switch (mode) {
  ServerMode.selfhosted => LocaleKeys.settings_server_self_hosted,
  ServerMode.relay => LocaleKeys.settings_server_relay,
  ServerMode.hosted => LocaleKeys.settings_server_hosted,
};

/// The server this phone is paged by: which host, and the admin token used
/// to talk to it.
class ServerSettingsScreen extends StatelessWidget {
  const ServerSettingsScreen({super.key, this.cubit});

  /// The Settings screen's own cubit, when the page draws in its detail
  /// pane, so the row beside the page and the page read one state. A pushed
  /// page leaves it null and loads its own.
  final SettingsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final shared = cubit;
    if (shared != null) {
      return BlocProvider.value(
        value: shared,
        child: const _ServerSettingsView(),
      );
    }
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

/// Which field of the Edit server sheet a refused connect is about: the
/// admin token when the server asked for one or did not accept it, the
/// address for everything else.
bool editServerErrorIsOnToken(ConnectOutcome outcome) =>
    outcome is AdminTokenRefused || outcome is AdminTokenMissing;

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
    String? urlError;
    String? tokenError;
    var isSaving = false;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        // Same reason as the dialog: the sheet must sit above the floating
        // tab bar, which the shell draws over every branch screen.
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
            final viewInsetsBottom = MediaQuery.viewInsetsOf(
              sheetContext,
            ).bottom;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  16 + bottomInset + viewInsetsBottom,
                ),
                // The close button is a 32 circle in a 48 tap box. The sheet
                // gives up 8 of its top and right padding for the box, and
                // the rest of the sheet takes the right 8 back, so nothing
                // moves.
                child: AppSheet(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
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
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 8 less than the 14 it was: the box reaches 8
                            // below the circle.
                            const SizedBox(height: 6),
                            AppTextField(
                              label: LocaleKeys.settings_server_url_label.tr(),
                              controller: urlController,
                              placeholder: 'https://api.critalarm.app',
                              errorText: urlError,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              label: LocaleKeys.settings_admin_token_label.tr(),
                              controller: tokenController,
                              placeholder: LocaleKeys
                                  .settings_admin_token_placeholder
                                  .tr(),
                              errorText: tokenError,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: LocaleKeys.common_cancel.tr(),
                                    variant: AppButtonVariant.ghost,
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton(
                                    label: LocaleKeys.common_save.tr(),
                                    isLoading: isSaving,
                                    onPressed: () async {
                                      final newUrl = urlController.text.trim();
                                      final newToken = tokenController.text
                                          .trim();
                                      if (newUrl.isEmpty) return;
                                      setSheetState(() {
                                        isSaving = true;
                                        urlError = null;
                                        tokenError = null;
                                      });
                                      // The sheet stays up until the server
                                      // is checked, and closes only on a
                                      // connect that landed. Nothing is
                                      // saved before that.
                                      final outcome = await cubit
                                          .saveConnection(
                                            serverUrl: newUrl,
                                            adminToken: newToken,
                                          );
                                      if (!sheetContext.mounted) return;
                                      if (outcome == null ||
                                          outcome is Connected) {
                                        Navigator.of(sheetContext).pop();
                                        return;
                                      }
                                      final line = cubit.state.errorMessage;
                                      setSheetState(() {
                                        isSaving = false;
                                        if (editServerErrorIsOnToken(
                                          outcome,
                                        )) {
                                          tokenError = line;
                                        } else {
                                          urlError = line;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
                if (state.serverMode != null)
                  Flexible(
                    child: Text(
                      serverModeLabelKey(state.serverMode!).tr(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.ink3,
                      ),
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
            // The buttons are 36 pills in 48 tap boxes: 6 less above and
            // below them.
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: LocaleKeys.settings_server_edit_button.tr(),
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ink,
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
                    // Quieter than Edit: the same outline, in a softer ink.
                    foregroundColor: colors.ink2,
                    isLoading: state.isDisconnecting,
                    onPressed: () => _confirmDisconnect(context, cubit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              LocaleKeys.settings_server_disconnect_hint.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 12,
                color: colors.ink3,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      // The Connect button is a 36 pill in a 48 tap box: 6 less below it.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
          const SizedBox(height: 4),
          AppButton(
            label: LocaleKeys.settings_server_connect_button.tr(),
            size: AppButtonSize.sm,
            isFullWidth: true,
            // The connect screen closes back to here. Read the connection
            // again then, so the card shows the server it just saved.
            onPressed: () async {
              final settings = context.read<SettingsCubit>();
              await context.push<void>(OnboardingEntryPoint.connectServer);
              if (!settings.isClosed) await settings.load();
            },
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
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.settings_server_connection_header.tr(),
            // Beside the Settings rows, in the detail pane, there is no back.
            leading: settingsBackButton(context),
          ),
          slivers: [
            // One line of context under the title, as Health has, so the page
            // is not a lone card on an empty screen.
            SliverToBoxAdapter(
              child: AppStage.horizontal(
                faceState: state.isConnected
                    ? FaceState.calm
                    : FaceState.watching,
                sub: state.isConnected
                    ? LocaleKeys.settings_server_stage_connected.tr()
                    : LocaleKeys.settings_server_stage_disconnected.tr(),
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
