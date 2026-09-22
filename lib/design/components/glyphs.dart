import 'package:flutter/material.dart';

/// Supported icon glyph names matching docs/design-system/index.html GLYPHS.
enum GlyphType {
  down,
  minus,
  dot,
  up,
  bell,
  repeat,
  check,
  arrow,
  back,
  gear,
  copy,
  plus,
  search,
  filter,
  close,
  chevron,
  wifi,
  list,
  clock,
  play,
  stop,
  record,
  pencil,
}

/// Vector glyph icon painted according to index.html on a 24x24 viewBox.
class AppGlyph extends StatelessWidget {
  const AppGlyph(
    this.glyph, {
    this.size = 14.0,
    this.color,
    this.strokeWidth = 2.6,
    super.key,
  });

  final GlyphType glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF1A140F);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GlyphPainter(
          glyph: glyph,
          color: effectiveColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final GlyphType glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas
      ..save()
      ..scale(scale, scale);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (glyph) {
      case GlyphType.down:
        // M5 9l7 7 7-7
        final path = Path()
          ..moveTo(5, 9)
          ..lineTo(12, 16)
          ..lineTo(19, 9);
        canvas.drawPath(path, strokePaint);

      case GlyphType.minus:
        // M5 12h14
        final path = Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12);
        canvas.drawPath(path, strokePaint);

      case GlyphType.dot:
        // circle cx 12 cy 12 r 5 fill
        canvas.drawCircle(const Offset(12, 12), 5, fillPaint);

      case GlyphType.up:
        // M5 15l7-7 7 7
        final path = Path()
          ..moveTo(5, 15)
          ..lineTo(12, 8)
          ..lineTo(19, 15);
        canvas.drawPath(path, strokePaint);

      case GlyphType.bell:
        // M6 17V11a6 6 0 0112 0v6l2 2H4zM10 21h4
        final body = Path()
          ..moveTo(6, 17)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 17)
          ..lineTo(20, 19)
          ..lineTo(4, 19)
          ..close();
        canvas.drawPath(body, strokePaint);

        final clapper = Path()
          ..moveTo(10, 21)
          ..lineTo(14, 21);
        canvas.drawPath(clapper, strokePaint);

      case GlyphType.repeat:
        // M17 2l4 4-4 4 M3 11V8a2 2 0 012-2h16
        // M7 22l-4-4 4-4 M21 13v3a2 2 0 01-2 2H3
        final path = Path()
          ..moveTo(17, 2)
          ..lineTo(21, 6)
          ..lineTo(17, 10)
          ..moveTo(3, 11)
          ..lineTo(3, 8)
          ..quadraticBezierTo(3, 6, 5, 6)
          ..lineTo(21, 6)
          ..moveTo(7, 22)
          ..lineTo(3, 18)
          ..lineTo(7, 14)
          ..moveTo(21, 13)
          ..lineTo(21, 16)
          ..quadraticBezierTo(21, 18, 19, 18)
          ..lineTo(3, 18);
        canvas.drawPath(path, strokePaint);

      case GlyphType.check:
        // M4 12l6 6L20 6
        final path = Path()
          ..moveTo(4, 12)
          ..lineTo(10, 18)
          ..lineTo(20, 6);
        canvas.drawPath(path, strokePaint);

      case GlyphType.arrow:
        // M5 12h14M13 6l6 6-6 6
        final path = Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18);
        canvas.drawPath(path, strokePaint);

      case GlyphType.back:
        // M15 5l-7 7 7 7
        final path = Path()
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
        canvas.drawPath(path, strokePaint);

      case GlyphType.gear:
        // circle cx 12 cy 12 r 3 + spokes
        canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
        final spokes = Path()
          ..moveTo(12, 2)
          ..lineTo(12, 5)
          ..moveTo(12, 19)
          ..lineTo(12, 22)
          ..moveTo(2, 12)
          ..lineTo(5, 12)
          ..moveTo(19, 12)
          ..lineTo(22, 12)
          ..moveTo(4.9, 4.9)
          ..lineTo(7, 7)
          ..moveTo(17, 17)
          ..lineTo(19.1, 19.1)
          ..moveTo(4.9, 19.1)
          ..lineTo(7, 17)
          ..moveTo(17, 7)
          ..lineTo(19.1, 4.9);
        canvas.drawPath(spokes, strokePaint);

      case GlyphType.copy:
        // Two overlapping document rectangles
        final r1 = RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 12, 12),
          const Radius.circular(2),
        );
        final r2 = Path()
          ..moveTo(16, 8)
          ..lineTo(16, 4)
          ..lineTo(4, 4)
          ..lineTo(4, 16)
          ..lineTo(8, 16);
        canvas.drawRRect(r1, strokePaint);
        canvas.drawPath(r2, strokePaint);

      case GlyphType.plus:
        // M12 5v14M5 12h14
        final path = Path()
          ..moveTo(12, 5)
          ..lineTo(12, 19)
          ..moveTo(5, 12)
          ..lineTo(19, 12);
        canvas.drawPath(path, strokePaint);

      case GlyphType.search:
        // circle cx 11 cy 11 r 7, then the handle down to 21 21
        canvas.drawCircle(const Offset(11, 11), 7, strokePaint);
        final handle = Path()
          ..moveTo(16, 16)
          ..lineTo(21, 21);
        canvas.drawPath(handle, strokePaint);

      case GlyphType.filter:
        // M4 6h16M7 12h10M10 18h4
        final path = Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(7, 12)
          ..lineTo(17, 12)
          ..moveTo(10, 18)
          ..lineTo(14, 18);
        canvas.drawPath(path, strokePaint);

      case GlyphType.close:
        // M6 6l12 12M18 6L6 18
        final path = Path()
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(18, 6)
          ..lineTo(6, 18);
        canvas.drawPath(path, strokePaint);

      case GlyphType.chevron:
        // M9 5l7 7-7 7
        final path = Path()
          ..moveTo(9, 5)
          ..lineTo(16, 12)
          ..lineTo(9, 19);
        canvas.drawPath(path, strokePaint);

      case GlyphType.wifi:
        // three arcs widening upward, one dot on the baseline
        for (final r in [4.0, 8.0, 12.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 18), radius: r),
            3.9270,
            1.5708,
            false,
            strokePaint,
          );
        }
        canvas.drawCircle(const Offset(12, 18), 1.4, fillPaint);

      case GlyphType.list:
        // M4 6h16M4 12h16M4 18h16
        final path = Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(4, 12)
          ..lineTo(20, 12)
          ..moveTo(4, 18)
          ..lineTo(20, 18);
        canvas.drawPath(path, strokePaint);

      case GlyphType.clock:
        // circle cx 12 cy 12 r 9, then the two hands
        canvas.drawCircle(const Offset(12, 12), 9, strokePaint);
        final hands = Path()
          ..moveTo(12, 7)
          ..lineTo(12, 12)
          ..lineTo(15, 14);
        canvas.drawPath(hands, strokePaint);

      case GlyphType.play:
        // M8.5 5l11 7-11 7z, filled, corners rounded by the stroke
        final path = Path()
          ..moveTo(8.5, 5)
          ..lineTo(19.5, 12)
          ..lineTo(8.5, 19)
          ..close();
        canvas
          ..drawPath(path, fillPaint)
          ..drawPath(path, strokePaint);

      case GlyphType.stop:
        // rounded square 10x10 in the middle
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 7, 10, 10),
            const Radius.circular(2),
          ),
          fillPaint,
        );

      case GlyphType.record:
        // circle cx 12 cy 12 r 6 fill
        canvas.drawCircle(const Offset(12, 12), 6, fillPaint);

      case GlyphType.pencil:
        // M4 20l1-4L16 5l3 3L8 19zM14 7l3 3
        final path = Path()
          ..moveTo(4, 20)
          ..lineTo(5, 16)
          ..lineTo(16, 5)
          ..lineTo(19, 8)
          ..lineTo(8, 19)
          ..close()
          ..moveTo(14, 7)
          ..lineTo(17, 10);
        canvas.drawPath(path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
