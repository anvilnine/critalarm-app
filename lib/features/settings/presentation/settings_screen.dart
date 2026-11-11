import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:critalarm/features/settings/presentation/account_plan_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/appearance_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/help_feedback_screen.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_screen.dart';
import 'package:critalarm/features/settings/presentation/privacy_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/ringing_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_account_hero.dart';
import 'package:critalarm/features/settings/presentation/settings_readiness_card.dart';
import 'package:critalarm/features/settings/presentation/settings_row_values.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Settings tab: the account and plan card on top, the phone checks card
/// under it, then a few titled white cards of one-line rows.
///
/// Each group's title is the first line inside its own card, in the display
/// face, so it reads as a title and never as a row's description. Every row
/// opens a page under /settings. The plan, Pro, the account, Sign out and
/// Delete account live on Account and plan. The ring switches, the default
/// sound link and Priorities live on Ringing. Feature Guides and the help
/// rows live on Help and feedback, and the developer rows on About. The phone
/// checks card keeps the only face on the tab, because it reports something.
///
/// Where the display has a detail pane (an expanded window, or book posture
/// on a foldable), the cards are the list and a row's page draws in the pane
/// beside them, starting with Account and plan. Nothing is pushed and the URL
/// stays /settings. Rows whose page belongs to another feature still push it.
/// In tabletop posture the phone checks card holds still in the top half and
/// the rest scrolls in the bottom half.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.forceDisconnected = false,
  });

  final bool forceDisconnected;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = getIt<SettingsCubit>();
            unawaited(cubit.load(forceDisconnected: forceDisconnected));
            return cubit;
          },
        ),
        // How the card on top says you are signed in.
        BlocProvider(
          create: (_) {
            final cubit = getIt<AccountCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
      ],
      child: _SettingsScreenContent(forceDisconnected: forceDisconnected),
    );
  }
}

/// The gap between two cards.
const double _kCardGap = 14;

class _SettingsScreenContent extends StatefulWidget {
  const _SettingsScreenContent({required this.forceDisconnected});

  /// The lost-server screen. Its pane opens on Server from the first frame.
  final bool forceDisconnected;

  @override
  State<_SettingsScreenContent> createState() => _SettingsScreenContentState();
}

class _SettingsScreenContentState extends State<_SettingsScreenContent> {
  /// The row whose page the detail pane shows. Null until a row is tapped
  /// or the saved connection has been read, and the pane opens on
  /// [_paneSelection] until then.
  SettingsPage? _selected;

  /// The pages the rows lead to on this phone, in row order.
  List<SettingsPage> _pagesShown() => settingsPagesShown(
    hasLocalNotifications: getIt<PlatformCapabilities>().hasLocalNotifications,
  );

  /// The page the pane shows for [state]. A phone that has lost its server
  /// opens on Server, the page that can fix it. Null while the pane waits
  /// for the connection read.
  SettingsPage? _paneSelection(SettingsState state) => settingsPaneOpening(
    selected: _selected,
    shown: _pagesShown(),
    connectionKnown: state.connectionKnown,
    isConnected: state.isConnected,
    forceDisconnected: widget.forceDisconnected,
  );

  /// The page of [page] as it draws in the detail pane. The pages that read
  /// [SettingsCubit] share this screen's, so the row beside the page shows
  /// what the page just changed.
  Widget _panePage(BuildContext context, SettingsPage page) => switch (page) {
    SettingsPage.accountPlan => AccountPlanScreen(
      settingsCubit: context.read<SettingsCubit>(),
      accountCubit: context.read<AccountCubit>(),
    ),
    SettingsPage.ringing => RingingSettingsScreen(
      cubit: context.read<SettingsCubit>(),
    ),
    SettingsPage.personalize => const PersonalizeScreen(),
    SettingsPage.appearance => const AppearanceSettingsScreen(),
    SettingsPage.server => ServerSettingsScreen(
      cubit: context.read<SettingsCubit>(),
    ),
    SettingsPage.storage => AlarmSettingsScreen(
      cubit: context.read<SettingsCubit>(),
    ),
    SettingsPage.privacy => PrivacySettingsScreen(
      cubit: context.read<SettingsCubit>(),
    ),
    SettingsPage.help => const HelpFeedbackScreen(),
    SettingsPage.about => const AboutScreen(),
    // Never selected: these push. See SettingsPage.opensInPane.
    SettingsPage.language ||
    SettingsPage.localReminders => const SizedBox.shrink(),
  };

  /// Opens [page] for a tap on its row. [shown] is the page the pane shows
  /// now, or null with no pane.
  void _open(BuildContext context, SettingsPage page, SettingsPage? shown) {
    final tap = settingsRowTapFor(
      showsDetail: AppScreenScaffold.showsDetail(context),
      page: page,
    );
    switch (tap) {
      case SettingsRowTap.select:
        if (page != shown) AppHaptics.selection();
        setState(() => _selected = page);
      case SettingsRowTap.push:
        final account = context.read<AccountCubit>();
        unawaited(
          context.push(page.path).then((_) {
            // Signing in or out on Account and plan changes the line on
            // the card on top.
            if (page == SettingsPage.accountPlan && !account.isClosed) {
              unawaited(account.load());
            }
          }),
        );
    }
  }

