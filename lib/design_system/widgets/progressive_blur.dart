import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Overlays a subtle progressive blur on the top and bottom edges of its child.
///
/// Content scrolling under the edges gets gradually blurrier toward each edge.
/// The blur ramps from zero at the inner boundary to a small max sigma at the
/// very edge, with no visible hard line. Taps and scroll events pass through.
///
/// Built as several stacked [BackdropFilter] bands with increasing sigma and
/// decreasing [Opacity], so the seam of each band is hidden by the one above
/// it that is blending in harder. The topmost and thinnest layer blends in at
/// very low opacity, making its own inner edge invisible.
///
/// Works in both light and dark theme (filters whatever is behind it).
class ProgressiveBlur extends StatelessWidget {
  const ProgressiveBlur({
    required this.child,
    this.topHeight = 80.0,
    this.bottomHeight = 80.0,
    super.key,
  });

  /// The widget below the blur overlays.
  final Widget child;

  /// Height of the top blur zone in logical pixels.
  final double topHeight;

  /// Height of the bottom blur zone in logical pixels.
  final double bottomHeight;

  /// Blur layers: (fraction of zone height from the edge, sigmaX/Y, opacity).
  ///
  /// A blur has no smooth ramp of its own — it cuts. So we stack bands.
  /// Each band covers a smaller fraction (closer to the edge) and blurs harder.
  /// Opacity hides the inner edge of each band: the widest band blends in at
  /// a very low alpha so its seam is invisible, while the narrowest innermost
  /// bands are opaque and are hidden beneath the solid chrome at the edge.
  static const List<(double fraction, double sigma, double opacity)>
  _blurLayers = [
    (1.00, 1.0, 0.04),
    (0.82, 2.0, 0.15),
    (0.65, 3.5, 0.35),
    (0.48, 5.0, 0.60),
    (0.32, 6.0, 1.00),
  ];

  /// Builds one edge (top or bottom) as a stack of blur bands.
  Widget _buildEdge(double height, {required bool isTop}) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final (fraction, sigma, opacity) in _blurLayers)
              Align(
                alignment:
                    isTop ? Alignment.topCenter : Alignment.bottomCenter,
                child: Opacity(
                  opacity: opacity,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      // Transparent child: the filter is the whole point.
                      child: SizedBox(
                        height: height * fraction,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildEdge(topHeight, isTop: true),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildEdge(bottomHeight, isTop: false),
        ),
      ],
    );
  }
}
