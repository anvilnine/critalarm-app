import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:flutter/material.dart';

/// The small tag on the stage that says which side of the moment the
/// preview is on: Free, or the product. Both names are always there, and
/// the one that is true is the filled one. After the lift, Free is struck
/// through, so a still frame reads as "was Free, now this".
///
/// It is ink on the canvas colour and never the accent. [frame] is which
/// side is up and how far through a flip it is. [entrance] pops it in,
/// 0 to 1.
class ProofTag extends StatelessWidget {
  const ProofTag({
    required this.free,
    required this.product,
    required this.frame,
    required this.isCompact,
    this.entrance = 1,
    this.swell = 1,
    super.key,
  });

  final String free;
  final String product;
  final ProofTagFrame frame;
  final bool isCompact;
  final double entrance;

  /// How large against its own size, for the pop at the lift. It rests
  /// at 1.
  final double swell;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pop = AppCurves.easeBack.transform(entrance.clamp(0, 1));

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Opacity(
        opacity: (entrance * 3).clamp(0, 1),
        child: Transform(
          alignment: Alignment.center,
          // The flip closes the tag to an edge and opens it again. It is
          // never thinner than a line, and it rests flat.
          transform: Matrix4.diagonal3Values(
            (0.7 + 0.3 * pop) * swell,
            (0.7 + 0.3 * pop) * swell * (0.06 + 0.94 * frame.flat),
            1,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.canvas,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: colors.onCanvas, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Side(
                    text: free,
                    isOn: !frame.isLifted,
                    isStruck: frame.isLifted,
                    isCompact: isCompact,
                  ),
                  _Side(
                    text: product,
                    isOn: frame.isLifted,
                    isStruck: false,
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.text,
    required this.isOn,
    required this.isStruck,
    required this.isCompact,
  });

  final String text;
  final bool isOn;
  final bool isStruck;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = isOn ? colors.canvas : colors.onCanvasMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOn ? colors.onCanvas : null,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? Spacing.s2 + 1 : Spacing.s3 - 2,
          vertical: isCompact ? 2 : 3,
        ),
        child: Text(
          text,
          maxLines: 1,
          style: AppTypography.small(ink, fontSize: isCompact ? 12 : 13)
              .copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
                decoration: isStruck ? TextDecoration.lineThrough : null,
                decorationColor: ink,
                decorationThickness: 2,
              ),
        ),
      ),
    );
  }
}
