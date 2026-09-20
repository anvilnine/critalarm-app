import 'dart:ui' show ImageFilter;

import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Which edge the fade sits on.
enum ScrollFadeEdge { top, bottom }

/// How many colour stops the ramp is cut into. A handful of stops shows its
/// own corners as faint lines across the list, which reads as a band sitting
/// on top of the content. This many steps reads as one continuous fade.
const int _rampSteps = 16;

/// Solid [base] against [edge], easing off to nothing at the far end.
///
/// The curve is smoothstep flipped over, so it leaves the edge flat and
/// arrives at nothing flat, with no visible start or finish to the wash. The
/// alpha [base] came with is the strongest the wash gets.
LinearGradient _fadeRamp(Color base, ScrollFadeEdge edge) {
  final isTop = edge == ScrollFadeEdge.top;
  final ramp = <Color>[];
  final stops = <double>[];
  for (var i = 0; i <= _rampSteps; i++) {
    final t = i / _rampSteps;
    ramp.add(base.withValues(alpha: base.a * (1 - (t * t * (3 - 2 * t)))));
    stops.add(t);
  }
  return LinearGradient(
    begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
    end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
    colors: ramp,
    stops: stops,
  );
}

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

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.appColors.canvas;
    if (base == Colors.transparent || base.a == 0) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: _fadeRamp(base, edge)),
        ),
      ),
    );
  }
}

/// A frosted wash behind a pinned bottom bar.
///
/// [AppScrollFade] paints the canvas colour, so it only shows up when the
/// canvas is what sits behind it. A pinned button also floats over a white
/// card, and over a screen that draws its own ambient canvas and leaves the
/// scaffold transparent. In both of those the wash alone is invisible and the
/// button looks pasted on. This blurs whatever is really behind the strip and
/// lays the same ramp on top, so rows dissolve on any background.
///
/// Like the plain fade it never takes taps.
class AppScrollScrim extends StatelessWidget {
  const AppScrollScrim({
    required this.height,
    required this.tint,
    super.key,
  });

  final double height;

  /// Colour of the wash over the blur. The alpha it comes with is the
  /// strongest the wash gets, right at the bottom edge.
  final Color tint;

  /// One entry per blur layer: how much of the strip it covers, measured from
  /// the bottom edge, and how hard it blurs.
  ///
  /// Each layer blurs what the one under it already blurred, so the strength
  /// builds towards the bottom edge instead of starting at the hard line a
  /// single blur would leave. The first layer is weak on purpose: its own top
  /// edge is the one that lands on sharp content.
  static const List<(double, double)> _blurLayers = [
    (1, 1.5),
    (0.78, 4),
    (0.5, 11),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final (run, sigma) in _blurLayers)
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: SizedBox(
                      height: height * run,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: _fadeRamp(tint, ScrollFadeEdge.bottom),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
