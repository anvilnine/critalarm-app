import 'dart:math' as math;

import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Round play button for a sound. While playing it turns into a stop button
/// with a ring that fills as the sound plays.
///
/// The labels come in from the screen, so the component knows no strings.
/// [progressLabel] is read out as the button's value while playing, for
/// example "40 percent played".
class AppPreviewButton extends StatelessWidget {
  const AppPreviewButton({
    required this.isPlaying,
    required this.onPressed,
    required this.playLabel,
    required this.stopLabel,
    this.progress,
    this.progressLabel,
    super.key,
  });

  static const size = 40.0;

  final bool isPlaying;
  final VoidCallback onPressed;
  final String playLabel;
  final String stopLabel;

  /// 0 to 1. Only drawn while [isPlaying].
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: isPlaying ? stopLabel : playLabel,
      value: isPlaying ? progressLabel : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isPlaying ? 32 : size,
                height: isPlaying ? 32 : size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? colors.highlight : colors.surface,
                  border: isPlaying ? null : Border.all(color: colors.hairline),
                ),
                alignment: Alignment.center,
                child: AppGlyph(
                  isPlaying ? GlyphType.stop : GlyphType.play,
                  size: 24,
                  strokeWidth: 2,
                  color: isPlaying ? colors.onHighlight : colors.ink,
                ),
              ),
              if (isPlaying)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: (progress ?? 0).clamp(0, 1),
                      track: colors.hairline,
                      fill: colors.highlight,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas
      ..drawArc(rect, 0, math.pi * 2, false, stroke..color = track)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        stroke
          ..color = fill
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