  /// One row that leads to a page under /settings. [value] is what the row
  /// is set to, when that is already known, and sits before the arrow.
  /// [shown] is the page the pane shows, or null with no pane.
  Widget _row(
    BuildContext context, {
    required SettingsPage? shown,
    required String title,
    required SettingsPage page,
    String? value,
    bool isMonoValue = false,
  }) => AppCardRow(
    title: title,
    value: value,
    isMonoValue: isMonoValue,
    isSelected: page == shown,
    onTap: () => _open(context, page, shown),
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      // Once the saved connection has been read, the page the pane opened
      // on stays put: a phone that opened on Server because it had lost its
      // server keeps Server when it connects again from that page.
      listenWhen: (was, now) => !was.connectionKnown && now.connectionKnown,
      listener: (context, state) {
        if (_selected == null) {
          setState(() => _selected = _paneSelection(state));
        }
      },
      builder: (context, state) {
        final capabilities = getIt<PlatformCapabilities>();
        final showsDetail = AppScreenScaffold.showsDetail(context);
        // Tabletop: the phone checks card holds still in the top half, over
        // the fold, and the rest scrolls in the bottom half.
        final cardOnStage = AppFold.of(context).isTabletop;
        final selection = _paneSelection(state);
        // The page the pane shows, or null where there is no pane.
        final shown = showsDetail ? selection : null;

        // The dark card. It reads the same checks as the Topics card and
        // opens the screen that lists them. The one face on the tab.
        const checks = FeatureGuideAnchor(
          id: FeatureGuideAnchorId.settingsHealth,
          child: SettingsReadinessCard(),
        );

        final hero = SettingsAccountHero(
          state: state,
          isSelected: shown == SettingsPage.accountPlan,
          onOpen: () => _open(context, SettingsPage.accountPlan, shown),
        );

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.settings_title.tr(),
            isTabRoot: true,
          ),
          detail: shown != null
              ? SettingsPaneScope(
                  key: ValueKey(shown),
                  child: _panePage(context, shown),
                )
              // Nothing tapped and the connection not read yet: the pane's
              // own quiet surface with no page in it, so the first row's
              // page is never drawn and then swapped for Server, and the
              // list does not move when the page arrives.
              : showsDetail &&
                    !widget.forceDisconnected &&
                    !state.connectionKnown
              ? const SizedBox.shrink()
              : null,
          // The card keeps the width of the rows' column below the fold and
          // rests in the middle of the half under the title.
          foldStage: cardOnStage
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSize.contentMaxWidth,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: checks,
                    ),
                  ),
                )
              : null,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                // With no title row above it, the first card keeps the gap
                // the other tab roots leave at the top.
                padding: EdgeInsets.fromLTRB(
                  12,
                  AppTopBar.tabBarNamesTabs(context) ? Spacing.s4 : 0,
                  12,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    hero,
                    if (!cardOnStage) ...[
                      const SizedBox(height: 12),
                      checks,
                    ],
                    const SizedBox(height: _kCardGap),
                    AppTitledCard(
                      title: LocaleKeys.settings_group_alarms.tr(),
                      children: [
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.settings_ringing_title.tr(),
                          page: SettingsPage.ringing,
                        ),
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.personalize_title.tr(),
                          page: SettingsPage.personalize,
                        ),
                      ],
                    ),
                    const SizedBox(height: _kCardGap),
                    AppTitledCard(
                      title: LocaleKeys.settings_app_header.tr(),
                      children: [
                        BlocBuilder<ThemeCubit, AppThemeMode>(
                          bloc: getIt<ThemeCubit>(),
                          builder: (context, mode) => _row(
                            context,
                            shown: shown,
                            title: LocaleKeys.settings_appearance_row_title
                                .tr(),
                            page: SettingsPage.appearance,
                            value: settingsThemeValueKey(mode).tr(),
                          ),
                        ),
                        BlocBuilder<LanguageCubit, LanguageState>(
                          bloc: getIt<LanguageCubit>(),
                          builder: (context, language) => _row(
                            context,
                            shown: shown,
                            title: LocaleKeys.language_title.tr(),
                            page: SettingsPage.language,
                            value: language.selectedTag == null
                                ? LocaleKeys.language_system_default.tr()
                                : languageNativeNames[language.selectedTag] ??
                                      '',
                          ),
                        ),
                        // Web has no local notifications, so no reminders.
                        if (capabilities.hasLocalNotifications)
                          _row(
                            context,
                            shown: shown,
                            title: LocaleKeys.local_reminders_settings_row_title
                                .tr(),
                            page: SettingsPage.localReminders,
                          ),
                      ],
                    ),
                    const SizedBox(height: _kCardGap),
                    AppTitledCard(
                      title: LocaleKeys.settings_group_server_data.tr(),
                      children: [
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.settings_server_row_title.tr(),
                          page: SettingsPage.server,
                          value: settingsServerValueKey(
                            status: state.status,
                            isConnected: state.isConnected,
                            mode: state.serverMode,
                          )?.tr(),
                        ),
                        // Storage only touches this phone's own copy, so it
                        // is there on every plan.
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.settings_storage_row_title.tr(),
                          page: SettingsPage.storage,
                          value: settingsStorageValueKey(
                            state.storage.retention,
                          ).tr(),
                        ),
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.settings_privacy_row_title.tr(),
                          page: SettingsPage.privacy,
                        ),
                      ],
                    ),
                    const SizedBox(height: _kCardGap),
                    AppTitledCard(
                      title: LocaleKeys.settings_help_header.tr(),
                      children: [
                        // Feature Guides moved one level down, so the guide
                        // step that points at them points at this row.
                        FeatureGuideAnchor(
                          id: FeatureGuideAnchorId.settingsFeatureGuides,
                          child: _row(
                            context,
                            shown: shown,
                            title: LocaleKeys.settings_help_feedback_title.tr(),
                            page: SettingsPage.help,
                          ),
                        ),
                        _row(
                          context,
                          shown: shown,
                          title: LocaleKeys.settings_about_row_title.tr(),
                          page: SettingsPage.about,
                          value: 'v$appVersion',
                          isMonoValue: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
