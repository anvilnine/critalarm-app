import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:flutter/material.dart';

/// The house close control: a bare cross with no circle behind it and a 44
/// point hit area, so a thumb finds it without the cross looking heavy.
///
/// Every card and bar on Home that can be put away uses this one. [label] is
/// what a screen reader says. The caller passes the words that name what is
/// being closed.
class AppDismissCross extends StatelessWidget {
  const AppDismissCross({
    required this.onPressed,
    required this.label,
    this.color,
    super.key,
  });

  /// Edge of the square that takes a tap.
  static const double hitSize = 44;

  final VoidCallback onPressed;
  final String label;

  /// The cross colour. Defaults to the quiet ink, which reads on a white or
  /// cream surface.
  final Color? color;

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
          width: hitSize,
          height: hitSize,
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
