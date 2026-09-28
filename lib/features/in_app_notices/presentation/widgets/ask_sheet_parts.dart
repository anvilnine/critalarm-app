import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// The centred display title the Pro sheet and the Reminders sheet share.
class AskSheetTitle extends StatelessWidget {
  const AskSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTypography.fontDisplay,
        fontFamilyFallback: AppTypography.fontDisplayFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 19,
        letterSpacing: -0.02 * 19,
        color: context.appColors.ink,
      ),
    );
  }
}

/// One checked line in a prompt sheet's list of what you get.
class AskSheetBullet extends StatelessWidget {
  const AskSheetBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppGlyph(
            GlyphType.check,
            size: 13,
            color: colors.cobalt,
            strokeWidth: 2.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
