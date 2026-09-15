import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';

/// Scores and orders search results.
///
/// Pure functions on purpose: every rule here is unit tested without a cubit,
/// a clock or a widget, the same way HistoryCubit.toEntries is.
abstract final class SearchRanking {
  /// The whole title is the query. "prod-db" typed in full.
  static const int exactTitle = 1000;

  /// The title starts with the query. "prod" finds "prod-db".
  static const int titlePrefix = 600;

  /// A word inside the title starts with the query. "db" finds "prod-db".
  static const int titleWordStart = 420;

  /// The query appears anywhere in the title.
  static const int titleContains = 260;

  /// The query appears in the grey line under the title.
  static const int subtitleContains = 140;

  /// The query appears in a hidden keyword, such as "dark mode" on the theme
  /// row. Counted once however many keywords hit.
  static const int keywordMatch = 110;

  /// The query reads as a date and this result happened on that day.
  static const int dateMatch = 700;

  /// This result is the kind the user was already looking at.
  static const int scopeBonus = 150;

  /// How well [result] answers [query]. Zero means it does not, and a zero
  /// scoring result is never shown.
  static int score(
    SearchResult result, {
    required String query,
    SearchScope? scope,
    DateTime? queryDate,
  }) {
    var total = 0;

    final date = result.date;
    if (queryDate != null && date != null) {
      if (date.year == queryDate.year &&
          date.month == queryDate.month &&
          date.day == queryDate.day) {
        total += dateMatch;
      }
    }

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final title = result.title.toLowerCase();
      if (title == q) {
        total += exactTitle;
      } else if (title.startsWith(q)) {
        total += titlePrefix;
      } else if (_hasWordStartingWith(title, q)) {
        total += titleWordStart;
      } else if (title.contains(q)) {
        total += titleContains;
      }

      if (result.subtitle.toLowerCase().contains(q)) {
        total += subtitleContains;
      }

      for (final keyword in result.keywords) {
        if (keyword.contains(q)) {
          total += keywordMatch;
          break;
        }
      }
    }

    // Nothing matched, so the scope bonus has nothing to lift. Without this a
    // scoped result would score 150 on an empty match and show up as a hit.
    if (total == 0) return 0;

    if (scope != null && kindForScope(scope) == result.kind) {
      total += scopeBonus;
    }
    return total;
  }

  /// [results] that match, best first. Ties keep the order they came in, which
  /// is the order the cubit builds them: topics, past alarms, settings, docs.
  static List<SearchResult> rank(
    List<SearchResult> results, {
    required String query,
    SearchScope? scope,
    DateTime? queryDate,
  }) {
    final scored = <_Scored>[];
    for (var i = 0; i < results.length; i++) {
      final value = score(
        results[i],
        query: query,
        scope: scope,
        queryDate: queryDate,
      );
      if (value > 0) {
        scored.add(_Scored(results[i], value, i));
      }
    }

    // List.sort is not stable, so the original index is part of the comparison
    // rather than something the sort is trusted to preserve.
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });

    return <SearchResult>[for (final entry in scored) entry.result];
  }

  /// Splits ranked results into sections, keeping both the order inside a
  /// section and the order of the sections themselves. The section holding the
  /// best result comes first.
  static Map<SearchResultKind, List<SearchResult>> section(
    List<SearchResult> ranked,
  ) {
    final sections = <SearchResultKind, List<SearchResult>>{};
    for (final result in ranked) {
      sections.putIfAbsent(result.kind, () => <SearchResult>[]).add(result);
    }
    return sections;
  }

  /// The result kind that belongs to the screen search was opened from.
  static SearchResultKind kindForScope(SearchScope scope) => switch (scope) {
    SearchScope.topics => SearchResultKind.topic,
    SearchScope.history => SearchResultKind.history,
    SearchScope.settings => SearchResultKind.settings,
  };

  /// True when any word in [text] starts with [query]. Words break on anything
  /// that is not a letter or a digit, so "prod-db" holds "prod" and "db".
  static bool _hasWordStartingWith(String text, String query) {
    var atWordStart = true;
    for (var i = 0; i < text.length; i++) {
      if (atWordStart && text.startsWith(query, i)) return true;
      atWordStart = !_isWordChar(text.codeUnitAt(i));
    }
    return false;
  }

  static bool _isWordChar(int code) {
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLower = code >= 0x61 && code <= 0x7A;
    final isUpper = code >= 0x41 && code <= 0x5A;
    return isDigit || isLower || isUpper;
  }
}

class _Scored {
  const _Scored(this.result, this.score, this.index);

  final SearchResult result;
  final int score;
  final int index;
}
