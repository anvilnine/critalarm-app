import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Message card for topic detail views matching index.html .msg.
class AppMessageCard extends StatelessWidget {
  const AppMessageCard({
    required this.title,
    required this.timestamp,
    required this.body,
    required this.source,
    this.isHigh = false,
    super.key,
  });

  final String title;
  final String timestamp;
  final String body;
  final String source;
  final bool isHigh;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = isHigh ? colors.surface : colors.cream;
    final border = isHigh ? Border.all(color: colors.high, width: 2) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.mdAll,
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01 * 15,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timestamp,
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontFamilyFallback: AppTypography.fontMonoFallbacks,
                  fontSize: 12,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            source,
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontSize: 11,
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
