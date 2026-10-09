import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/personalize/sound_hero_rules.dart';
import 'package:flutter/material.dart';

/// The Sound page's one large living thing: the wave of the sound that rings.
///
/// The bars are the sound's own peaks, between 14 and 40 of them by width.
/// At rest every bar is full and nothing moves. While a preview plays, the
/// bars left of the playhead stay full and the rest dim, following
/// [progress]. With no peaks (still being read, or unreadable) it draws flat
/// bars and no playhead.
///
/// Under reduce motion the playhead does not move: a preview shows the
/// finished wave, the same as at rest.
class SoundHero extends StatelessWidget {
  const SoundHero({
    required this.peaks,
    required this.isPlaying,
    required this.progress,
    required this.tone,
    required this.height,
    super.key,
  });

  /// The sound's peaks, 0 to 1, or null when none are known.
  final List<double>? peaks;

  /// Whether a preview plays.
  final bool isPlaying;

  /// How far the preview has got, 0 to 1. Only read while [isPlaying].
  final Animation<double> progress;

  final PassTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final moves = isPlaying && !context.reduceMotion;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) {
            final count = soundHeroBarCount(box.maxWidth);
            final bars = soundHeroBars(peaks, count);
            Widget paint(double? fill) => RepaintBoundary(
              child: CustomPaint(
                size: Size(box.maxWidth, height),
                painter: SoundHeroPainter(
                  bars: bars,
                  count: count,
                  fill: fill,
                  fullColor: tone.onGround,
                  dimColor: tone.onGround.withValues(alpha: 0.55),
                ),
              ),
            );
            if (!moves) return paint(null);
            return AnimatedBuilder(
              animation: progress,
              builder: (context, _) => paint(soundHeroFill(progress.value)),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the wave: rounded bars centred on the middle line.
class SoundHeroPainter extends CustomPainter {
  const SoundHeroPainter({
    required this.bars,
    required this.count,
    required this.fill,
    required this.fullColor,
    required this.dimColor,
  });

  /// The shortest a bar of a real wave gets, and the height of a flat bar.
  static const double minBar = 8;
  static const double flatBar = 6;

  /// Share of a bar's pitch that is bar and not gap.
  static const double _barShare = 0.56;

  /// One level per bar, 0 to 1. Empty draws [count] flat bars.
  final List<double> bars;
  final int count;

  /// The playhead, 0 to 1, or null at rest (every bar full).
  final double? fill;

  final Color fullColor;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0 || size.isEmpty) return;
    final isFlat = bars.isEmpty;
    final pitch = size.width / count;
    final barWidth = pitch * _barShare;
    final middle = size.height / 2;
    final full = Paint()..color = fullColor;
    final dim = Paint()..color = dimColor;
    for (var i = 0; i < count; i++) {
      final level = isFlat ? 0.0 : bars[i];
      final barHeight = isFlat
          ? flatBar
          : math.max(minBar, level * size.height);
      // A wave with nothing to follow has no playhead, so a flat bar is
      // always dim.
      final paint = !isFlat && soundHeroBarFilled(i, count, fill) ? full : dim;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(i * pitch + pitch / 2, middle),
            width: barWidth,
            height: barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SoundHeroPainter old) =>
      old.fill != fill ||
      old.count != count ||
      old.fullColor != fullColor ||
      old.dimColor != dimColor ||
      !_same(old.bars, bars);

  static bool _same(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The yellow Play or Stop circle. Yellow on the page's blue is
/// 5.03 to 1, the glyph in ink on the yellow is far above that.
class SoundPlayCircle extends StatelessWidget {
  const SoundPlayCircle({
    required this.isPlaying,
    required this.playLabel,
    required this.stopLabel,
    required this.onPressed,
    super.key,
  });

  /// As tall as the back ring, which it sits level with at the top right.
  static const double size = kPassRingSize;

  final bool isPlaying;
  final String playLabel;
  final String stopLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: isPlaying ? stopLabel : playLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onPressed();
        },
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.yellow,
          ),
          child: AppGlyph(
            isPlaying ? GlyphType.stop : GlyphType.play,
            size: 20,
            strokeWidth: 2,
            color: colors.inkFixed,
          ),
        ),
      ),
    );
  }
}
