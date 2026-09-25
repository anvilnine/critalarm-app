import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A subtle progressive blur along one edge of a scrolling list.
///
/// Content scrolling under the edge gets a little blurrier the closer it gets
/// to the screen edge. Taps and scrolls pass straight through.
/// `AppScreenScaffold` places it between the list and the top bar, so the
/// bar itself stays sharp.
///
/// A blur cannot fade on its own, and it cannot sit under a [ShaderMask] or an
/// [Opacity] fade without losing what is behind it or showing a line where
/// each layer stops. So the edge is cut into many thin slices that sit side
/// by side, never on top of each other. Each slice blurs a tiny bit harder
/// than its neighbour, so the step between two slices is too small to see.
/// All slices share one [BackdropKey], so the engine reads the screen behind
/// them once instead of once per slice.
class ProgressiveBlurEdge extends StatefulWidget {
  const ProgressiveBlurEdge({
    required this.height,
    required this.isTop,
    super.key,
  });

  /// Height of the blur zone in logical pixels.
  final double height;

  /// True for the top edge, false for the bottom.
  final bool isTop;

  /// Blur strength right at the screen edge. Kept low so the effect stays
  /// quiet.
  static const double _maxSigma = 4;

  /// Slices per edge. With [_maxSigma] at 4, neighbours differ by about 0.25.
  static const int _slices = 24;

  @override
  State<ProgressiveBlurEdge> createState() => _EdgeState();
}

class _EdgeState extends State<ProgressiveBlurEdge> {
  // One key per edge: the slices never overlap, so they can share one read
  // of the screen behind them.
  final _backdropKey = BackdropKey();

  // Rounded to whole device pixels so two slices never leave a gap between
  // them, which would show as a sharp hairline.
  late double _dpr;

  double _snap(double v) => (v * _dpr).round() / _dpr;

  @override
  Widget build(BuildContext context) {
    const n = ProgressiveBlurEdge._slices;
    final sliceHeight = widget.height / n;
    _dpr = MediaQuery.devicePixelRatioOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            // i = 0 is the slice right at the screen edge.
            if (_sigma(i) > 0.05)
              Positioned(
                left: 0,
                right: 0,
                top: widget.isTop
                    ? _snap(i * sliceHeight)
                    : _snap(widget.height) - _snap((i + 1) * sliceHeight),
                height: _snap((i + 1) * sliceHeight) - _snap(i * sliceHeight),
                child: ClipRect(
                  child: BackdropFilter(
                    backdropGroupKey: _backdropKey,
                    filter: ImageFilter.blur(
                      sigmaX: _sigma(i),
                      sigmaY: _sigma(i),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Blur for slice [i]: full at the edge, easing to nothing at the inner
  /// end. Smoothstep keeps both ends flat, so there is no visible start.
  static double _sigma(int i) {
    const n = ProgressiveBlurEdge._slices;
    final t = 1 - (i + 0.5) / n;
    return ProgressiveBlurEdge._maxSigma * (t * t * (3 - 2 * t));
  }
}
