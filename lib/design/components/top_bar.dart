import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Top bar matching index.html .phone .bar.
/// Displays leading button (e.g. back), title text, spacer, and trailing widget (e.g. settings/action/chip).
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    this.title,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 0),
    super.key,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            if (title != null) const SizedBox(width: 12),
          ],
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontFamily: AppTypography.fontDisplay,
                fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.02 * 18,
                color: colors.onCanvas,
              ),
            ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
