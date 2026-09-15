import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_result_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The results, sitting directly above the search bar.
///
/// It grows upward from the bar as matches come in and stops at [maxHeight],
/// after which it scrolls. With nothing to show it takes no space at all, so
/// the bar sits alone over the blurred screen.
class SearchPanel extends StatelessWidget {
  const SearchPanel({
    required this.state,
    required this.maxHeight,
    required this.onTapResult,
    required this.onTapRecent,
    required this.onClearRecent,
    super.key,
  });

  final SearchState state;

  /// How tall it may get before the list starts scrolling. The shell works
  /// this out from what is left above the bar and the keyboard.
  final double maxHeight;

  final ValueChanged<SearchResult> onTapResult;
  final ValueChanged<String> onTapRecent;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final children = _children(context);
    if (children.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // The panel floats over whichever screen is showing, so like the tab bar
      // it carries its own Material. Without one, Text falls back to the debug
      // style with underlines and the rows have nothing to draw ink on.
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: Radii.lgAll,
            border: Border.all(color: colors.panelLine),
            boxShadow: AppShadows.shadowLg(isDark: isDark),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Spacing.s2),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    if (state.isBrowsing) {
      // Nothing typed and nothing searched before: show nothing rather than a
      // box explaining what search is. The bar's own hint already says it.
      if (state.recent.isEmpty) return const <Widget>[];

      return <Widget>[
        SearchSectionLabel(
          LocaleKeys.search_recent_header.tr(),
          action: LocaleKeys.search_recent_clear.tr(),
          onAction: onClearRecent,
        ),
        for (final query in state.recent)
          SearchResultRow(
            title: query,
            subtitle: '',
            glyph: GlyphType.clock,
            isMono: false,
            onTap: () => onTapRecent(query),
          ),
      ];
    }

    if (state.hasNoMatches) {
      return <Widget>[
        _NoMatches(query: state.query.trim()),
      ];
    }

    final children = <Widget>[];
    state.sections.forEach((kind, results) {
      children.add(SearchSectionLabel(_sectionTitle(kind)));
      for (var i = 0; i < results.length; i++) {
        if (i > 0) children.add(const _RowDivider());
        final result = results[i];
        children.add(
          SearchResultRow(
            title: result.title,
            subtitle: result.subtitle,
            glyph: result.opensExternally ? GlyphType.arrow : GlyphType.chevron,
            isMono: kind != SearchResultKind.docs,
            onTap: () => onTapResult(result),
          ),
        );
      }
    });
    return children;
  }

  static String _sectionTitle(SearchResultKind kind) => switch (kind) {
    SearchResultKind.topic => LocaleKeys.search_section_topics.tr(),
    SearchResultKind.history => LocaleKeys.search_section_history.tr(),
    SearchResultKind.settings => LocaleKeys.search_section_settings.tr(),
    SearchResultKind.docs => LocaleKeys.search_section_docs.tr(),
  };
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.s4),
      child: Container(height: 1, color: context.appColors.panelLine),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.s4,
        Spacing.s3,
        Spacing.s4,
        Spacing.s3,
      ),
      child: Text(
        LocaleKeys.search_no_matches_title.tr(
          namedArgs: <String, String>{'query': query},
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 14,
          color: colors.onPanelMuted,
        ),
      ),
    );
  }
}
