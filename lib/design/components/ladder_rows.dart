import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Priority ladder row matching index.html .ladder > div.
class AppLadderRow extends StatelessWidget {
  const AppLadderRow({
    required this.priority,
    required this.description,
    required this.faceState,
    this.faceStrokeColor,
    this.isCrit = false,
    super.key,
  });

  final PriorityLevel priority;
  final String description;
  final FaceState faceState;
  final Color? faceStrokeColor;
  final bool isCrit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = isCrit ? colors.panel : colors.surface;
    final fg = isCrit ? colors.onPanel : colors.ink;
    final radius = isCrit ? Radii.lgAll : Radii.mdAll;
    final padding = isCrit
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    final shadows = isCrit ? AppShadows.lightMd : null;
    final faceSize = isCrit ? 48.0 : 36.0;

    final faceFill = isCrit ? colors.panel : colors.canvas;
    final faceStroke =
        faceStrokeColor ??
        (isCrit
            ? colors.crit
            : (faceState == FaceState.worried
                  ? colors.high
                  : colors.faceStroke));
    final faceInk = isCrit ? colors.onPanel : colors.faceInk;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppPriorityChip(priority: priority),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: isCrit ? 16 : 14,
                fontWeight: isCrit ? FontWeight.w500 : FontWeight.w400,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 16),
          FaceWidget(
            state: faceState,
            size: faceSize,
            overrideFillColor: faceFill,
            overrideStrokeColor: faceStroke,
            overrideInkColor: faceInk,
          ),
        ],
      ),
    );
  }
}
