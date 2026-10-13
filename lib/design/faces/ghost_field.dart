import 'dart:math' as math;
import 'package:critalarm/design/faces/face_painter.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// How loud the watermark on the lock screen is. 0 is gone, 1 is a full face.
/// Low enough that the clock, the cards and the button read over it.
const double ghostWatermarkOpacity = 0.12;

/// The colours a watermark face is drawn in: the brand head, outline and
/// ink, the same as every other face. Only the opacity makes it quiet.
({Color head, Color outline, Color ink}) ghostWatermarkColors(
  AppColors colors,
) => (
  head: colors.faceFill,
  outline: colors.faceStroke,
  ink: colors.faceInk,
);

/// A big Crit face faded back to sit behind a screen. The head is brand
/// yellow with its dark outline and features, so it is still a face and
/// still yellow. The whole face is faded as one piece.
class GhostWatermarkFace extends StatelessWidget {
  const GhostWatermarkFace({
    required this.size,
    this.state = FaceState.alarmed,
    this.opacity = ghostWatermarkOpacity,
    super.key,
  });

  final double size;
  final FaceState state;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = ghostWatermarkColors(context.appColors);
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size.square(size),
        painter: FacePainter(
          state: state,
          fillColor: c.head,
          strokeColor: c.outline,
          inkColor: c.ink,
        ),
      ),
    );
  }
}

/// A big abstract shape from the ambient set (a ring and a pill) in the
/// page's own ghost colours, for a watermark that has no face.
class GhostWatermarkShape extends StatelessWidget {
  const GhostWatermarkShape({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CustomPaint(
      size: Size.square(size),
      painter: _GhostWatermarkShapePainter(
        fill: colors.canvasGhost,
        line: colors.canvasGhostStrong,
      ),
    );
  }
}

class _GhostWatermarkShapePainter extends CustomPainter {
  const _GhostWatermarkShapePainter({required this.fill, required this.line});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.shortestSide;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      extent / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = line,
    );
    final height = extent * 0.58 * 0.6;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-14.0 * math.pi / 180.0)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: extent * 0.84,
            height: height,
          ),
          Radius.circular(height / 2),
        ),
        Paint()..color = fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _GhostWatermarkShapePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.line != line;
}

/// Decorative background with floating ghost shapes (circles, rings,
/// tilted squares, dots, lock face).
class GhostField extends StatelessWidget {
  const GhostField({
    required this.child,
    this.showLockFace = false,
    this.lockFaceState = FaceState.alarmed,
    this.seed = 42,
    this.shapeCount = 6,
    this.opacity = 1,
    super.key,
  });

  final Widget child;
  final bool showLockFace;
  final FaceState lockFaceState;
  final int seed;
  final int shapeCount;

  /// Dials the shapes down. Below 1 they sit further back, so text over them
  /// keeps its contrast. Light mode needs this more than dark: its ghosts are
  /// drawn at 7% and 12% against 4.5% and 8% in dark.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      children: [
        // Background ghost canvas
        Positioned.fill(
          child: CustomPaint(
            painter: _GhostFieldPainter(
              ghostColor: colors.canvasGhost.withValues(
                alpha: colors.canvasGhost.a * opacity,
              ),
              ghostStrongColor: colors.canvasGhostStrong.withValues(
                alpha: colors.canvasGhostStrong.a * opacity,
              ),
              seed: seed,
              shapeCount: shapeCount,
            ),
          ),
        ),
        // Optional large lock-screen watermark face
        if (showLockFace)
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: Center(
              child: SizedBox(
                width: 380,
                height: 380,
                child: GhostWatermarkFace(
                  size: 380,
                  state: lockFaceState,
                ),
              ),
            ),
          ),
        // Foreground content
        child,
      ],
    );
  }
}

class _GhostFieldPainter extends CustomPainter {
  const _GhostFieldPainter({
    required this.ghostColor,
    required this.ghostStrongColor,
    required this.seed,
    required this.shapeCount,
  });

  final Color ghostColor;
  final Color ghostStrongColor;
  final int seed;
  final int shapeCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final random = math.Random(seed);
    final kinds = ['circle', 'ring', 'sq', 'dots'];

    for (var i = 0; i < shapeCount; i++) {
      final kind = kinds[i % kinds.length];
      final shapeSize = 60.0 + random.nextDouble() * 120.0;
      final x =
          random.nextDouble() * (size.width - shapeSize * 0.5) -
          shapeSize * 0.2;
      final y =
          random.nextDouble() * (size.height - shapeSize * 0.5) -
          shapeSize * 0.2;

      switch (kind) {
        case 'circle':
          final paint = Paint()
            ..style = PaintingStyle.fill
            ..color = ghostColor;
          canvas.drawCircle(
            Offset(x + shapeSize / 2, y + shapeSize / 2),
            shapeSize / 2,
            paint,
          );
        case 'ring':
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..color = ghostStrongColor;
          canvas.drawCircle(
            Offset(x + shapeSize / 2, y + shapeSize / 2),
            shapeSize / 2,
            paint,
          );
        case 'sq':
          final paint = Paint()
            ..style = PaintingStyle.fill
            ..color = ghostColor;
          canvas.save();
          canvas.translate(x + shapeSize / 2, y + shapeSize / 2);
          canvas.rotate(14.0 * math.pi / 180.0);
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: shapeSize,
            height: shapeSize,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(shapeSize * 0.24)),
            paint,
          );
          canvas.restore();
        case 'dots':
          final paint = Paint()
            ..style = PaintingStyle.fill
            ..color = ghostStrongColor;
          const dotSpacing = 16.0;
          const dotRadius = 1.5;
          final cols = (shapeSize / dotSpacing).floor();
          final rows = (shapeSize / dotSpacing).floor();
          for (var c = 0; c < cols; c++) {
            for (var r = 0; r < rows; r++) {
              canvas.drawCircle(
                Offset(x + c * dotSpacing, y + r * dotSpacing),
                dotRadius,
                paint,
              );
            }
          }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GhostFieldPainter oldDelegate) {
    return oldDelegate.ghostColor != ghostColor ||
        oldDelegate.ghostStrongColor != ghostStrongColor ||
        oldDelegate.seed != seed ||
        oldDelegate.shapeCount != shapeCount;
  }
}
