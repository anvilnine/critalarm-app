import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/list_rows.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/search_layout.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_no_matches.dart';
import 'package:critalarm/features/search/presentation/widgets/search_recent_row.dart';
import 'package:critalarm/features/search/presentation/widgets/search_section_label.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The results, sitting directly above the search bar.
///
/// No card behind them: the rows sit straight on the blurred screen, grow
/// upward from the bar as matches come in, with the best match nearest the
/// bar, and stop at [maxHeight], the full
/// height of the display. The list itself runs edge to edge: [bottomInset]
/// keeps the last row clear of the bar and [topInset] the first row clear of
/// the status bar, and past that the rows scroll under both instead of being
/// clipped short of them. With nothing to show it takes no space at all, so
/// the bar sits alone over the blurred screen.
class SearchPanel extends StatelessWidget {
  const SearchPanel({
    required this.state,
    required this.maxHeight,
    required this.onTapResult,
    required this.onTapRecent,
    required this.onClearRecent,
    required this.onTapExample,
    this.topInset = 0,
    this.bottomInset = 0,
    super.key,
  });

  /// Gap between rows, matching the Topics and History lists.
  static const double _rowGap = 10;

  final SearchState state;

  /// How tall it may get before the list starts scrolling. The shell works
  /// this out from what is left above the bar and the keyboard.
  final double maxHeight;

  final ValueChanged<SearchResult> onTapResult;
  final ValueChanged<String> onTapRecent;
  final VoidCallback onClearRecent;

  /// Called with one of the example queries on the no-results card.
  final ValueChanged<String> onTapExample;

  /// Room left above the first row once the list is long enough to reach the
  /// top, so it starts below the status bar and scrolls up under it.
  final double topInset;

  /// Room left below the last row for the search bar, and the keyboard when
  /// it is up. Rows scroll through it, under the bar.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final children = _children(context);
    if (children.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // The panel floats over whichever screen is showing, so like the tab bar
      // it carries its own Material. Without one, Text falls back to the debug
      // style with underlines and the rows have nothing to draw ink on.
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            Spacing.s1,
            topInset + Spacing.s2,
            Spacing.s1,
            bottomInset + Spacing.s1,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
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
        for (final query in state.recent)
          SearchRecentRow(query: query, onTap: () => onTapRecent(query)),
        SearchSectionLabel(
          LocaleKeys.search_recent_header.tr(),
          action: LocaleKeys.search_recent_clear.tr(),
          onAction: onClearRecent,
        ),
      ];
    }

    if (state.hasNoMatches) {
      return <Widget>[
        SearchNoMatches(
          query: state.query.trim(),
          onTapExample: onTapExample,
        ),
      ];
    }

    return <Widget>[
      for (final entry in nearestFirstEntries(state.sections))
        switch (entry) {
          SearchHeaderEntry(:final kind) => SearchSectionLabel(
            _sectionTitle(kind),
          ),
          SearchRowEntry(:final result) => Padding(
            padding: const EdgeInsets.only(bottom: _rowGap),
            child: _row(context, result),
          ),
        },
    ];
  }

  /// Draws a result with the row its own screen uses.
  ///
  /// A topic wears its face and its ringing state, the way the Topics list
  /// draws it. A past alarm carries the same sentence, with the day where
  /// History puts the time. Settings and documentation only open something
  /// else, so they get no face and an arrow, matching the Settings screen.
  Widget _row(BuildContext context, SearchResult result) {
    void open() => onTapResult(result);

    return switch (result.kind) {
      SearchResultKind.topic => AppListRow(
        name: result.title,
        meta: result.subtitle,
        faceState: result.faceState,
        isCrit: result.isCrit,
        isQuiet: result.isQuiet,
        onTap: open,
      ),
      SearchResultKind.history => AppListRow(
        name: result.title,
        meta: result.subtitle,
        faceState: result.faceState,
        timeText: result.timeText,
        onTap: open,
      ),
      SearchResultKind.settings || SearchResultKind.docs => AppListRow(
        name: result.title,
        meta: result.subtitle,
        faceState: null,
        trailing: _trailingGlyph(context, GlyphType.arrow),
        onTap: open,
      ),
    };
  }

  static Widget _trailingGlyph(BuildContext context, GlyphType glyph) {
    return AppGlyph(glyph, size: 16, color: context.appColors.ink3);
  }

  static String _sectionTitle(SearchResultKind kind) => switch (kind) {
    SearchResultKind.topic => LocaleKeys.search_section_topics.tr(),
    SearchResultKind.history => LocaleKeys.search_section_history.tr(),
    SearchResultKind.settings => LocaleKeys.search_section_settings.tr(),
    SearchResultKind.docs => LocaleKeys.search_section_docs.tr(),
  };
}
