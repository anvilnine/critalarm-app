import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Notification card for lock screen and preview displays
/// matching index.html .notif.
class AppNotificationCard extends StatelessWidget {
  const AppNotificationCard({
    required this.topic,
    required this.title,
    required this.body,
    this.faceState = FaceState.calm,
    this.timeText,
    this.ringingPillText,
    this.isCrit = false,
    this.isQuiet = false,
    this.onTap,
    super.key,
  });

  final String topic;
  final String title;
  final String body;
  final FaceState faceState;
  final String? timeText;
  final String? ringingPillText;
  final bool isCrit;
  final bool isQuiet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color bg;
    Border? border;
    List<BoxShadow> shadows;

    if (isCrit) {
      bg = colors.surface;
      border = Border.all(color: colors.ink, width: 2.5);
      shadows = AppShadows.lightLg;
    } else if (isQuiet) {
      bg = colors.cream;
      border = null;
      shadows = [];
    } else {
      bg = colors.surface;
      border = null;
      shadows = AppShadows.lightMd;
    }

    final faceStroke = isCrit ? colors.crit : colors.faceStroke;
    final faceFill = colors.surface;
    final faceInk = colors.ink;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.lgAll,
        border: border,
        boxShadow: shadows,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaceWidget(
            state: isCrit ? FaceState.alarmed : faceState,
            size: 44,
            overrideFillColor: faceFill,
            overrideStrokeColor: faceStroke,
            overrideInkColor: faceInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Crit Alarm',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        topic,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTypography.fontMono,
                          fontFamilyFallback: AppTypography.fontMonoFallbacks,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01 * 16,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 13,
                    color: colors.ink2,
                    height: 1.35,
                  ),
                ),
                if (ringingPillText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.crit,
                      borderRadius: Radii.fullAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppGlyph(
                          GlyphType.bell,
                          size: 12,
                          color: colors.inkFixed,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ringingPillText!,
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.inkFixed,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (timeText != null) ...[
            const SizedBox(width: 8),
            Text(
              timeText!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontSize: 12,
                color: colors.ink3,
              ),
            ),
          ],
        ],
      ),
    );

    final content = isQuiet ? Opacity(opacity: 0.9, child: card) : card;
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
