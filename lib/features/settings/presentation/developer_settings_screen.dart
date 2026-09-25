import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/paywall/dev_paywall_variant_switch.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Only reachable in builds made with --dart-define=SKIP_PAYWALL=true. Lets
/// whoever is testing the build move between the free and Pro states without
/// a store purchase.
class DeveloperSettingsScreen extends StatelessWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proSwitch = getIt<DevProSwitch>();

    return AppScreenScaffold(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: proSwitch,
                    builder: (context, isPro, _) => AppToggleRow(
                      title: LocaleKeys.settings_developer_pro_title.tr(),
                      subtitle: LocaleKeys.settings_developer_pro_subtitle.tr(),
                      value: isPro,
                      onChanged: (val) {
                        unawaited(proSwitch.setPro(isPro: val));
                        // The widgets lock and unlock with Pro.
                        getIt<WidgetSync>().rewrite();
                      },
                    ),
                  ),
                  if (buildHasPaywallLab) ...[
                    const SizedBox(height: 14),
                    const _PaywallVariantPicker(),
                  ],
                  const SizedBox(height: 14),
                  AppListRow(
                    name: LocaleKeys.settings_developer_dialog_sheet_title.tr(),
                    meta: LocaleKeys.settings_developer_dialog_sheet_subtitle
                        .tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () =>
                        context.push('/settings/developer/dialog-sheet'),
                  ),
                  const SizedBox(height: 8),
                  AppListRow(
                    name: LocaleKeys.settings_developer_faces_title.tr(),
                    meta: LocaleKeys.settings_developer_faces_subtitle.tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () => context.push('/settings/developer/faces'),
                  ),
                  const SizedBox(height: 8),
                  AppListRow(
                    name: LocaleKeys.settings_developer_ringing_faces_title
                        .tr(),
                    meta: LocaleKeys.settings_developer_ringing_faces_subtitle
                        .tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () =>
                        context.push('/settings/developer/ringing-faces'),
                  ),
                  const SizedBox(height: 8),
                  AppListRow(
                    name: LocaleKeys.settings_developer_welcome_title.tr(),
                    meta: LocaleKeys.settings_developer_welcome_subtitle.tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () =>
                        context.push('/onboarding/welcome?preview=true&v=1'),
                  ),
                  const SizedBox(height: 8),
                  AppListRow(
                    name: LocaleKeys.reminders_lab_row_title.tr(),
                    meta: LocaleKeys.reminders_lab_row_subtitle.tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () => context.push('/settings/developer/reminders'),
                  ),
                  const SizedBox(height: 8),
                  AppListRow(
                    name: LocaleKeys.settings_developer_alarm_debug_title.tr(),
                    meta: LocaleKeys.settings_developer_alarm_debug_subtitle
                        .tr(),
                    faceState: null,
                    trailing: AppGlyph(
                      GlyphType.arrow,
                      color: context.appColors.ink3,
                      size: 16,
                    ),
                    onTap: () => context.push('/settings/developer/alarm'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pins the paywall to one layout so a single build can show every variant.
///
/// Only drawn in a `--dart-define=PAYWALL_LAB=true` build. Null means Remote
/// Config decides, which is what every store build does.
class _PaywallVariantPicker extends StatelessWidget {
  const _PaywallVariantPicker();

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
    final colors = context.appColors;
    final variantSwitch = getIt<DevPaywallVariantSwitch>();
    const choices = <PaywallVariant?>[null, ...PaywallVariant.values];

    return ValueListenableBuilder<PaywallVariant?>(
      valueListenable: variantSwitch,
      builder: (context, selected, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.settings_developer_paywall_variant_title.tr(),
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            LocaleKeys.settings_developer_paywall_variant_subtitle.tr(),
            style: TextStyle(color: colors.ink3, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final choice in choices) ...[
            AppListRow(
              name: _label(choice),
              meta: '',
              faceState: null,
              trailing: choice == selected
                  ? AppGlyph(GlyphType.check, color: colors.highlight, size: 16)
                  : null,
              onTap: () => unawaited(variantSwitch.setVariant(choice)),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
