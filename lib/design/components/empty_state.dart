import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Empty state container with dashed border and expressive face.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    this.title = 'No topics yet',
    this.description =
        'Create one, point a script at it, and this face will tell you '
        'when something breaks.',
    this.buttonLabel = 'Create a topic',
    this.onButtonPressed,
    this.faceState = FaceState.watching,
    this.isLive = true,
    super.key,
  });

  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final FaceState faceState;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CustomPaint(
      painter: _DashedRRectPainter(
        color: colors.canvasGhostStrong,
        strokeWidth: 2,
        dashLength: 8,
        gapLength: 6,
        radius: Radii.xl,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.s7,
          horizontal: Spacing.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaceWidget(
              state: faceState,
              isLive: isLive,
            ),
            const SizedBox(height: Spacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headline(colors.onCanvas, fontSize: 30),
              ),
            ),
            const SizedBox(height: Spacing.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.body(colors.onCanvasMuted),
              ),
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: Spacing.s5),
              AppButton(
                label: buttonLabel!,
                onPressed: onButtonPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
