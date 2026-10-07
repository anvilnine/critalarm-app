import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:flutter/material.dart';

// The small size of every preview: one mark on one tile. They all share the
// tile's shape, fill and corner, and the mark's colour, weight and size, so
// a row of them reads as one set. Nothing on it moves.

/// The side of the tile in a box whose short side is [edge].
double previewGlyphTileEdge(double edge) =>
    math.min(edge, PaywallPreviewClass.small.edge);

/// The corner of a tile [edge] wide.
double previewGlyphTileRadius(double edge) => math.min(Radii.sm, edge * 0.22);

/// The side of the mark on a tile [edge] wide.
double previewGlyphSize(double edge) => edge * 0.5;

/// How thick a mark's line is, on the 24 unit grid every glyph is drawn on.
/// It is the glyph set's own weight.
const double previewGlyphStroke = 2.6;

/// A mark the glyph set does not have, drawn on the same grid with the same
/// line.
enum PreviewMark {
  /// A home screen: one wide widget over two app icons.
  homeWidget,

  /// An app icon with a face on it.
  appIcon,

  /// A calendar page with a tick on it.
  weeklyCheck,

  /// A code in a viewfinder: four corner marks around a few squares.
  scanCode,

  /// A waveform: five bars of a sound.
  soundWave,

  /// A phone with a face on its screen and a button under it.
  alarmScreen,
}

/// One mark on the shared tile, centred in [size].
class PreviewGlyphTile extends StatelessWidget {
  /// A glyph from the design system's set.
  const PreviewGlyphTile.glyph(
    GlyphType this.glyph, {
    required this.size,
    super.key,
  }) : mark = null,
       text = null;

  /// A drawn mark.
  const PreviewGlyphTile.mark(
    PreviewMark this.mark, {
    required this.size,
    super.key,
  }) : glyph = null,
       text = null;

  /// A short number, set in the display face at the weight of the line.
  const PreviewGlyphTile.text(
    String this.text, {
    required this.size,
    super.key,
  }) : glyph = null,
       mark = null;

  final Size size;
  final GlyphType? glyph;
  final PreviewMark? mark;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final edge = previewGlyphTileEdge(size.shortestSide);
    final glyphSize = previewGlyphSize(edge);

    final Widget child;
    if (glyph case final glyph?) {
      child = AppGlyph(
        glyph,
        size: glyphSize,
        color: colors.ink,
      );
    } else if (mark case final mark?) {
      child = CustomPaint(
        size: Size.square(glyphSize),
        painter: _MarkPainter(mark: mark, color: colors.ink),
      );
    } else {
      child = SizedBox(
        width: edge * 0.76,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text!,
            maxLines: 1,
            softWrap: false,
            style: AppTypography.display(colors.ink).copyWith(
              fontSize: edge * 0.3,
              height: 1,
              letterSpacing: -0.02 * edge * 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    return SizedBox.fromSize(
      size: size,
      child: Center(
        // A picture: it does not follow the text size.
        child: MediaQuery.withNoTextScaling(
          child: Container(
            width: edge,
            height: edge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cream,
              borderRadius: BorderRadius.circular(
                previewGlyphTileRadius(edge),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.mark, required this.color});

  final PreviewMark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas
      ..save()
      ..scale(scale, scale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = previewGlyphStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color;

    RRect box(double l, double t, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

    switch (mark) {
      case PreviewMark.homeWidget:
        canvas
          ..drawRRect(box(4, 4, 16, 9, 3), stroke)
          ..drawRRect(box(2.7, 16.3, 7.8, 5, 1.8), fill)
          ..drawRRect(box(13.5, 16.3, 7.8, 5, 1.8), fill);

      case PreviewMark.appIcon:
        canvas
          ..drawRRect(box(4, 4, 16, 16, 5), stroke)
          ..drawCircle(const Offset(9.4, 10.2), 1.2, fill)
          ..drawCircle(const Offset(14.6, 10.2), 1.2, fill)
          ..drawPath(
            Path()
              ..moveTo(9, 14)
              ..quadraticBezierTo(12, 16.8, 15, 14),
            stroke,
          );

      case PreviewMark.weeklyCheck:
        canvas
          ..drawRRect(box(4, 5, 16, 15, 3), stroke)
          ..drawPath(
            Path()
              ..moveTo(8, 3)
              ..lineTo(8, 6)
              ..moveTo(16, 3)
              ..lineTo(16, 6)
              ..moveTo(8.6, 13.6)
              ..lineTo(11, 16)
              ..lineTo(15.6, 11.2),
            stroke,
          );

      case PreviewMark.scanCode:
        canvas
          ..drawPath(
            Path()
              ..moveTo(3.5, 8)
              ..lineTo(3.5, 3.5)
              ..lineTo(8, 3.5)
              ..moveTo(16, 3.5)
              ..lineTo(20.5, 3.5)
              ..lineTo(20.5, 8)
              ..moveTo(20.5, 16)
              ..lineTo(20.5, 20.5)
              ..lineTo(16, 20.5)
              ..moveTo(8, 20.5)
              ..lineTo(3.5, 20.5)
              ..lineTo(3.5, 16),
            stroke,
          )
          ..drawRRect(box(8, 8, 3.6, 3.6, 0.8), fill)
          ..drawRRect(box(12.6, 8, 3.4, 3.4, 0.8), fill)
          ..drawRRect(box(8, 12.6, 3.4, 3.4, 0.8), fill)
          ..drawRRect(box(13.4, 13.4, 2.6, 2.6, 0.6), fill);

      case PreviewMark.soundWave:
        canvas.drawPath(
          Path()
            ..moveTo(4, 10.5)
            ..lineTo(4, 13.5)
            ..moveTo(8, 7)
            ..lineTo(8, 17)
            ..moveTo(12, 3.5)
            ..lineTo(12, 20.5)
            ..moveTo(16, 8)
            ..lineTo(16, 16)
            ..moveTo(20, 10.5)
            ..lineTo(20, 13.5),
          stroke,
        );

      case PreviewMark.alarmScreen:
        canvas
          ..drawRRect(box(6, 2.5, 12, 19, 3), stroke)
          ..drawCircle(const Offset(10.1, 8.6), 1.1, fill)
          ..drawCircle(const Offset(13.9, 8.6), 1.1, fill)
          ..drawPath(
            Path()
              ..moveTo(10, 16.6)
              ..lineTo(14, 16.6),
            stroke,
          );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}
