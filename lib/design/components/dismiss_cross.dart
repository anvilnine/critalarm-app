import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:flutter/material.dart';

/// The house close control: a bare cross with no circle behind it and a 48
/// point hit area, so a thumb finds it without the cross looking heavy.
///
/// The box is [tapSize] across and the cross sits in its middle, so a bar
/// that holds one takes the room the box adds out of its own padding. The
/// paywall layouts place the cross by the old 44 box and pass nothing, so
/// [tapSize] stays 44 there. Everything else passes 48.
///
/// Every card and bar on Home that can be put away uses this one. [label] is
/// what a screen reader says. The caller passes the words that name what is
/// being closed.
class AppDismissCross extends StatelessWidget {
  const AppDismissCross({
    required this.onPressed,
    required this.label,
    this.color,
    this.tapSize = hitSize,
    super.key,
  });

  /// Edge of the square that takes a tap, unless [tapSize] says otherwise.
  static const double hitSize = 44;

  /// The room [tapSize] adds on each side of the cross's own 44 box.
  static double tapRoom(double tapSize) => (tapSize - hitSize) / 2;

  final VoidCallback onPressed;
  final String label;

  /// The cross colour. Defaults to the quiet ink, which reads on a white or
  /// cream surface.
  final Color? color;

  /// Edge of the square that takes a tap. 44 keeps the box the paywall
  /// layouts were placed by; 48 is what every other screen uses.
  final double tapSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.fullAll,
        child: SizedBox(
          width: tapSize,
          height: tapSize,
          child: Center(
            child: AppGlyph(
              GlyphType.close,
              color: color ?? colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
