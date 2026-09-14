import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Which edge the fade sits on.
enum ScrollFadeEdge { top, bottom }

/// A soft wash of the canvas colour over the edge of a scrolling list.
///
/// Content runs edge to edge and scrolls behind pinned chrome (the top bar, the
/// floating tab bar). This paints over the last few pixels so rows dissolve
/// into the background instead of being sliced by a hard line.
///
/// It never takes taps, so the list underneath still scrolls through it.
class AppScrollFade extends StatelessWidget {
  const AppScrollFade({
    required this.edge,
    this.height = 72,
    this.color,
    super.key,
  });

  final ScrollFadeEdge edge;
  final double height;

  /// Defaults to the current canvas, which follows the severity retint.
  final Color? color;

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
                base,
                base.withValues(alpha: 0.94),
                base.withValues(alpha: 0.62),
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
