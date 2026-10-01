import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Settings › Feature Guides. Playing all of them sits on top as the main
/// action, with one row per screen below it. Starts the one tapped once the
/// sheet is gone.
Future<void> showFeatureGuidePickerSheet(BuildContext context) async {
  final guides = getIt<FeatureGuideCubit>();
  final picked = await showAppSheet<_Pick>(
    context: context,
    title: LocaleKeys.feature_guides_picker_title.tr(),
    subtitle: LocaleKeys.feature_guides_picker_subtitle.tr(),
    content: (sheetContext) => _FeatureGuidePicker(
      hasSeen: guides.hasSeen,
      onPick: (guide) => Navigator.of(sheetContext).pop(_Pick(guide)),
    ),
  );
  // The future resolves after the sheet is popped, so a guide never starts
  // navigating underneath it.
  if (picked != null) guides.requestGuide(picked.guide);
}

/// Wraps the choice so "all guides" (a null guide) is not confused with a
/// dismissed sheet, which resolves to null.
class _Pick {
  const _Pick(this.guide);

  final FeatureGuide? guide;
}

/// The sheet's body: the all-guides button, then a row per guide. Scrolls when
/// the guides do not fit, so a small phone or a large text size still reaches
/// the last row.
class _FeatureGuidePicker extends StatelessWidget {
  const _FeatureGuidePicker({required this.hasSeen, required this.onPick});

  final bool Function(FeatureGuide guide) hasSeen;
  final ValueChanged<FeatureGuide?> onPick;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: featureGuideFullLabel(),
              isFullWidth: true,
              icon: AppGlyph(
                GlyphType.play,
                color: context.appColors.onPrimary,
              ),
              onPressed: () => onPick(null),
            ),
            AppSectionHeader(
              LocaleKeys.feature_guides_picker_section.tr(),
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            ),
            for (final guide in FeatureGuide.values) ...[
              if (guide != FeatureGuide.values.first) const SizedBox(height: 8),
              AppListRow(
                name: featureGuideLabelKey(guide).tr(),
                preview: featureGuideDescriptionKey(guide).tr(),
                meta: _meta(guide),
                faceState: null,
                trailing: AppGlyph(
                  GlyphType.arrow,
                  color: context.appColors.ink3,
                  size: 16,
                ),
                onTap: () => onPick(guide),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _meta(FeatureGuide guide) {
    final steps = LocaleKeys.feature_guides_picker_steps.plural(
      featureGuideStepsFor(guide).length,
    );
    return hasSeen(guide)
        ? '$steps · ${LocaleKeys.feature_guides_picker_seen.tr()}'
        : steps;
  }
}

/// The all-guides button's label: its name and how many steps it plays.
String featureGuideFullLabel() =>
    '${LocaleKeys.feature_guides_picker_full.tr()} · '
    '${LocaleKeys.feature_guides_picker_steps.plural(
      featureGuideSteps.length,
    )}';

/// The translation key for a guide's name in the picker. Exhaustive, so a new
/// [FeatureGuide] does not compile until it has a label.
String featureGuideLabelKey(FeatureGuide guide) => switch (guide) {
  FeatureGuide.home => LocaleKeys.feature_guides_guide_home,
  FeatureGuide.search => LocaleKeys.feature_guides_guide_search,
  FeatureGuide.createTopic => LocaleKeys.feature_guides_guide_create_topic,
  FeatureGuide.topic => LocaleKeys.feature_guides_guide_topic,
  FeatureGuide.history => LocaleKeys.feature_guides_guide_history,
  FeatureGuide.settings => LocaleKeys.feature_guides_guide_settings,
};

/// The translation key for the one line saying what a guide covers.
/// Exhaustive for the same reason as [featureGuideLabelKey].
String featureGuideDescriptionKey(FeatureGuide guide) => switch (guide) {
  FeatureGuide.home => LocaleKeys.feature_guides_guide_home_sub,
  FeatureGuide.search => LocaleKeys.feature_guides_guide_search_sub,
  FeatureGuide.createTopic => LocaleKeys.feature_guides_guide_create_topic_sub,
  FeatureGuide.topic => LocaleKeys.feature_guides_guide_topic_sub,
  FeatureGuide.history => LocaleKeys.feature_guides_guide_history_sub,
  FeatureGuide.settings => LocaleKeys.feature_guides_guide_settings_sub,
};
