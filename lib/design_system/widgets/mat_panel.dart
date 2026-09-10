import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

/// The card primitive: a solid panel with a seam border and
/// an optional colored rail down the left edge (safety orange for the hero,
/// tape colors for status rows). Zero translucency, zero blur — panels are
/// cut material, not glass.
class MatPanel extends StatelessWidget {
  const MatPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.color,
    this.railColor,
    this.railWidth = 6,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Panel fill; defaults to the elevated mat surface.
  final Color? color;

  /// Optional accent strip down the left edge.
  final Color? railColor;
  final double railWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipRRect(
      borderRadius: Radii.mdAll,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? colors.surfaceElevated,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.outline),
        ),
        child: Stack(
          children: [
            if (railColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: railWidth,
                child: ColoredBox(color: railColor!),
              ),
            Padding(
              padding: railColor == null
                  ? padding
                  : padding.add(EdgeInsets.only(left: railWidth)),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
