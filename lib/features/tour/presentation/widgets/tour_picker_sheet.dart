import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Settings › How to use the app. Lists the full tour and every single guide,
/// and starts the one tapped once the sheet is gone.
Future<void> showTourPickerSheet(BuildContext context) async {
  final picked = await showAppSheet<_Pick>(
    context: context,
    title: LocaleKeys.tour_picker_title.tr(),
    options: [
      AppSheetOption<_Pick>(
        label: LocaleKeys.tour_picker_full.tr(),
        glyph: GlyphType.play,
        value: const _Pick(null),
      ),
      for (final guide in TourGuide.values)
        AppSheetOption<_Pick>(
          label: tourGuideLabelKey(guide).tr(),
          glyph: _glyphFor(guide),
          meta: LocaleKeys.tour_picker_steps.plural(
            tourStepsFor(guide).length,
          ),
          value: _Pick(guide),
        ),
    ],
  );
  // The future resolves after the sheet is popped, so the tour never starts
  // navigating underneath it.
  if (picked != null) getIt<TourCubit>().requestGuide(picked.guide);
}

/// Wraps the choice so "full tour" (a null guide) is not confused with a
/// dismissed sheet, which resolves to null.
class _Pick {
  const _Pick(this.guide);

  final TourGuide? guide;
}

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

/// The icon beside a guide's row, so the list reads as places in the app.
GlyphType _glyphFor(TourGuide guide) => switch (guide) {
  TourGuide.home => GlyphType.list,
  TourGuide.search => GlyphType.search,
  TourGuide.createTopic => GlyphType.plus,
  TourGuide.topic => GlyphType.bell,
  TourGuide.history => GlyphType.clock,
  TourGuide.settings => GlyphType.gear,
};
