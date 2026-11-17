import 'dart:ui' as ui;

import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design_system/edge_effect.dart';
import 'package:flutter/material.dart';
import 'package:foldable_ext/foldable_ext.dart';

/// A subtle progressive blur along one edge of a scrolling list.
///
/// Content scrolling under the edge gets a little blurrier the closer it gets
/// to the screen edge. Taps and scrolls pass straight through.
/// `AppScreenScaffold` places it between the list and the top bar, so the
/// bar itself stays sharp.
///
/// What it draws follows [appEdgeEffect]: the shader blur, the older slice
/// blur, or nothing (the fade and none effects draw no blur). It draws
/// nothing on a short display, such as a phone on its side, whatever the
/// effect.
class ProgressiveBlurEdge extends StatelessWidget {
  const ProgressiveBlurEdge({
    required this.height,
    required this.isTop,
    this.maxSigma = quietSigma,
    this.plateau = 0,
    super.key,
  });

  /// Height of the blur zone in logical pixels.
  final double height;

  /// True for the top edge, false for the bottom.
  final bool isTop;

  /// Blur strength right at the screen edge. A larger number makes the one
  /// blur stronger. It never adds a blur pass or a slice.
  final double maxSigma;

  /// How much of [height], in logical pixels from the screen edge, holds
  /// the full blur before it starts to ease off. 0, the default, is fully
  /// progressive: the blur is full only at the screen edge.
  final double plateau;

  /// The blur of an edge with nothing to hide. Kept low so the effect stays
  /// quiet.
  static const double quietSigma = 4;

  /// Slices per edge in the slice blur, whatever the strength.
  static const int sliceCount = 24;

  /// Below this a blur is not worth a pass.
  static const double _leastSigma = 0.05;

  /// The blur of each slice of the slice blur, from the screen edge inwards:
  /// full at the edge, easing to nothing at the inner end. Smoothstep keeps
  /// both ends flat, so there is no visible start. Always [sliceCount] long:
  /// [maxSigma] scales every slice and adds none.
  static List<double> sliceSigmas(double maxSigma) => [
    for (var i = 0; i < sliceCount; i++) _sliceSigma(i, maxSigma),
  ];

  static double _sliceSigma(int i, double maxSigma) {
    final t = 1 - (i + 0.5) / sliceCount;
    return maxSigma * (t * t * (3 - 2 * t));
  }

