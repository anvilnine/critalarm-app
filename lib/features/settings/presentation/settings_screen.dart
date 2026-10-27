import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/feature_guides/presentation/widgets/feature_guide_picker_sheet.dart';
import 'package:critalarm/features/feedback/presentation/help_section.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/appearance_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_screen.dart';
import 'package:critalarm/features/settings/presentation/priorities_screen.dart';
import 'package:critalarm/features/settings/presentation/privacy_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:critalarm/features/settings/presentation/settings_pro_row.dart';
import 'package:critalarm/features/settings/presentation/settings_readiness_card.dart';
import 'package:critalarm/features/settings/presentation/settings_row_values.dart';
import 'package:critalarm/features/settings/presentation/sound_picker_screen.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Settings tab: a dark card on top that answers "will it wake me?", then
/// a white sheet of rows.
///
/// Everything with more than one control behind it lives on its own screen
/// under /settings. What stays here is the readiness card, the rows that lead
/// to those screens, and the plan. There is no face scene: a list gets none.
///
/// Where the display has a detail pane (an expanded window, or book posture
/// on a foldable), the card and the rows are the list and a row's page draws
/// in the pane beside them, starting with the first row's. Nothing is pushed
/// and the URL stays /settings. Rows whose page belongs to another feature
/// still push it. In tabletop posture the card holds still in the top half
/// and the rows scroll in the bottom half.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.forceDisconnected = false,
  });

  final bool forceDisconnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SettingsCubit>();
        unawaited(cubit.load(forceDisconnected: forceDisconnected));
        return cubit;
      },
      child: const _SettingsScreenContent(),
    );
  }
}

/// The sheet's inner padding. A row keeps 14 points inside its own box, so
/// the row text, the plan card text and the section labels all start 20 points
/// in from the sheet's edge, as the text on the Topics and Topic sheets does.
const EdgeInsets _kSheetPadding = EdgeInsets.fromLTRB(6, 10, 6, 10);

/// The section label's padding: the row's own 14 points at each side.
const EdgeInsets _kLabelPadding = EdgeInsets.fromLTRB(14, 10, 14, 6);

class _SettingsScreenContent extends StatefulWidget {
  const _SettingsScreenContent();

  @override
  State<_SettingsScreenContent> createState() => _SettingsScreenContentState();
}

class _SettingsScreenContentState extends State<_SettingsScreenContent> {
  /// The row whose page the detail pane shows. Null until a row is tapped,
  /// and then the pane opens on the first row's page.
  SettingsPage? _selected;

  /// The page the pane shows right now, worked out in [build].
  SettingsPage? _shown;

  /// The page of [page] as it draws in the detail pane.
  Widget _panePage(SettingsPage page) => switch (page) {
    SettingsPage.sound => const SoundPickerScreen(),
    SettingsPage.priorities => const PrioritiesScreen(),
    SettingsPage.storage => const AlarmSettingsScreen(),
    SettingsPage.server => const ServerSettingsScreen(),
    SettingsPage.personalize => const PersonalizeScreen(),
    SettingsPage.appearance => const AppearanceSettingsScreen(),
    SettingsPage.privacy => const PrivacySettingsScreen(),
    SettingsPage.about => const AboutScreen(),
    // Never selected: these push. See SettingsPage.opensInPane.
    SettingsPage.account ||
    SettingsPage.language ||
    SettingsPage.localReminders ||
    SettingsPage.developer => const SizedBox.shrink(),
  };

  void _open(BuildContext context, SettingsPage page) {
    final tap = settingsRowTapFor(
      showsDetail: AppScreenScaffold.showsDetail(context),
      page: page,
    );
    switch (tap) {
      case SettingsRowTap.select:
        if (page != _shown) AppHaptics.selection();
        setState(() => _selected = page);
      case SettingsRowTap.push:
        unawaited(context.push(page.path));
    }
  }

