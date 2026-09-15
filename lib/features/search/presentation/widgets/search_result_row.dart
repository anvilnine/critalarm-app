import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// One line in the search panel.
///
/// Deliberately not AppListRow: that draws a full width card with a face and
/// list padding, which stacks into a wall when a dozen of them sit inside a
/// floating panel. This is a flat row sized to be scanned.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onTap,
    this.isMono = true,
    super.key,
  });

  /// Row height, so the panel can work out how many fit before it scrolls.
  static const double height = 52;

  final String title;

  /// The grey line under the title. Empty draws nothing and the title centres.
  final String subtitle;

  final GlyphType glyph;
  final VoidCallback onTap;

  /// Topic names and settings rows are mono, matching the rest of the app.
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasSubtitle = subtitle.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: isMono
                            ? AppTypography.fontMono
                            : AppTypography.fontBody,
                        fontFamilyFallback: isMono
                            ? AppTypography.fontMonoFallbacks
                            : AppTypography.fontBodyFallbacks,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.2,
                        color: colors.onPanel,
                      ),
                    ),
                    if (hasSubtitle) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 12,
                          height: 1.2,
                          color: colors.onPanelMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s3),
              AppGlyph(glyph, color: colors.onPanelMuted),
            ],
          ),
        ),
      ),
    );
  }
}

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
                  color: colors.onPanelMuted,
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
