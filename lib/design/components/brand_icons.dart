import 'package:flutter/material.dart';

/// Supported brand icon types.
enum BrandIconType {
  google,
  apple,
  github,
}

/// Crisp vector brand icon rendered at any size on a 24x24 viewBox.
class BrandIcon extends StatelessWidget {
  const BrandIcon.google({super.key, this.size = 20.0})
    : type = BrandIconType.google,
      color = null;

  const BrandIcon.apple({super.key, this.size = 20.0, this.color})
    : type = BrandIconType.apple;

  const BrandIcon.github({super.key, this.size = 20.0, this.color})
    : type = BrandIconType.github;

  final BrandIconType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF1A140F);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BrandIconPainter(
          type: type,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class _BrandIconPainter extends CustomPainter {
  const _BrandIconPainter({
    required this.type,
    required this.color,
  });

  final BrandIconType type;
  final Color color;

  static final Path _googleBlue = _parseSvgPath(
    'M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 '
    '3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z',
  );
  static final Path _googleGreen = _parseSvgPath(
    'M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 '
    '1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z',
  );
  static final Path _googleYellow = _parseSvgPath(
    'M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 '
    '8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z',
  );
  static final Path _googleRed = _parseSvgPath(
    'M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 '
    '1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z',
  );

  static final Path _applePath = _parseSvgPath(
    'M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 '
    '0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 '
    '9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 '
    '3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 '
    '4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.42c.67-.82 1.13-1.96 '
    '.99-3.12-1.01.04-2.24.68-2.94 1.5-.62.72-1.16 1.88-1.02 3 1.13.09 2.28 '
    '-.58 2.97-1.38z',
  );

  static final Path _githubPath = _parseSvgPath(
    'M12 2C6.477 2 2 6.477 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5 '
    'v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62 '
    '.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.1-.65 '
    '.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1 '
    '-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 '
    '1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65 '
    '.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85 '
    'V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas
      ..save()
      ..scale(scale, scale);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case BrandIconType.google:
        canvas
          ..drawPath(
            _googleBlue,
            fillPaint..color = const Color(0xFF4285F4),
          )
          ..drawPath(
            _googleGreen,
            fillPaint..color = const Color(0xFF34A853),
          )
          ..drawPath(
            _googleYellow,
            fillPaint..color = const Color(0xFFFBBC05),
          )
          ..drawPath(
            _googleRed,
            fillPaint..color = const Color(0xFFEA4335),
          );

      case BrandIconType.apple:
        canvas.drawPath(_applePath, fillPaint..color = color);

      case BrandIconType.github:
        canvas.drawPath(_githubPath, fillPaint..color = color);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

Path _parseSvgPath(String d) {
  final path = Path();
  final regex = RegExp(r'([a-zA-Z]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?)');
  final matches = regex.allMatches(d).map((m) => m.group(0)!).toList();
  var idx = 0;
  var curX = 0.0;
  var curY = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var cmd = '';

  while (idx < matches.length) {
    final token = matches[idx];
    if (RegExp(r'^[a-zA-Z]$').hasMatch(token)) {
      cmd = token;
      idx++;
    }

    switch (cmd) {
      case 'M':
        final x = double.parse(matches[idx++]);
        final y = double.parse(matches[idx++]);
        curX = x;
        curY = y;
        startX = x;
        startY = y;
        path.moveTo(curX, curY);
        cmd = 'L';
      case 'm':
        final dx = double.parse(matches[idx++]);
        final dy = double.parse(matches[idx++]);
        curX += dx;
        curY += dy;
        startX = curX;
        startY = curY;
        path.moveTo(curX, curY);
        cmd = 'l';
      case 'L':
        final x = double.parse(matches[idx++]);
        final y = double.parse(matches[idx++]);
        curX = x;
        curY = y;
        path.lineTo(curX, curY);
      case 'l':
        final dx = double.parse(matches[idx++]);
        final dy = double.parse(matches[idx++]);
        curX += dx;
        curY += dy;
        path.lineTo(curX, curY);
      case 'H':
        curX = double.parse(matches[idx++]);
        path.lineTo(curX, curY);
      case 'h':
        curX += double.parse(matches[idx++]);
        path.lineTo(curX, curY);
      case 'V':
        curY = double.parse(matches[idx++]);
        path.lineTo(curX, curY);
      case 'v':
        curY += double.parse(matches[idx++]);
        path.lineTo(curX, curY);
      case 'C':
        final x1 = double.parse(matches[idx++]);
        final y1 = double.parse(matches[idx++]);
        final x2 = double.parse(matches[idx++]);
        final y2 = double.parse(matches[idx++]);
        final x = double.parse(matches[idx++]);
        final y = double.parse(matches[idx++]);
        curX = x;
        curY = y;
        path.cubicTo(x1, y1, x2, y2, curX, curY);
      case 'c':
        final dx1 = double.parse(matches[idx++]);
        final dy1 = double.parse(matches[idx++]);
        final dx2 = double.parse(matches[idx++]);
        final dy2 = double.parse(matches[idx++]);
        final dx = double.parse(matches[idx++]);
        final dy = double.parse(matches[idx++]);
        path.cubicTo(
          curX + dx1,
          curY + dy1,
          curX + dx2,
          curY + dy2,
          curX + dx,
          curY + dy,
        );
        curX += dx;
        curY += dy;
      case 'A':
        final rx = double.parse(matches[idx++]);
        final ry = double.parse(matches[idx++]);
        final _ = double.parse(matches[idx++]); // rot
        final _ = double.parse(matches[idx++]); // largeArc
        final sweep = double.parse(matches[idx++]) != 0;
        final x = double.parse(matches[idx++]);
        final y = double.parse(matches[idx++]);
        curX = x;
        curY = y;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          clockwise: sweep,
        );
      case 'Z' || 'z':
        path.close();
        curX = startX;
        curY = startY;
        cmd = '';
      default:
        idx++;
    }
  }

  return path;
}
