import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Which edge the fade sits on.
enum ScrollFadeEdge { top, bottom }

/// A soft wash of the canvas colour over the edge of a scrolling list.
///
/// Content runs edge to edge and scrolls behind pinned chrome (the floating tab
/// bar, a pinned button). This paints over the last few pixels so rows dissolve
/// into the background instead of being sliced by a hard line.
///
/// It never takes taps, so the list underneath still scrolls through it.
class AppScrollFade extends StatelessWidget {
  const AppScrollFade({
    required this.edge,
    this.height = 72,
    this.color,
    this.strength = 1,
    super.key,
  });

  final ScrollFadeEdge edge;
  final double height;

  /// Defaults to the current canvas, which follows the severity retint.
  final Color? color;

  /// Scales every step of the ramp. 1 hides the rows behind a pinned button.
  /// Lower values only take the edge off, for chrome that floats clear of the
  /// content and should not look like it sits on a band.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.appColors.canvas;
    final isTop = edge == ScrollFadeEdge.top;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                base.withValues(alpha: strength),
                base.withValues(alpha: 0.94 * strength),
                base.withValues(alpha: 0.62 * strength),
                base.withValues(alpha: 0),
              ],
              stops: const [0, 0.42, 0.72, 1],
            ),
          ),
        ),
      ),
    );
  }
}
