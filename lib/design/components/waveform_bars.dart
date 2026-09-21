import 'dart:math' as math;

import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A row of rounded bars, one per peak, sitting on the bottom edge.
///
/// Takes plain numbers (0 to 1), never a sound, so any screen can draw one.
/// Bars left of [progress] take [activeColor], the rest [idleColor]. With no
/// peaks yet it draws a flat dotted line, so the row does not jump when they
/// arrive. Fills whatever box it is given; give it a height.
///
/// Screen readers skip it. The play button next to it carries the progress.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    required this.peaks,
    this.progress,
    this.activeColor,
    this.idleColor,
    this.barGap = 2,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: WaveformBarsPainter(
          peaks: peaks.isEmpty
              ? List<double>.filled(placeholderBars, 0)
              : peaks,
          progress: progress ?? 0,
          activeColor: activeColor ?? colors.highlight,
          idleColor: idleColor ?? colors.ink.withValues(alpha: .28),
          barGap: barGap,
        ),
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
  });

  final List<double> peaks;
  final double progress;
  final Color activeColor;
  final Color idleColor;
  final double barGap;

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
      final height = math.max<double>(
        2,
        peaks[i].clamp(0.0, 1.0) * (size.height - 4),
      );
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
      !listEquals(oldDelegate.peaks, peaks);
}
