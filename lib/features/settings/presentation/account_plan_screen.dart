import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:critalarm/features/settings/presentation/settings_pro_row.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Settings, Account and plan: the card on top of Settings opens it.
///
/// The plan and Pro first, then who is signed in and the join code, then
/// Sign out and Delete account at the bottom. A server of one's own has no
/// accounts, so it shows the plan and Pro alone.
class AccountPlanScreen extends StatelessWidget {
  const AccountPlanScreen({super.key, this.settingsCubit, this.accountCubit});

  /// The Settings screen's own cubits, when the page draws in its detail
  /// pane, so the card beside the page and the page read one state. A pushed
  /// page leaves them null and loads its own.
  final SettingsCubit? settingsCubit;
  final AccountCubit? accountCubit;

  @override
  Widget build(BuildContext context) {
    final settings = settingsCubit;
    final account = accountCubit;
    return MultiBlocProvider(
      providers: [
        if (settings != null)
          BlocProvider.value(value: settings)
        else
          BlocProvider(
            create: (_) {
              final cubit = getIt<SettingsCubit>();
              unawaited(cubit.load());
              return cubit;
            },
          ),
        if (account != null)
          BlocProvider.value(value: account)
        else
          BlocProvider(
            create: (_) {
              final cubit = getIt<AccountCubit>();
              unawaited(cubit.load());
              return cubit;
            },
          ),
      ],
      child: const _AccountPlanView(),
    );
  }
}

class _AccountPlanView extends StatelessWidget {
  const _AccountPlanView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.settings_account_plan_title.tr(),
            leading: settingsBackButton(context),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTitledCard(
                      title: LocaleKeys.settings_plan_header.tr(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                          child: _PlanCards(state: state),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const AccountView(),
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

/// The plan card and the Pro row, as they were on Settings.
class _PlanCards extends StatelessWidget {
  const _PlanCards({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOwnServerMode(state.serverMode))
          _selfHostedPlan(context)
        else
          _plan(context),
        // Pro is bought in the app, so every server mode gets the row. Not
        // drawn until the phone has been asked.
        if (state.proState case final pro?) ...[
          // The own-server plan card has a note under it, so the row sits a
          // little further down.
          SizedBox(height: isOwnServerMode(state.serverMode) ? 12 : 8),
          SettingsProRow(
            state: pro,
            onSee: () {
              AppHaptics.capture();
              unawaited(
                openProPaywall(context, ProPackSheetSource.settingsPlan),
              );
            },
          ),
        ],
      ],
    );
  }

  /// A phone on a server of its own has no plan, so this says so and offers
  /// nothing to buy. The second line is plain text, not a link.
  Widget _selfHostedPlan(BuildContext context) {
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

  Widget _plan(BuildContext context) {
    // A purchase the store confirmed counts as Cloud before the server has
    // registered it.
    final isHosted = state.holdsHosted;
    final canManage = settingsCanManageCloud();
    final access = state.access;
    final limit = access.caps?.criticalTopics;
    return SettingsPlanCard(
      title: isHosted
          ? LocaleKeys.settings_plan_pro.tr()
          : !access.isKnown
          ? LocaleKeys.account_plan_unavailable.tr()
          : LocaleKeys.settings_plan_free.tr(),
      usage: state.criticalUsage,
      // The bar is the free allowance. Cloud, a purchase still being
      // confirmed (held already) and an unknown plan have none to show.
      fraction: isHosted || !access.isKnown
          ? null
          : planUsageFraction(
              used: access.criticalCount(state.topics),
              limit: limit,
            ),
      actionLabel: !isHosted
          ? LocaleKeys.settings_card_plan_upgrade.tr()
          : canManage
          ? LocaleKeys.settings_plan_manage_button.tr()
          : null,
      onAction: !isHosted
          ? () => openCloudFromSettings(context)
          : canManage
          ? openCloudManagement
          : null,
    );
  }
}

/// Whether the Manage button can show for Cloud: the store's own
/// subscription page, through the RevenueCat customer centre. A build that
/// skips the paywall never configures RevenueCat, and the Mac has no
/// customer centre.
bool settingsCanManageCloud() =>
    !buildSkipsPaywall && getIt<PlatformCapabilities>().hasCustomerCenter;

/// Opens the Cloud paywall from the Settings plan, from the card on top of
/// Settings or from the plan card on Account and plan. One source for both,
/// as when the plan card sat on Settings.
void openCloudFromSettings(BuildContext context) {
  AppHaptics.capture();
  unawaited(context.push(hostedPaywallLocation(PaywallSource.settingsPlan)));
}

/// Opens the store's subscription page for Cloud.
void openCloudManagement() {
  AppHaptics.capture();
  unawaited(getIt<PaywallCubit>().presentCustomerCenter());
}
