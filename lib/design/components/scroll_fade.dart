import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Which edge the fade sits on.
enum ScrollFadeEdge { top, bottom }

/// A wash of the canvas colour over the edge of a scrolling list.
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
    super.key,
  });

  final ScrollFadeEdge edge;
  final double height;

  /// Defaults to the current canvas, which follows the severity retint.
  final Color? color;

  /// How many colour stops the ramp is cut into. A handful of stops shows its
  /// own corners as faint lines across the list, which reads as a band sitting
  /// on top of the content. This many steps reads as one continuous fade.
  static const int _rampSteps = 16;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.appColors.canvas;
    final isTop = edge == ScrollFadeEdge.top;

    // Solid canvas against the edge, easing off to nothing at the far end. The
    // curve is smoothstep flipped over, so it leaves the edge flat and arrives
    // at nothing flat, with no visible start or finish to the wash.
    final ramp = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= _rampSteps; i++) {
      final t = i / _rampSteps;
      ramp.add(base.withValues(alpha: 1 - (t * t * (3 - 2 * t))));
      stops.add(t);
    }

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: ramp,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}
