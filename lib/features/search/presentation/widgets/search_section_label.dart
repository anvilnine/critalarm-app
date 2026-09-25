import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The small label over each group of results.
class SearchSectionLabel extends StatelessWidget {
  const SearchSectionLabel(this.title, {this.action, this.onAction, super.key});

  static const double height = 30;

  final String title;

  /// An optional link on the right, used by Recent for its clear button.
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = action;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.s4, 0, Spacing.s4, 0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: colors.ink3,
                ),
              ),
            ),
            if (label != null)
              InkWell(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.s2,
                    vertical: Spacing.s1,
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: colors.highlight,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
