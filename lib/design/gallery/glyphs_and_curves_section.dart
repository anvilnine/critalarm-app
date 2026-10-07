import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Every glyph in the set by name, and the motion curves drawn as graphs.
class GlyphsAndCurvesSection extends StatelessWidget {
  const GlyphsAndCurvesSection({super.key});

  static const _curves = <(String, String, Curve)>[
    ('easeOut', 'Anything entering the frame.', AppCurves.easeOut),
    ('easeSpring', 'A hover, a press, a landing.', AppCurves.easeSpring),
    ('easeBack', 'A pop that lands past its size.', AppCurves.easeBack),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final caption = AppTypography.mono(colors.onCanvasMuted, fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Glyphs', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: Spacing.s2),
        Text(
          'One set on a 24 unit grid, drawn with AppGlyph. A screen that '
          'needs a glyph the set lacks adds it here, never a painter of its '
          'own.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s4),
        Wrap(
          spacing: Spacing.s3,
          runSpacing: Spacing.s3,
          children: [
            for (final glyph in GlyphType.values)
              SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: Radii.mdAll,
                      ),
                      child: AppGlyph(glyph, size: 22, color: colors.ink),
                    ),
                    const SizedBox(height: Spacing.s1),
                    Text(glyph.name, maxLines: 1, style: caption),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.s8),
        Text('Motion curves', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: Spacing.s2),
        Text(
          'Time runs left to right. The dashed line is the resting value, so '
          'what rises over it is the overshoot.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s4),
        Wrap(
          spacing: Spacing.s4,
          runSpacing: Spacing.s4,
          children: [
            for (final (name, use, curve) in _curves)
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(Spacing.s3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: Radii.mdAll,
                      ),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _CurvePainter(
                          curve: curve,
                          line: colors.highlight,
                          rule: colors.ink.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.s1),
                    Text(name, style: caption.copyWith(color: colors.onCanvas)),
                    Text(use, style: AppTypography.small(colors.onCanvasMuted)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A curve from 0 to 1, with headroom above 1 for an overshoot.
class _CurvePainter extends CustomPainter {
  const _CurvePainter({
    required this.curve,
    required this.line,
    required this.rule,
  });

  final Curve curve;
  final Color line;
  final Color rule;

  /// The value at the top edge of the graph.
  static const double _top = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double value) => size.height * (1 - value / _top);

    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y(1)), Offset(x + 3, y(1)), rulePaint);
    }

    const steps = 60;
    final path = Path()..moveTo(0, y(0));
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      path.lineTo(size.width * t, y(curve.transform(t)));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.curve != curve || old.line != line || old.rule != rule;
}
