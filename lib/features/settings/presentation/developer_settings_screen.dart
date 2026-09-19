import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
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
                      onChanged: (val) =>
                          unawaited(proSwitch.setPro(isPro: val)),
                    ),
                  ),
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
