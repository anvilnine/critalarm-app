import 'dart:math' as math;
import 'package:critalarm/design/faces/face_painter.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Decorative background with floating ghost shapes (circles, rings,
/// tilted squares, dots, lock face).
class GhostField extends StatelessWidget {
  const GhostField({
    required this.child,
    this.showLockFace = false,
    this.lockFaceState = FaceState.alarmed,
    this.seed = 42,
    this.shapeCount = 6,
    super.key,
  });

  final Widget child;
  final bool showLockFace;
  final FaceState lockFaceState;
  final int seed;
  final int shapeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      children: [
        // Background ghost canvas
        Positioned.fill(
          child: CustomPaint(
            painter: _GhostFieldPainter(
              ghostColor: colors.canvasGhost,
              ghostStrongColor: colors.canvasGhostStrong,
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
                child: CustomPaint(
                  painter: FacePainter(
                    state: lockFaceState,
                    fillColor: Colors.transparent,
                    strokeColor: colors.canvasGhostStrong,
                    inkColor: colors.canvasGhostStrong,
                  ),
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
