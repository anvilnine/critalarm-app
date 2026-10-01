import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Settings › How to use the app. The full tour sits on top as the main
/// action, with one row per screen below it. Starts the one tapped once the
/// sheet is gone.
Future<void> showTourPickerSheet(BuildContext context) async {
  final tour = getIt<TourCubit>();
  final picked = await showAppSheet<_Pick>(
    context: context,
    title: LocaleKeys.tour_picker_title.tr(),
    subtitle: LocaleKeys.tour_picker_subtitle.tr(),
    content: (sheetContext) => _TourPicker(
      hasSeen: tour.hasSeen,
      onPick: (guide) => Navigator.of(sheetContext).pop(_Pick(guide)),
    ),
  );
  // The future resolves after the sheet is popped, so the tour never starts
  // navigating underneath it.
  if (picked != null) tour.requestGuide(picked.guide);
}

/// Wraps the choice so "full tour" (a null guide) is not confused with a
/// dismissed sheet, which resolves to null.
class _Pick {
  const _Pick(this.guide);

  final TourGuide? guide;
}

/// The sheet's body: the full tour button, then a row per guide. Scrolls when
/// the guides do not fit, so a small phone or a large text size still reaches
/// the last row.
class _TourPicker extends StatelessWidget {
  const _TourPicker({required this.hasSeen, required this.onPick});

  final bool Function(TourGuide guide) hasSeen;
  final ValueChanged<TourGuide?> onPick;

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
              label: tourFullLabel(),
              isFullWidth: true,
              icon: AppGlyph(
                GlyphType.play,
                color: context.appColors.onPrimary,
              ),
              onPressed: () => onPick(null),
            ),
            AppSectionHeader(
              LocaleKeys.tour_picker_section.tr(),
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            ),
            for (final guide in TourGuide.values) ...[
              if (guide != TourGuide.values.first) const SizedBox(height: 8),
              AppListRow(
                name: tourGuideLabelKey(guide).tr(),
                preview: tourGuideDescriptionKey(guide).tr(),
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

  String _meta(TourGuide guide) {
    final steps = LocaleKeys.tour_picker_steps.plural(
      tourStepsFor(guide).length,
    );
    return hasSeen(guide)
        ? '$steps · ${LocaleKeys.tour_picker_seen.tr()}'
        : steps;
  }
}

/// The full tour button's label: its name and how many steps it plays.
String tourFullLabel() =>
    '${LocaleKeys.tour_picker_full.tr()} · '
    '${LocaleKeys.tour_picker_steps.plural(tourSteps.length)}';

/// The translation key for a guide's name in the picker. Exhaustive, so a new
/// [TourGuide] does not compile until it has a label.
String tourGuideLabelKey(TourGuide guide) => switch (guide) {
  TourGuide.home => LocaleKeys.tour_guide_home,
  TourGuide.search => LocaleKeys.tour_guide_search,
  TourGuide.createTopic => LocaleKeys.tour_guide_create_topic,
  TourGuide.topic => LocaleKeys.tour_guide_topic,
  TourGuide.history => LocaleKeys.tour_guide_history,
  TourGuide.settings => LocaleKeys.tour_guide_settings,
};

/// The translation key for the one line saying what a guide covers.
/// Exhaustive for the same reason as [tourGuideLabelKey].
String tourGuideDescriptionKey(TourGuide guide) => switch (guide) {
  TourGuide.home => LocaleKeys.tour_guide_home_sub,
  TourGuide.search => LocaleKeys.tour_guide_search_sub,
  TourGuide.createTopic => LocaleKeys.tour_guide_create_topic_sub,
  TourGuide.topic => LocaleKeys.tour_guide_topic_sub,
  TourGuide.history => LocaleKeys.tour_guide_history_sub,
  TourGuide.settings => LocaleKeys.tour_guide_settings_sub,
};
