import 'dart:ui' as ui;

import 'package:critalarm/design_system/edge_effect.dart';
import 'package:flutter/material.dart';

/// A subtle progressive blur along one edge of a scrolling list.
///
/// Content scrolling under the edge gets a little blurrier the closer it gets
/// to the screen edge. Taps and scrolls pass straight through.
/// `AppScreenScaffold` places it between the list and the top bar, so the
/// bar itself stays sharp.
///
/// What it draws follows [appEdgeEffect]: the shader blur, the older slice
/// blur, or nothing (the fade and none effects draw no blur).
class ProgressiveBlurEdge extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EdgeEffect>(
      valueListenable: appEdgeEffect,
      builder: (context, effect, _) {
        final program = edgeBlurProgram;
        return IgnorePointer(
          child: switch (effect) {
            EdgeEffect.shaderBlur when program != null => _ShaderEdge(
              program: program,
              height: height,
              isTop: isTop,
            ),
            EdgeEffect.sliceBlur => _SliceEdge(height: height, isTop: isTop),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

/// One plain blur, faded in towards the edge by `shaders/edge_blur.frag`.
///
/// The engine blurs the strip once, which it does cheaply, and the shader sets
/// how much of that blur shows at each row. Where it shows less, the sharp
/// screen behind comes through. That is one blur pass per edge, where the
/// slice blur needs one per slice.
///
/// The shader works in screen pixels, so it needs to know where this strip
/// sits on the screen. That is measured after each build and again when the
/// route finishes moving, because a page slides in from somewhere else.
class _ShaderEdge extends StatefulWidget {
  const _ShaderEdge({
    required this.program,
    required this.height,
    required this.isTop,
  });

  final ui.FragmentProgram program;
  final double height;
  final bool isTop;

  @override
  State<_ShaderEdge> createState() => _ShaderEdgeState();
}

class _ShaderEdgeState extends State<_ShaderEdge> {
  late final ui.FragmentShader _shader = widget.program.fragmentShader();

  /// Screen y of the top of this strip, in logical pixels. Null until the
  /// first measure, and nothing is drawn until then.
  double? _top;

  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation?..addStatusListener(_onRouteStatus);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _shader.dispose();
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status.isCompleted) _measure();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top != _top) setState(() => _top = top);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final top = _top;
    if (top == null) return const SizedBox.expand();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bottom = top + widget.height;
    // Floats 0 and 1 are the input size, which the engine sets.
    _shader
      ..setFloat(2, (widget.isTop ? top : bottom) * dpr)
      ..setFloat(3, (widget.isTop ? bottom : top) * dpr);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.shader(_shader),
          inner: ui.ImageFilter.blur(
            sigmaX: ProgressiveBlurEdge._maxSigma,
            sigmaY: ProgressiveBlurEdge._maxSigma,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The older blur: the edge cut into thin slices that sit side by side, each
/// blurring a tiny bit harder than its neighbour. One blur pass per slice, so
/// it costs far more than [_ShaderEdge]. Kept to compare the two on a device.
///
/// A blur cannot fade on its own, and it cannot sit under a [ShaderMask] or an
/// [Opacity] fade without losing what is behind it or showing a line where
/// each layer stops, which is why it is cut into slices. All slices share one
/// [BackdropKey], so the engine reads the screen behind them once instead of
/// once per slice.
class _SliceEdge extends StatefulWidget {
  const _SliceEdge({required this.height, required this.isTop});

  final double height;
  final bool isTop;

  /// Slices per edge. With a top blur of 4, neighbours differ by about 0.25.
  static const int _slices = 24;

  @override
  State<_SliceEdge> createState() => _SliceEdgeState();
}

class _SliceEdgeState extends State<_SliceEdge> {
  // One key per edge: the slices never overlap, so they can share one read
  // of the screen behind them.
  final _backdropKey = BackdropKey();

  // Rounded to whole device pixels so two slices never leave a gap between
  // them, which would show as a sharp hairline.
  late double _dpr;

  double _snap(double v) => (v * _dpr).round() / _dpr;

  @override
  Widget build(BuildContext context) {
    const n = _SliceEdge._slices;
    final sliceHeight = widget.height / n;
    _dpr = MediaQuery.devicePixelRatioOf(context);

    return Stack(
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
                  filter: ui.ImageFilter.blur(
                    sigmaX: _sigma(i),
                    sigmaY: _sigma(i),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
      ],
    );
  }

  /// Blur for slice [i]: full at the edge, easing to nothing at the inner
  /// end. Smoothstep keeps both ends flat, so there is no visible start.
  static double _sigma(int i) {
    const n = _SliceEdge._slices;
    final t = 1 - (i + 0.5) / n;
    return ProgressiveBlurEdge._maxSigma * (t * t * (3 - 2 * t));
  }
}
