import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// What the mascot says once the joke is over, as a small tag with a tail
/// pointing back at it. It is what keeps the joke readable on the resting
/// frame.
///
/// [entrance] is how far in it is, 0 to 1: it pops out from the mascot's
/// side. One draws it in place.
class FalseAlarmTag extends StatelessWidget {
  const FalseAlarmTag({
    required this.text,
    required this.isCompact,
    this.entrance = 1,
    super.key,
  });

  final String text;
  final bool isCompact;
  final double entrance;

  static const double _tail = 7;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pop = AppCurves.easeBack.transform(entrance.clamp(0, 1));

    return Opacity(
      opacity: (entrance * 3).clamp(0, 1),
      child: Transform.scale(
        scale: 0.6 + 0.4 * pop,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(_tail, 12),
              painter: _TailPainter(colors.onCanvas),
            ),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.onCanvas,
                  borderRadius: BorderRadius.circular(Spacing.s3),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.s3,
                    vertical: isCompact ? Spacing.s1 + 2 : Spacing.s2,
                  ),
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textWidthBasis: TextWidthBasis.longestLine,
                    style: AppTypography.small(
                      colors.canvas,
                      fontSize: isCompact ? 13 : 15,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // One point under the tag's edge, so no seam shows between them.
    final path = Path()
      ..moveTo(size.width + 1, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width + 1, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => color != old.color;
}
