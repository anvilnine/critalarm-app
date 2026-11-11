import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feature_guides/presentation/widgets/feature_guide_picker_sheet.dart';
import 'package:critalarm/features/feedback/presentation/help_section.dart';
import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Ways to learn the app and to reach us: Feature Guides first, then the
/// docs, the two forms, a problem report and the store listing.
class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.settings_help_feedback_title.tr(),
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
                HelpSection(
                  title: LocaleKeys.settings_help_header.tr(),
                  leading: [
                    AppCardRow(
                      title: LocaleKeys.settings_feature_guides_row_title.tr(),
                      detail: LocaleKeys.settings_feature_guides_row_subtitle
                          .tr(),
                      onTap: () =>
                          unawaited(showFeatureGuidePickerSheet(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
