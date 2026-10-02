import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:flutter/foundation.dart';

/// One line in the results list: a section header or a result row.
@immutable
sealed class SearchEntry {
  const SearchEntry();
}

class SearchHeaderEntry extends SearchEntry {
  const SearchHeaderEntry(this.kind);

  final SearchResultKind kind;

  @override
  bool operator ==(Object other) =>
      other is SearchHeaderEntry && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

class SearchRowEntry extends SearchEntry {
  const SearchRowEntry(this.result);

  final SearchResult result;

  @override
  bool operator ==(Object other) =>
      other is SearchRowEntry && other.result == result;

  @override
  int get hashCode => result.hashCode;
}

/// Orders [sections] for a list that grows upward from the search bar.
///
/// The first entry is drawn nearest the bar, so the best match is the closest
/// thing to the thumb. A section's header comes after its rows, which puts it
/// above them on screen. Sections and the rows inside them keep their ranked
/// order, best first.
List<SearchEntry> nearestFirstEntries(
  Map<SearchResultKind, List<SearchResult>> sections,
) {
  final entries = <SearchEntry>[];
  sections.forEach((kind, results) {
    for (final result in results) {
      entries.add(SearchRowEntry(result));
    }
    entries.add(SearchHeaderEntry(kind));
  });
  return entries;
}
