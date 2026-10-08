import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/paywall/dev_paywall_variant_switch.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/presentation/developer_options_group.dart';
import 'package:critalarm/features/settings/presentation/developer_options_rules.dart';
import 'package:critalarm/features/settings/presentation/developer_setup_section.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Only reachable in builds made with --dart-define=SKIP_PAYWALL=true or
/// --dart-define=PAYWALL_LAB=true. Lets whoever is testing the build move
/// between the free and Pro states without a store purchase.
///
/// One list in a few sections ([developerSectionsFor]). A switch is a toggle
/// row, a choice from a list is one [AppPickerRow] that shows its value and
/// opens a sheet, and a page that only opens is an [AppValueRow] in the
/// last section.
///
/// The Force Pro switches read switches that DI only registers in a
/// SKIP_PAYWALL build, so a PAYWALL_LAB only build hides them.
class DeveloperSettingsScreen extends StatelessWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = developerSectionsFor(
      hasPlanSwitches: buildSkipsPaywall,
      hasSetupTools: developerSetupIsShown(),
    );
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.settings_developer_header.tr(),
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
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final section in sections)
                    switch (section) {
                      DeveloperSection.plans => const _PlansSection(),
                      DeveloperSection.paywalls => const _PaywallsSection(),
                      DeveloperSection.setup => const DeveloperSetupSection(),
                      DeveloperSection.tools => const _ToolsSection(),
                    },
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context) {
    return DeveloperOptionsGroup(
      title: LocaleKeys.developer_options_section_plans.tr(),
      rows: [
        ValueListenableBuilder<bool>(
          valueListenable: getIt<DevProSwitch>(),
          builder: (context, isPro, _) => AppToggleRow(
            title: LocaleKeys.settings_developer_pro_title.tr(),
            value: isPro,
            onChanged: (val) {
              unawaited(getIt<DevProSwitch>().setPro(isPro: val));
              // The widgets lock and unlock with Pro.
              getIt<WidgetSync>().rewrite();
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: getIt<ProPackDevSwitch>(),
          builder: (context, isHeld, _) => AppToggleRow(
            title: LocaleKeys.settings_developer_pro_pack_title.tr(),
            value: isHeld,
            onChanged: (val) => unawaited(
              getIt<ProPackDevSwitch>().setHeld(isHeld: val),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaywallsSection extends StatelessWidget {
  const _PaywallsSection();

  @override
  Widget build(BuildContext context) {
    return DeveloperOptionsGroup(
      title: LocaleKeys.developer_options_section_paywalls.tr(),
      rows: const [
        if (buildHasPaywallLab) _PaywallVariantRow(),
        _PaywallLayoutsRow(),
      ],
    );
  }
}

/// Pins the shipped paywall to one variant so a single build can show every
/// one.
///
/// Only drawn in a `--dart-define=PAYWALL_LAB=true` build. Null means Remote
/// Config decides, which is what every store build does.
class _PaywallVariantRow extends StatelessWidget {
  const _PaywallVariantRow();

  static String _label(PaywallVariant? variant) {
    switch (variant) {
      case null:
        return LocaleKeys.settings_developer_paywall_variant_auto.tr();
      case PaywallVariant.straight:
        return LocaleKeys.settings_developer_paywall_variant_straight.tr();
      case PaywallVariant.compare:
        return LocaleKeys.settings_developer_paywall_variant_compare.tr();
      case PaywallVariant.oneJob:
        return LocaleKeys.settings_developer_paywall_variant_one_job.tr();
      case PaywallVariant.hostedTemplate:
        return LocaleKeys.settings_developer_paywall_variant_hosted_template
            .tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final variantSwitch = getIt<DevPaywallVariantSwitch>();
    return ValueListenableBuilder<PaywallVariant?>(
      valueListenable: variantSwitch,
      builder: (context, selected, _) => AppPickerRow<PaywallVariant?>(
        title: LocaleKeys.developer_options_variant_title.tr(),
        sheetNote: LocaleKeys.settings_developer_paywall_variant_subtitle.tr(),
        selected: selected,
        options: [
          for (final choice in const <PaywallVariant?>[
            null,
            ...PaywallVariant.values,
          ])
            AppPickerOption(value: choice, label: _label(choice)),
        ],
        onPick: (choice) => unawaited(variantSwitch.setVariant(choice)),
      ),
    );
  }
}

/// The one way in to the paywall picker page, with what each product's
/// paywall opens now as its second line.
class _PaywallLayoutsRow extends StatelessWidget {
  const _PaywallLayoutsRow();

  static String _layoutLabel(PaywallLayoutSetting? setting) {
    if (setting == null) return LocaleKeys.developer_options_remote.tr();
    if (setting.isShipped) {
      return LocaleKeys.settings_developer_paywall_route_shipped.tr();
    }
    if (setting.isAuto) {
      return LocaleKeys.settings_developer_paywall_route_auto.tr();
    }
    final layout = setting.layout;
    return layout == null ? setting.storedKey : paywallLayoutName(layout);
  }

  @override
  Widget build(BuildContext context) {
    void open() =>
        unawaited(context.push('/settings/developer/paywall-layouts'));
    final title = LocaleKeys.paywall_kit_dev_row_title.tr();
    // A debug build with neither flag has the page and no switches.
    if (!getIt.isRegistered<DevPaywallLayoutSwitches>()) {
      return AppValueRow(title: title, onTap: open);
    }
    final switches = getIt<DevPaywallLayoutSwitches>();
    return ListenableBuilder(
      listenable: Listenable.merge([
        switches.hosted,
        switches.pro,
        switches.hostedIntro,
        switches.proIntro,
      ]),
      builder: (context, _) {
        final remote = LocaleKeys.developer_options_remote.tr();
        String pair(DevPaywallIntroSwitch intro, DevPaywallLayoutSwitch at) =>
            paywallPairText(
              intro: intro.value == null
                  ? null
                  : paywallIntroName(intro.value!),
              layout: at.value == null ? null : _layoutLabel(at.value),
              remote: remote,
            );
        return AppValueRow(
          title: title,
          detail: LocaleKeys.developer_options_layouts_value.tr(
            namedArgs: {
              'hosted_name': paywallProductName(PaywallProduct.hosted),
              'hosted': pair(switches.hostedIntro, switches.hosted),
              'pro_name': paywallProductName(PaywallProduct.pro),
              'pro': pair(switches.proIntro, switches.pro),
            },
          ),
          onTap: open,
        );
      },
    );
  }
}

/// Galleries, labs and debug views: rows that only open another page.
class _ToolsSection extends StatelessWidget {
  const _ToolsSection();

  @override
  Widget build(BuildContext context) {
    AppValueRow page(String title, String location) => AppValueRow(
      title: title,
      onTap: () => unawaited(context.push(location)),
    );
    return DeveloperOptionsGroup(
      title: LocaleKeys.developer_options_section_tools.tr(),
      rows: [
        page(
          LocaleKeys.settings_developer_dialog_sheet_title.tr(),
          '/settings/developer/dialog-sheet',
        ),
        page(
          LocaleKeys.settings_developer_faces_title.tr(),
          '/settings/developer/faces',
        ),
        page(
          LocaleKeys.settings_developer_ringing_faces_title.tr(),
          '/settings/developer/ringing-faces',
        ),
        page(
          LocaleKeys.settings_developer_welcome_title.tr(),
          '/onboarding/welcome?preview=true&v=1',
        ),
        page(
          LocaleKeys.local_reminders_lab_row_title.tr(),
          '/settings/developer/local-reminders',
        ),
        page(
          LocaleKeys.settings_developer_alarm_debug_title.tr(),
          '/settings/developer/alarm',
        ),
      ],
    );
  }
}
