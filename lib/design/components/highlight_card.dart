import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// What an [AppHighlightCard] is saying about the thing inside it.
enum AppHighlightTone {
  /// The one choice on the screen that matters. The critical canvas with its
  /// stroke.
  crit,

  /// Settled: a step that is done. The cobalt tint with a cobalt stroke, the
  /// same "good, done" pair a feature bullet uses.
  calm,
}

/// Width of the stroke around an [AppHighlightCard].
const double highlightCardStrokeWidth = 2;

/// The fill and stroke [tone] takes from [colors]. Both come straight from
/// the palette, so a theme or severity change carries through.
({Color fill, Color stroke}) highlightToneColors(
  AppHighlightTone tone,
  AppColors colors,
) => switch (tone) {
  AppHighlightTone.crit => (
    fill: colors.critCanvas,
    stroke: colors.critStroke,
  ),
  AppHighlightTone.calm => (fill: colors.cobaltTint, stroke: colors.cobalt),
};

/// A tinted, stroked surface that marks one thing on a screen as the
/// important one.
///
/// It draws the surface and nothing else: no title, switch or button of its
/// own. Put a toggle row, a checklist row or a column inside as [child].
/// Use one per screen, or one per row in a short checklist; a screen full of
/// them highlights nothing.
///
/// Text on it takes `onCanvas`. On the light crit tone `onCanvasMuted` is
/// under 4.5:1, so keep muted text there to a short supporting line.
class AppHighlightCard extends StatelessWidget {
  const AppHighlightCard({
    required this.child,
    this.tone = AppHighlightTone.crit,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final AppHighlightTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (:fill, :stroke) = highlightToneColors(tone, context.appColors);

    // Animated so a row that turns from crit to calm retints instead of
    // cutting. A card whose tone never changes never animates.
    return AnimatedContainer(
      duration: context.motion(AppDurations.base),
      curve: AppCurves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: Radii.lgAll,
        border: Border.all(color: stroke, width: highlightCardStrokeWidth),
      ),
      child: child,
    );
  }
}