  /// One row that leads to a screen under /settings. [value] is what the row
  /// is set to, when that is already known, and sits before the arrow.
  Widget _buildNavRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required SettingsPage page,
    String? value,
  }) {
    final colors = context.appColors;
    final valueStyle = AppTypography.small(colors.ink3, fontSize: 13);
    // At larger text the value moves under the title, where the whole row
    // width is free for it. Before that it sits at the end of the row and
    // takes the room it needs, ahead of the description.
    final valueUnderTitle =
        MediaQuery.textScalerOf(context).scale(1) > kSettingsValueMaxTextScale;
    return AppListRow(
      name: title,
      preview: valueUnderTitle ? value : null,
      meta: subtitle,
      // No face. A face reports how something is doing, and these rows only
      // open another screen. The readiness card above keeps one because it
      // does report something.
      faceState: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && !valueUnderTitle) ...[
            // The value is chrome: it stops growing with the text size so it
            // never squeezes the row's title out.
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: kChromeMaxTextScale),
              ),
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
        ],
      ),
      isSelected: page == _shown,
      onTap: () => _open(context, page),
    );
  }

  /// A phone on a server of its own has no plan, so this says so and offers
  /// nothing to buy. The second line is plain text, not a link.
  Widget _buildSelfHostedPlanRow(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsPlanCard(
          title: LocaleKeys.settings_plan_selfhosted_title.tr(),
          usage: LocaleKeys.settings_plan_selfhosted_subtitle.tr(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(
            LocaleKeys.settings_plan_selfhosted_cloud_note.tr(),
            style: AppTypography.small(colors.ink3, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRow(BuildContext context, SettingsState state) {
    if (isOwnServerMode(state.serverMode)) {
      return _buildSelfHostedPlanRow(context);
    }
    // A purchase the store confirmed counts as Hosted before the server has
    // registered it.
    final isHosted = state.holdsHosted;
    final access = state.access;
    final limit = access.caps?.criticalTopics;
    return SettingsPlanCard(
      title: isHosted
          ? LocaleKeys.settings_plan_pro.tr()
          : !access.isKnown
          ? LocaleKeys.account_plan_unavailable.tr()
          : LocaleKeys.settings_plan_free.tr(),
      usage: state.criticalUsage,
      // The bar is the free allowance. Hosted, a purchase still being
      // confirmed (held already) and an unknown plan have none to show.
      fraction: isHosted || !access.isKnown
          ? null
          : planUsageFraction(
              used: access.criticalCount(state.topics),
              limit: limit,
            ),
      actionLabel: !isHosted
          ? LocaleKeys.settings_card_plan_upgrade.tr()
          : !buildSkipsPaywall
          // The store's own subscription page, through the RevenueCat
          // customer centre. A build that skips the paywall never
          // configures RevenueCat, and has no subscription to manage.
          ? LocaleKeys.settings_plan_manage_button.tr()
          : null,
      onAction: !isHosted
          ? () {
              AppHaptics.capture();
              unawaited(
                context.push(
                  hostedPaywallLocation(PaywallSource.settingsPlan),
                ),
              );
            }
          : !buildSkipsPaywall
          ? () {
              AppHaptics.capture();
              unawaited(getIt<PaywallCubit>().presentCustomerCenter());
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final colors = context.appColors;
        final capabilities = getIt<PlatformCapabilities>();
        final showsDetail = AppScreenScaffold.showsDetail(context);
        // Tabletop: the card holds still in the top half, over the fold,
        // and the rows scroll in the bottom half.
        final cardOnStage = AppFold.of(context).isTabletop;
        final shown = settingsPaneSelection(
          selected: _selected,
          shown: settingsPagesShown(
            canRunAlarm: capabilities.canRunAlarm,
            hasAccounts: state.hasAccounts,
            hasLocalNotifications: capabilities.hasLocalNotifications,
            showsDeveloper: buildSkipsPaywall || buildHasPaywallLab,
          ),
        );
        _shown = showsDetail ? shown : null;

        // The dark card. It reads the same checks as the Topics card and
        // opens the screen that lists them.
        const card = FeatureGuideAnchor(
          id: FeatureGuideAnchorId.settingsHealth,
          child: SettingsReadinessCard(),
        );

        return AppScreenScaffold(
          topBar: AppTopBar(title: LocaleKeys.settings_title.tr()),
          detail: showsDetail && shown != null
              ? SettingsPaneScope(
                  key: ValueKey(shown),
                  child: _panePage(shown),
                )
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
                      child: card,
                    ),
                  ),
                )
              : null,
          // The sheet is text on white and scrolls under the title, so the
          // backing holds full strength behind the whole title row.
          slivers: [
            if (!cardOnStage)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: card,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: AppSheet(
                  padding: _kSheetPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_alarm_sound_row_title.tr(),
                        subtitle: LocaleKeys.settings_alarm_sound_row_subtitle
                            .tr(),
                        page: SettingsPage.sound,
                      ),
                      // A browser has no push and no alarm to describe.
                      if (capabilities.canRunAlarm) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_priorities_row_title.tr(),
                          subtitle: LocaleKeys.settings_priorities_row_subtitle
                              .tr(),
                          page: SettingsPage.priorities,
                        ),
                      ],
                      // Storage is the only thing left of the old Alarms
                      // page. It only touches this phone's own copy, so it
                      // is there on every plan.
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_storage_row_title.tr(),
                        subtitle: LocaleKeys.settings_storage_row_subtitle.tr(),
                        page: SettingsPage.storage,
                        value: settingsStorageValueKey(
                          state.storage.retention,
                        ).tr(),
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_server_row_title.tr(),
                        subtitle: LocaleKeys.settings_server_row_subtitle.tr(),
                        page: SettingsPage.server,
                        value: settingsServerValueKey(
                          status: state.status,
                          isConnected: state.isConnected,
                          mode: state.serverMode,
                        )?.tr(),
                      ),
                      if (state.hasAccounts) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.account_row_title.tr(),
                          subtitle: LocaleKeys.account_row_subtitle.tr(),
                          page: SettingsPage.account,
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_app_header.tr(),
                        padding: _kLabelPadding,
                      ),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.personalize_title.tr(),
                        subtitle: LocaleKeys.personalize_row_subtitle.tr(),
                        page: SettingsPage.personalize,
                      ),
                      const SizedBox(height: 8),
                      BlocBuilder<ThemeCubit, AppThemeMode>(
                        bloc: getIt<ThemeCubit>(),
                        builder: (context, mode) => _buildNavRow(
                          context,
                          title: LocaleKeys.settings_appearance_row_title.tr(),
                          subtitle: LocaleKeys.settings_appearance_row_subtitle
                              .tr(),
                          page: SettingsPage.appearance,
                          value: settingsThemeValueKey(mode).tr(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      BlocBuilder<LanguageCubit, LanguageState>(
                        bloc: getIt<LanguageCubit>(),
                        builder: (context, state) => _buildNavRow(
                          context,
                          title: LocaleKeys.language_title.tr(),
                          // The value says what it is set to, and a line
                          // under "Language" would only repeat the title.
                          subtitle: '',
                          page: SettingsPage.language,
                          value: state.selectedTag == null
                              ? LocaleKeys.language_system_default.tr()
                              : languageNativeNames[state.selectedTag] ?? '',
                        ),
                      ),
                      // Web has no local notifications, so no reminders.
                      if (capabilities.hasLocalNotifications) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.local_reminders_settings_row_title
                              .tr(),
                          subtitle: LocaleKeys
                              .local_reminders_settings_row_subtitle
                              .tr(),
                          page: SettingsPage.localReminders,
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_plan_header.tr(),
                        padding: _kLabelPadding,
                      ),
                      _buildPlanRow(context, state),
                      // Pro is bought in the app, so every server mode gets
                      // the row. Not drawn until the phone has been asked.
                      if (state.proState case final pro?) ...[
                        // The own-server plan card has a note under it, so
                        // the row sits a little further down.
                        SizedBox(
                          height: isOwnServerMode(state.serverMode) ? 12 : 8,
                        ),
                        SettingsProRow(
                          state: pro,
                          onSee: () {
                            AppHaptics.capture();
                            unawaited(
                              openProPaywall(
                                context,
                                ProPackSheetSource.settingsPlan,
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.settings_setup_header.tr(),
                        padding: _kLabelPadding,
                      ),
                      FeatureGuideAnchor(
                        id: FeatureGuideAnchorId.settingsFeatureGuides,
                        child: AppListRow(
                          name: LocaleKeys.settings_feature_guides_row_title
                              .tr(),
                          meta: LocaleKeys.settings_feature_guides_row_subtitle
                              .tr(),
                          faceState: null,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          onTap: () =>
                              unawaited(showFeatureGuidePickerSheet(context)),
                        ),
                      ),
                      // Debug and developer-flag builds only (the same flags
                      // that show Developer options). A store user gets the
                      // Feature Guides above.
                      if (kDebugMode ||
                          buildSkipsPaywall ||
                          buildHasPaywallLab) ...[
                        const SizedBox(height: 8),
                        AppListRow(
                          name: LocaleKeys.settings_redo_onboarding_title.tr(),
                          meta: LocaleKeys.settings_redo_onboarding_subtitle
                              .tr(),
                          faceState: null,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          // From Settings this is a look at the screens, not
                          // a real run, so no step is skipped for being
                          // granted.
                          onTap: () => context.pushNamed(
                            AppRoute.onboardingWelcome,
                            queryParameters: const {'demo': 'true'},
                          ),
                        ),
                      ],
                      if (buildSkipsPaywall || buildHasPaywallLab) ...[
                        const SizedBox(height: 8),
                        _buildNavRow(
                          context,
                          title: LocaleKeys.settings_developer_row_title.tr(),
                          subtitle: LocaleKeys.settings_developer_row_subtitle
                              .tr(),
                          page: SettingsPage.developer,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const HelpSection(headerPadding: _kLabelPadding),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_privacy_row_title.tr(),
                        subtitle: LocaleKeys.settings_privacy_row_subtitle.tr(),
                        page: SettingsPage.privacy,
                      ),
                      const SizedBox(height: 8),
                      _buildNavRow(
                        context,
                        title: LocaleKeys.settings_about_row_title.tr(),
                        subtitle: LocaleKeys.settings_about_row_subtitle.tr(),
                        page: SettingsPage.about,
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
