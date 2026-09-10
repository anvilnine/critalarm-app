import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:flutter/material.dart';

/// A horizontal filled track — solid safety-orange fill against a solid mat
/// track, hard tight corners. No gradients, no glow: progress reads as cut
/// material, like every other primitive here.
class ProgressRail extends StatelessWidget {
  const ProgressRail({required this.progress, this.height = 10, super.key});

  /// 0..1; values outside the range are clamped.
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: Radii.smAll,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            border: Border.all(color: colors.outline),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clamped,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
