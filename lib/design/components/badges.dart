import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Pill badge with mini 24px face and text.
/// Example: "Rings through silent mode"
class AppBadge extends StatelessWidget {
  const AppBadge({
    this.text = 'Rings through silent mode',
    this.faceState = FaceState.calm,
    super.key,
  });

  final String text;
  final FaceState faceState;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? colors.yellow : colors.canvas;
    final faceFill = isDark ? colors.yellow : colors.canvas;
    final faceStroke = isDark ? colors.yellow : colors.canvas;
    final faceInk = isDark ? colors.inkFixed : colors.ink;

    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 6, right: 14),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaceWidget(
            state: faceState,
            size: 24,
            overrideFillColor: faceFill,
            overrideStrokeColor: faceStroke,
            overrideInkColor: faceInk,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
