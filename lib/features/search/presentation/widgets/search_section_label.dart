import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The label over each group of results: the app's [AppSectionHeader], with an
/// optional link on the right that Recent uses for its clear button.
class SearchSectionLabel extends StatelessWidget {
  const SearchSectionLabel(this.title, {this.action, this.onAction, super.key});

  static const double height = 30;

  /// Lines up with the text inside a row, which sits 14 in from the row edge.
  static const EdgeInsets _inset = EdgeInsets.fromLTRB(
    Spacing.s4 + Spacing.s1,
    Spacing.s2,
    Spacing.s4,
    Spacing.s1,
  );

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = action;

    return ConstrainedBox(
      // A minimum, so the row grows with Dynamic Type instead of clipping.
      constraints: const BoxConstraints(minHeight: height),
      child: Row(
        children: <Widget>[
          Expanded(child: AppSectionHeader(title, padding: _inset)),
          if (label != null)
            InkWell(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s2,
                  vertical: Spacing.s1,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.highlight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
