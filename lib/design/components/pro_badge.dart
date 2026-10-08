import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A small yellow pill that names a plan: "Hosted" or "Pro".
///
/// The one badge in the app. With [isLocked] it carries a lock glyph before
/// the word and marks something the plan would unlock. Without it, it says
/// the thing belongs to that plan.
class ProBadge extends StatelessWidget {
  const ProBadge({required this.label, this.isLocked = false, super.key});

  /// The word on the pill, already translated.
  final String label;

  /// Draws the lock glyph before the word.
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final word = Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.2,
        color: colors.inkFixed,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.yellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.inkFixed, width: 1.5),
      ),
      child: isLocked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppGlyph(
                  GlyphType.lock,
                  size: 11,
                  strokeWidth: 3,
                  color: colors.inkFixed,
                ),
                const SizedBox(width: 4),
                word,
              ],
            )
          : word,
    );
  }
}