  @override
  Widget build(BuildContext context) {
    // A phone on its side keeps the colour fade and draws no blur. A tablet
    // or an open foldable on its side is tall enough to keep it: its panes
    // scroll under the bar like a portrait screen does.
    if (AppSize.of(context).isShort) return const SizedBox.shrink();
    if (maxSigma < _leastSigma) return const SizedBox.shrink();
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
              maxSigma: maxSigma,
              plateau: plateau,
            ),
            EdgeEffect.sliceBlur => _SliceEdge(
              height: height,
              isTop: isTop,
              maxSigma: maxSigma,
              plateau: plateau,
            ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

/// The two screen rows, in physical pixels, the edge blur shader fades
/// between: the blur is whole from `full` outwards and gone at `clear`.
///
/// - [top] and [bottom]: where the strip is drawn, in logical pixels of the
///   screen.
/// - [origin]: screen y, in logical pixels, of the top of the buffer the
///   strip is drawn into. The shader counts rows from there. 0 when the app
///   draws straight to the screen.
/// - [height] and [plateau]: the strip and its full blur part as they are
///   laid out. A strip drawn at another size than [height] scales the
///   plateau with it.
/// - [pixelRatio]: physical pixels per logical pixel of the screen.
///
/// The shader holds the full blur from the first row outwards, so moving
/// that row in by the plateau keeps the blur full under the bar.
({double full, double clear}) edgeBlurRows({
  required double top,
  required double bottom,
  required double height,
  required double plateau,
  required bool isTop,
  required double pixelRatio,
  double origin = 0,
}) {
  final drawn = height > 0 ? (bottom - top) / height : 1.0;
  final held = plateau.clamp(0.0, height) * drawn;
  return (
    full: ((isTop ? top + held : bottom - held) - origin) * pixelRatio,
    clear: ((isTop ? bottom : top) - origin) * pixelRatio,
  );
}

/// One plain blur, faded in towards the edge by `shaders/edge_blur.frag`.
///
/// The engine blurs the strip once, which it does cheaply, and the shader sets
/// how much of that blur shows at each row. Where it shows less, the sharp
/// screen behind comes through. That is one blur pass per edge, where the
/// slice blur needs one per slice.
///
/// The shader works in the pixels of the buffer it draws into, so it needs to
/// know where this strip sits in that buffer. That is measured after each
/// build and again when the route finishes moving, because a page slides in
/// from somewhere else.
///
/// The buffer is the screen, except in an emulated window (an app rendered
/// as an iPhone Duo on another device). That window draws into a buffer of
/// its own that starts at the window's top, so rows are counted from there.
class _ShaderEdge extends StatefulWidget {
  const _ShaderEdge({
    required this.program,
    required this.height,
    required this.isTop,
    required this.maxSigma,
    required this.plateau,
  });

  final ui.FragmentProgram program;
  final double height;
  final bool isTop;
  final double maxSigma;
  final double plateau;

  @override
  State<_ShaderEdge> createState() => _ShaderEdgeState();
}

class _ShaderEdgeState extends State<_ShaderEdge> {
  late final ui.FragmentShader _shader = widget.program.fragmentShader();

  /// Screen y of the top and the bottom of this strip, in logical pixels of
  /// the screen. Null until the first measure, and nothing is drawn until
  /// then.
  double? _top;
  double? _bottom;

  /// Screen y of the top of the buffer this strip draws into.
  double _origin = 0;

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
    // Both ends, so a strip drawn smaller or larger than it is laid out
    // (an app scaled to fit the screen) is measured at the size it is drawn.
    // The laid out size, not `widget.height`: on the frame the height
    // changes, the box still has the old one.
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final origin = _bufferTop(box);
    if (top != _top || bottom != _bottom || origin != _origin) {
      setState(() {
        _top = top;
        _bottom = bottom;
        _origin = origin;
      });
    }
  }

  /// Screen y of the top of the buffer [box] paints into: the top of the
  /// nearest emulated window that is drawn, or 0 for the screen.
  static double _bufferTop(RenderBox box) {
    var node = box.parent;
    while (node != null) {
      if (node is RenderEmulatedWindow && node.placement != null) {
        final window = node.child;
        if (window != null) return window.localToGlobal(Offset.zero).dy;
      }
      node = node.parent;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final top = _top;
    final bottom = _bottom;
    if (top == null || bottom == null) return const SizedBox.expand();

    // Floats 0 and 1 are the input size, which the engine sets.
    final rows = edgeBlurRows(
      top: top,
      bottom: bottom,
      origin: _origin,
      height: widget.height,
      plateau: widget.plateau,
      isTop: widget.isTop,
      // The screen's own ratio. `MediaQuery` can describe a window that is
      // drawn at another scale.
      pixelRatio: View.of(context).devicePixelRatio,
    );
    _shader
      ..setFloat(2, rows.full)
      ..setFloat(3, rows.clear);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.shader(_shader),
          inner: ui.ImageFilter.blur(
            sigmaX: widget.maxSigma,
            sigmaY: widget.maxSigma,
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
  const _SliceEdge({
    required this.height,
    required this.isTop,
    required this.maxSigma,
    required this.plateau,
  });

  final double height;
  final bool isTop;
  final double maxSigma;
  final double plateau;

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
    const n = ProgressiveBlurEdge.sliceCount;
    final plateau = widget.plateau.clamp(0.0, widget.height);
    final sliceHeight = (widget.height - plateau) / n;
    final sigmas = ProgressiveBlurEdge.sliceSigmas(widget.maxSigma);
    _dpr = MediaQuery.devicePixelRatioOf(context);

    // Where slice i starts, measured from the screen edge. The first slice
    // also covers the plateau, so the count stays the same.
    double start(int i) => i == 0 ? 0 : plateau + i * sliceHeight;

    return Stack(
      children: [
        for (var i = 0; i < n; i++)
          // i = 0 is the slice right at the screen edge.
          if (sigmas[i] > ProgressiveBlurEdge._leastSigma)
            Positioned(
              left: 0,
              right: 0,
              top: widget.isTop
                  ? _snap(start(i))
                  : _snap(widget.height) - _snap(start(i + 1)),
              height: _snap(start(i + 1)) - _snap(start(i)),
              child: ClipRect(
                child: BackdropFilter(
                  backdropGroupKey: _backdropKey,
                  filter: ui.ImageFilter.blur(
                    sigmaX: sigmas[i],
                    sigmaY: sigmas[i],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
      ],
    );
  }
}
