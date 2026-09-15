import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';
import 'package:flutter/foundation.dart';

enum SearchStatus { initial, loading, ready, failure }

@immutable
class SearchState {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.scope,
    this.results = const <SearchResult>[],
    this.recent = const <String>[],
    this.errorMessage,
  });

  final SearchStatus status;

  /// Exactly what the user typed, including spaces and capitals.
  final String query;

  /// The screen search was opened from. Null when it was opened from nowhere in
  /// particular, and then nothing gets a scope bonus.
  final SearchScope? scope;

  /// Matches for [query], best first. Empty while browsing.
  final List<SearchResult> results;

  final List<String> recent;

  final String? errorMessage;

  bool get isLoading => status == SearchStatus.loading;

  /// Nothing typed yet, so the screen shows recent searches instead of results.
  bool get isBrowsing => query.trim().isEmpty;

  /// Something was typed and nothing matched it.
  bool get hasNoMatches =>
      status == SearchStatus.ready && !isBrowsing && results.isEmpty;

  /// Results grouped into the sections they are drawn under, in the order the
  /// sections should appear.
  Map<SearchResultKind, List<SearchResult>> get sections {
    final grouped = <SearchResultKind, List<SearchResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.kind, () => <SearchResult>[]).add(result);
    }
    return grouped;
  }

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchScope? scope,
    List<SearchResult>? results,
    List<String>? recent,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      scope: scope ?? this.scope,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
