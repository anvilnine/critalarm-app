import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/settings/presentation/account_plan_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/settings_hero_view.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The card on top of Settings: what you pay for and how you are signed in.
///
/// A tap on the card opens Account and plan. The buttons under it open the
/// same paywalls the plan card and the Pro row open, from the same source, so
/// nothing about what was counted changes. Pro owned shows as the Pro badge,
/// which is a word and never a button.
class SettingsAccountHero extends StatelessWidget {
  const SettingsAccountHero({
    required this.state,
    required this.onOpen,
    this.isSelected = false,
    super.key,
  });

  final SettingsState state;

  /// The card itself was tapped.
  final VoidCallback onOpen;

  /// The card's page shows in the detail pane beside the list.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, account) {
        final identity = account.identity;
        final view = SettingsHeroView.from(
          serverMode: state.serverMode,
          loaded: state.status == SettingsStatus.success,
          holdsHosted: state.holdsHosted,
          planKnown: state.access.isKnown,
          proState: state.proState,
          signedIn: identity != null,
          canManage: settingsCanManageCloud(),
        );
        final plan = view.planKey?.tr() ?? '';
        final line = switch (view.line) {
          SettingsHeroLine.signedIn =>
            '${LocaleKeys.account_provider_label.tr()} '
                '${identity!.providers.map(providerName).join(', ')}',
          SettingsHeroLine.signedOut =>
            LocaleKeys.settings_hero_signed_out.tr(),
          SettingsHeroLine.ownServer =>
            LocaleKeys.settings_plan_selfhosted_subtitle.tr(),
          SettingsHeroLine.none => '',
        };

        final card = Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const _Avatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          plan,
                          style: AppTypography.headline(
                            colors.ink,
                            fontSize: 24,
                          ),
                        ),
                        if (view.ownsPro)
                          ProBadge(label: LocaleKeys.settings_pro_title.tr()),
                      ],
                    ),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small(colors.ink3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
            ],
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.lg,
            border: isSelected
                ? Border.all(color: colors.highlight, width: 2.5)
                : null,
          ),
          child: ClipRRect(
            borderRadius: Radii.xlAll,
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    selected: isSelected,
                    label: [
                      LocaleKeys.settings_account_plan_title.tr(),
                      if (plan.isNotEmpty) plan,
                      if (view.ownsPro)
                        LocaleKeys.settings_pro_owned_label.tr(),
                      if (line.isNotEmpty) line,
                    ].join(', '),
                    excludeSemantics: true,
                    child: InkWell(onTap: onOpen, child: card),
                  ),
                  if (view.actions.isNotEmpty)
                    Padding(
                      // The buttons are 36 pills in 48 tap boxes, so 6 less
                      // above them than the 18 the card keeps.
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          // Each button as wide as its label, side by side
                          // while they fit.
                          for (final action in view.actions)
                            IntrinsicWidth(
                              child: _actionButton(context, action),
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
    );
  }

  Widget _actionButton(BuildContext context, SettingsHeroAction action) =>
      switch (action) {
        SettingsHeroAction.seeCloud => AppButton(
          label: LocaleKeys.settings_card_plan_upgrade.tr(),
          size: AppButtonSize.sm,
          onPressed: () => openCloudFromSettings(context),
        ),
        SettingsHeroAction.manage => AppButton(
          label: LocaleKeys.settings_plan_manage_button.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          onPressed: openCloudManagement,
        ),
        SettingsHeroAction.seePro => AppButton(
          label: LocaleKeys.settings_pro_button.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          onPressed: () {
            AppHaptics.capture();
            unawaited(openProPaywall(context, ProPackSheetSource.settingsPlan));
          },
        ),
      };
}

/// A square in the panel colour with a person drawn in the Crit yellow.
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: Radii.mdAll,
          // Keeps the tile apart from the card in dark mode, where the panel
          // and the card are close in tone.
          border: Border.all(color: colors.hairline),
        ),
        child: AppGlyph(
          GlyphType.person,
          size: 28,
          strokeWidth: 2.2,
          color: colors.yellow,
        ),
      ),
    );
  }
}
