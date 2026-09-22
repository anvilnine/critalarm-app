import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// One large round play button. While playing it shows a stop square.
///
/// The labels come in from the screen, so the component knows no strings.
class AppTransportButton extends StatelessWidget {
  const AppTransportButton({
    required this.isPlaying,
    required this.onPressed,
    required this.playLabel,
    required this.stopLabel,
    super.key,
  });

  static const size = 72.0;

  final bool isPlaying;
  final VoidCallback? onPressed;
  final String playLabel;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: isPlaying ? stopLabel : playLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : .5,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.highlight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isPlaying
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.onHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : CustomPaint(
                    size: const Size.square(size),
                    painter: _TrianglePainter(colors.onHighlight),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Nudged right, so the triangle looks centred rather than measures it.
    final cx = size.width / 2 + 1.5;
    final cy = size.height / 2;
    final s = size.width * 0.18;
    final path = Path()
      ..moveTo(cx - s, cy - s * 1.15)
      ..lineTo(cx + s * 1.1, cy)
      ..lineTo(cx - s, cy + s * 1.15)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
