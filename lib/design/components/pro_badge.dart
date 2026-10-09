import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A small yellow pill that names a plan: "Hosted" or "Pro".
///
/// The one badge in the app. With [isLocked] it carries a lock glyph before
/// the word and marks something the plan would unlock. Without it, it says
/// the thing belongs to that plan.
///
/// [fill], [ink] and [border] set the colours for a ground where the yellow
/// pill would not stand out (a pass card). [isCompact] draws the smaller pill
/// that sits on a label line, with its lock and word scaled by the text size.
class ProBadge extends StatelessWidget {
  const ProBadge({
    required this.label,
    this.isLocked = false,
    this.fill,
    this.ink,
    this.border,
    this.isCompact = false,
    super.key,
  });

  /// The word on the pill, already translated.
  final String label;

  /// Draws the lock glyph before the word.
  final bool isLocked;

  /// The pill's colour. Null is the yellow.
  final Color? fill;

  /// The word and the lock. Null is the fixed ink.
  final Color? ink;

  /// The pill's outline. Null is the fixed ink.
  final Color? border;

  /// The smaller pill for a mono label line.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final inkColor = ink ?? colors.inkFixed;
    final fontSize = isCompact ? 10.0 : 11.0;
    final glyphSize = isCompact
        ? MediaQuery.textScalerOf(context).scale(10)
        : 11.0;
    final word = Text(
      label.toUpperCase(),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.2,
        color: inkColor,
      ),
    );
    return Container(
      padding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill ?? colors.yellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? colors.inkFixed, width: 1.5),
      ),
      child: isLocked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppGlyph(
                  GlyphType.lock,
                  size: glyphSize,
                  strokeWidth: 3,
                  color: inkColor,
                ),
                SizedBox(width: isCompact ? 3 : 4),
                word,
              ],
            )
          : word,
    );
  }
}
