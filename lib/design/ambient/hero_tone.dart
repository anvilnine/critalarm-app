import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// How the disc behind the hero's face is tinted.
///
/// The severity canvases retint the disc by themselves: [calm] is the
/// canvas's lighter step, so under a high, critical or acknowledged canvas it
/// is already orange, red or cobalt. The other three are for a yellow canvas
/// that needs the disc to say something the canvas does not.
enum AppHeroTone {
  /// The lighter step of the canvas. The default for a card that is fine,
  /// and the one tone to use under a severity canvas.
  calm,

  /// A faint ink wash that takes the colour out of the scene: quiet and
  /// stale.
  quiet,

  /// Orange at half strength: a check needs a look.
  look,

  /// Red at a third of its strength: nothing can reach the phone, or an
  /// alarm was missed.
  danger;

  /// The disc fill on [colors], strength included.
  Color discColor(AppColors colors) {
    final (color, opacity) = discTint(colors);
    return color.withValues(alpha: opacity);
  }

  /// The disc as a colour and how strongly it is drawn, apart. An ambient
  /// shape keeps the two apart, and lerps each of them.
  (Color, double) discTint(AppColors colors) => switch (this) {
    AppHeroTone.calm => (colors.canvasAlt, 1.0),
    AppHeroTone.quiet => (colors.onCanvas, 0.06),
    AppHeroTone.look => (colors.high, 0.55),
    AppHeroTone.danger => (colors.crit, 0.3),
  };
}
