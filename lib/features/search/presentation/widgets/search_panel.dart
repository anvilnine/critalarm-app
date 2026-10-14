import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/list_rows.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_docs_row.dart';
import 'package:critalarm/features/search/presentation/widgets/search_no_matches.dart';
import 'package:critalarm/features/search/presentation/widgets/search_recent_row.dart';
import 'package:critalarm/features/search/presentation/widgets/search_section_label.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The results, sitting directly above the search bar.
///
/// No card behind the panel as a whole: each section sits straight on the
/// blurred screen and grows upward from the bar as matches come in. The best
/// section is the one nearest the bar. Inside a section things read like any
/// other list, its title on top and its best match first under it.
///
/// Each section wears the look of the screen its results come from, so the
/// kind of thing is clear before the words are read:
/// - Topics: the face cards of the Topics list.
/// - History: the tick and bang rows of History, on a white sheet with
///   hairlines between them.
/// - Settings: the arrow rows of Settings, on a white sheet.
/// - Documentation: flat rows on a cream sheet with an arrow pointing out,
///   because they open in the browser.
///
/// It stops at [maxHeight], the full height of the display. The list runs edge
/// to edge: [bottomInset] keeps the nearest section clear of the bar and
/// [topInset] the farthest clear of the status bar, and past that the sections
/// scroll under both instead of being clipped short of them. With nothing to
/// show it takes no space at all, so the bar sits alone over the blurred
/// screen.
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

  /// Gap between the topic cards, matching the Topics list.
  static const double _rowGap = 10;

  /// Gap between one section and the next.
  static const double _sectionGap = Spacing.s4;

  /// The inner padding of the History, Settings and docs sheets.
  static const EdgeInsets _sheetPadding = EdgeInsets.all(6);

  final SearchState state;

  /// How tall it may get before the list starts scrolling. The shell works
  /// this out from what is left above the bar and the keyboard.
  final double maxHeight;

  final ValueChanged<SearchResult> onTapResult;
  final ValueChanged<String> onTapRecent;
  final VoidCallback onClearRecent;

  /// Called with one of the example queries on the no-results card.
  final ValueChanged<String> onTapExample;

  /// Room left above the farthest section once the list is long enough to
  /// reach the top, so it starts below the status bar and scrolls up under it.
  final double topInset;

  /// Room left below the nearest section for the search bar, and the keyboard
  /// when it is up. Sections scroll through it, under the bar.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final sections = _sections(context);
    if (sections.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // The panel floats over whichever screen is showing, so like the tab bar
      // it carries its own Material. Without one, Text falls back to the debug
      // style with underlines and the rows have nothing to draw ink on.
      child: Material(
        type: MaterialType.transparency,
        // The keyboard stays up while the user reads through the rows. It
        // goes away only when they drag the list down, towards it. The list
        // is reversed, so that drag scrolls it in the reverse direction.
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            return false;
          },
          // Reversed so the first section sits by the bar and the list opens
          // scrolled to it. Each section is one child drawn top to bottom, so
          // its title stays above its rows.
          child: ListView.separated(
            reverse: true,
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              Spacing.s1,
              topInset + Spacing.s2,
              Spacing.s1,
              bottomInset + Spacing.s1,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: _sectionGap),
            itemBuilder: (_, i) => sections[i],
          ),
        ),
      ),
    );
  }

  /// One widget per section, nearest the bar first.
  List<Widget> _sections(BuildContext context) {
    if (state.isBrowsing) {
      // Nothing typed and nothing searched before: show nothing rather than a
      // box explaining what search is. The bar's own hint already says it.
      if (state.recent.isEmpty) return const <Widget>[];

      return <Widget>[
        _Section(
          label: SearchSectionLabel(
            LocaleKeys.search_recent_header.tr(),
            action: LocaleKeys.search_recent_clear.tr(),
            onAction: onClearRecent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final query in state.recent)
                SearchRecentRow(query: query, onTap: () => onTapRecent(query)),
            ],
          ),
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
      for (final MapEntry(key: kind, value: results) in state.sections.entries)
        _Section(
          label: SearchSectionLabel(_sectionTitle(kind)),
          child: _body(context, kind, results),
        ),
    ];
  }

  Widget _body(
    BuildContext context,
    SearchResultKind kind,
    List<SearchResult> results,
  ) {
    return switch (kind) {
      SearchResultKind.topic => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < results.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: _rowGap),
            _topicRow(results[i]),
          ],
        ],
      ),
      SearchResultKind.history => AppSheet(
        padding: _sheetPadding,
        child: _hairlined(context, results, _historyRow),
      ),
      SearchResultKind.settings => AppSheet(
        padding: _sheetPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < results.length; i++) ...<Widget>[
              // Settings spaces its rows apart on the sheet, with no lines.
              if (i > 0) const SizedBox(height: Spacing.s2),
              _settingsRow(context, results[i]),
            ],
          ],
        ),
      ),
      SearchResultKind.docs => AppSheet(
        padding: _sheetPadding,
        color: context.appColors.cream,
        child: _hairlined(context, results, _docsRow),
      ),
    };
  }

  /// [results] drawn with [row], a hairline between each, as History does.
  static Widget _hairlined(
    BuildContext context,
    List<SearchResult> results,
    Widget Function(SearchResult) row,
  ) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < results.length; i++) ...<Widget>[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ColoredBox(
                color: colors.hairline,
                child: const SizedBox(height: 1),
              ),
            ),
          row(results[i]),
        ],
      ],
    );
  }

  /// A topic wears its face and its ringing state, the way the Topics list
  /// draws it.
  Widget _topicRow(SearchResult result) => AppListRow(
    name: result.title,
    meta: result.subtitle,
    faceState: result.faceState,
    isCrit: result.isCrit,
    isQuiet: result.isQuiet,
    onTap: () => onTapResult(result),
  );

  /// A past alarm is the History row, with the day where History puts the
  /// time, because the results have no day headings to sit under.
  Widget _historyRow(SearchResult result) {
    final mark = result.historyMark ?? HistoryMark.answered;
    return HistoryRow(
      name: result.title,
      meta: result.subtitle,
      time: result.timeText ?? '',
      mark: mark,
      markLabel: _markLabel(mark),
      onTap: () => onTapResult(result),
    );
  }

  /// A setting only opens another screen, so it gets no face and an arrow,
  /// matching the Settings screen. The grey line names the screen it is on.
  Widget _settingsRow(BuildContext context, SearchResult result) => AppListRow(
    name: result.title,
    meta: result.subtitle,
    faceState: null,
    trailing: AppGlyph(
      GlyphType.arrow,
      size: 16,
      color: context.appColors.ink3,
    ),
    onTap: () => onTapResult(result),
  );

  Widget _docsRow(SearchResult result) => SearchDocsRow(
    title: result.title,
    group: result.subtitle,
    onTap: () => onTapResult(result),
  );

  static String _markLabel(HistoryMark mark) => switch (mark) {
    HistoryMark.answered => LocaleKeys.history_hero_mark_answered.tr(),
    HistoryMark.notAnswered => LocaleKeys.history_hero_mark_not_answered.tr(),
    HistoryMark.ringing => LocaleKeys.history_hero_mark_ringing.tr(),
  };

  static String _sectionTitle(SearchResultKind kind) => switch (kind) {
    SearchResultKind.topic => LocaleKeys.search_section_topics.tr(),
    SearchResultKind.history => LocaleKeys.search_section_history.tr(),
    SearchResultKind.settings => LocaleKeys.search_section_settings.tr(),
    SearchResultKind.docs => LocaleKeys.search_section_docs.tr(),
  };
}

/// A section title with its rows under it.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final Widget label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[label, child],
    );
  }
}
