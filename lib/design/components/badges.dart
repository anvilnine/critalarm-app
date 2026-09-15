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
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaceWidget(
            state: faceState,
            size: 24,
            overrideFillColor: colors.yellow,
            overrideStrokeColor: colors.yellow,
            overrideInkColor: colors.inkFixed,
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
                color: colors.yellow,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
