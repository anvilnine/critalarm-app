import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// One past search in the panel.
///
/// Not AppListRow: that row is built for a thing with a name and a line about
/// how it is doing, and reserves the space for both. A past search is one line
/// of text the user typed, so it gets one line.
class SearchRecentRow extends StatelessWidget {
  const SearchRecentRow({
    required this.query,
    required this.onTap,
    super.key,
  });

  static const double height = 44;

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        // A minimum, so the row grows with Dynamic Type instead of clipping.
        constraints: const BoxConstraints(minHeight: height),
        child: Padding(
          // Lines up with the section label above it.
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 15,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.s3),
              AppGlyph(
                GlyphType.clock,
                size: 15,
                color: colors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
