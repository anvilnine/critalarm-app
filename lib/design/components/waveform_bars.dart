import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A row of rounded bars, one per peak, sitting on the bottom edge.
///
/// Takes plain numbers (0 to 1), never a sound, so any screen can draw one.
/// Bars left of [progress] take [activeColor], the rest [idleColor]. With no
/// peaks yet it draws a flat dotted line, so the row does not jump when they
/// arrive. Fills whatever box it is given; give it a height.
///
/// While [loading] it draws soft placeholder bars that pulse. When peaks show
/// up after that, the bars grow from the bottom edge, left to right. With
/// reduced motion on, nothing pulses or grows: the bars just appear.
///
/// Screen readers skip it. The play button next to it carries the progress.
class WaveformBars extends StatefulWidget {
  const WaveformBars({
    required this.peaks,
    this.progress,
    this.activeColor,
    this.idleColor,
    this.barGap = 2,
    this.loading = false,
    super.key,
  });

  /// Bars drawn while there are no peaks.
  static const placeholderBars = 48;

  final List<double> peaks;

  /// 0 to 1, or null when nothing is playing.
  final double? progress;
  final Color? activeColor;
  final Color? idleColor;
  final double barGap;

  /// True while the peaks are still being read.
  final bool loading;

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.ring,
  );
  late final Animation<double> _pulseCurve = CurvedAnimation(
    parent: _pulse,
    curve: AppCurves.easeOut,
  );

  // Starts full, so bars that are already known on the first frame show
  // straight away. Only peaks that arrive later grow in.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: AppDurations.base,
    value: 1,
  );

  bool _reduceMotion = false;

  /// Gentle fixed heights for the loading bars, so they look like a sound
  /// without looking like any real one.
  static final List<double> _skeleton = [
    for (var i = 0; i < WaveformBars.placeholderBars; i++)
      .3 + .18 * math.sin(i * .55) * math.cos(i * .21),
  ];

  bool get _showSkeleton => widget.loading && widget.peaks.isEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    _syncPulse();
    if (_reduceMotion) _grow.value = 1;
  }

  @override
  void didUpdateWidget(covariant WaveformBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    final arrived = oldWidget.peaks.isEmpty && widget.peaks.isNotEmpty;
    if (arrived && !_reduceMotion) unawaited(_grow.forward(from: 0));
    _syncPulse();
  }

  void _syncPulse() {
    if (_showSkeleton && !_reduceMotion) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final idle = widget.idleColor ?? colors.ink.withValues(alpha: .28);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _grow]),
        builder: (context, child) {
          final skeleton = _showSkeleton;
          return CustomPaint(
            painter: WaveformBarsPainter(
              peaks: skeleton
                  ? _skeleton
                  : widget.peaks.isEmpty
                  ? List<double>.filled(WaveformBars.placeholderBars, 0)
                  : widget.peaks,
              progress: skeleton ? 0 : widget.progress ?? 0,
              activeColor: widget.activeColor ?? colors.highlight,
              idleColor: skeleton
                  ? idle.withValues(
                      alpha: idle.a * (.35 + .35 * _pulseCurve.value),
                    )
                  : idle,
              barGap: widget.barGap,
              grow: skeleton ? 1 : _grow.value,
            ),
            child: child,
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints [WaveformBars]. Public so a bigger editor can reuse the bars.
class WaveformBarsPainter extends CustomPainter {
  const WaveformBarsPainter({
    required this.peaks,
    required this.progress,
    required this.activeColor,
    required this.idleColor,
    this.barGap = 2,
    this.grow = 1,
  });

  final List<double> peaks;
  final double progress;
  final Color activeColor;
  final Color idleColor;
  final double barGap;

  /// 0 to 1. How far the bars have grown in. Each bar starts a little after
  /// the one to its left.
  final double grow;

  /// Share of the grow time spent waiting for the last bar to start.
  static const _stagger = .5;

  @override
  void paint(Canvas canvas, Size size) {
    final count = peaks.length;
    if (count == 0 || size.isEmpty) return;
    final barWidth = math.max<double>(
      1,
      (size.width - barGap * (count - 1)) / count,
    );
    final active = Paint()..color = activeColor;
    final idle = Paint()..color = idleColor;
    for (var i = 0; i < count; i++) {
      final start = count == 1 ? 0.0 : _stagger * i / (count - 1);
      final t = ((grow - start) / (1 - _stagger)).clamp(0.0, 1.0);
      final scale = grow >= 1 ? 1.0 : AppCurves.easeOut.transform(t);
      final height =
          math.max<double>(2, peaks[i].clamp(0.0, 1.0) * (size.height - 4)) *
          scale;
      if (height <= 0) continue;
      final x = i * (barWidth + barGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        i / count < progress ? active : idle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformBarsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.barGap != barGap ||
      oldDelegate.grow != grow ||
      !listEquals(oldDelegate.peaks, peaks);
}
