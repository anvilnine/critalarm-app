import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/durations.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:critalarm/design_system/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A strip of tape: uppercase label on a solid color block with dark ink.
/// Neutral by default; pass a tape/status token for loud states. Slapped
/// down with a quick fade + settle on first appearance.
class TapeLabel extends StatelessWidget {
  const TapeLabel({required this.label, this.color, super.key});

  final String label;

  /// Tape color; defaults to the faint neutral strip.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final strip = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.onSurfaceFaint,
        borderRadius: Radii.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.eyebrow(
            colors.onPrimary,
          ).copyWith(letterSpacing: 0.8),
        ),
      ),
    );

    if (context.reduceMotion) return strip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.enter,
      curve: Curves.easeOut,
      child: strip,
      builder: (context, t, child) => Opacity(
        opacity: t,
        // Settle in — scales visually only, never nudges layout.
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
    );
  }
}
