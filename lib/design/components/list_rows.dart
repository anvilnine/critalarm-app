import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// List row item for topics or incident history.
/// Supports normal, critical takeover (dark card), and quiet styles.
class AppListRow extends StatefulWidget {
  const AppListRow({
    required this.name,
    required this.meta,
    this.faceState = FaceState.calm,
    this.faceStrokeColor,
    this.trailing,
    this.timeText,
    this.isCrit = false,
    this.isQuiet = false,
    this.onTap,
    super.key,
  });

  final String name;
  final String meta;
  final FaceState faceState;
  final Color? faceStrokeColor;
  final Widget? trailing;
  final String? timeText;
  final bool isCrit;
  final bool isQuiet;
  final VoidCallback? onTap;

  @override
  State<AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<AppListRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color bg;
    final Color nameColor;
    final Color metaColor;
    final Color faceFill;
    final Color faceStroke;
    final Color faceInk;
    final List<BoxShadow> shadows;

    if (widget.isCrit) {
      bg = colors.panel;
      nameColor = colors.onPanel;
      metaColor = colors.onPanelMuted;
      faceFill = colors.panel;
      faceStroke = colors.crit;
      faceInk = colors.onPanel;
      shadows = AppShadows.lightMd;
    } else if (widget.isQuiet) {
      bg = colors.ash;
      nameColor = colors.ink;
      metaColor = colors.ink3;
      faceFill = colors.canvas;
      faceStroke = widget.faceStrokeColor ?? colors.faceStroke;
      faceInk = colors.faceInk;
      shadows = const [];
    } else {
      bg = colors.surface;
      nameColor = colors.ink;
      metaColor = colors.ink3;
      faceFill = colors.canvas;
      faceStroke =
          widget.faceStrokeColor ??
          (widget.faceState == FaceState.worried
              ? colors.high
              : colors.faceStroke);
      faceInk = colors.faceInk;
      shadows = _isHovered ? AppShadows.lightMd : const [];
    }

    final translateY = (_isHovered && !widget.isQuiet) ? -1.0 : 0.0;
    final scale = _isPressed ? 0.98 : 1.0;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: AppDurations.quick,
          curve: AppCurves.easeSpring,
          offset: Offset(0, translateY / 40.0),
          child: AnimatedScale(
            duration: AppDurations.quick,
            curve: AppCurves.easeSpring,
            scale: scale,
            child: AnimatedContainer(
              duration: AppDurations.quick,
              curve: AppCurves.easeSpring,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: Radii.mdAll,
                boxShadow: shadows,
              ),
              child: Row(
                children: [
                  FaceWidget(
                    state: widget.faceState,
                    size: 40,
                    overrideFillColor: faceFill,
                    overrideStrokeColor: faceStroke,
                    overrideInkColor: faceInk,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontFamilyFallback: AppTypography.fontMonoFallbacks,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: nameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.meta,
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontFamilyFallback: AppTypography.fontBodyFallbacks,
                            fontSize: 12,
                            color: metaColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: widget.trailing!,
                    ),
                  ],
                  if (widget.timeText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.timeText!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontSize: 12,
                        color: metaColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
