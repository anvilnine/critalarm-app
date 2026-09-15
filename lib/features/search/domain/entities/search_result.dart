import 'package:flutter/foundation.dart';

/// What a result points at. Also the section it is drawn under.
enum SearchResultKind { topic, history, settings, docs }

/// One thing the user can find. Built in the cubit from topics, past alarms,
/// the settings index and the documentation index, then ranked as one list.
@immutable
class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.keywords = const <String>[],
    this.routePath,
    this.externalUrl,
    this.date,
  });

  final SearchResultKind kind;

  /// Unique within its kind. Used for list keys and for dedupe.
  final String id;

  final String title;

  /// The grey line under the title. Empty draws nothing.
  final String subtitle;

  /// Extra words that should match but are never shown, such as "dark mode"
  /// on the theme row. Lowercase them when building.
  final List<String> keywords;

  /// Where tapping goes inside the app. Null for a result that leaves the app.
  final String? routePath;

  /// Where tapping goes outside the app. Only documentation sets this.
  final String? externalUrl;

  /// The day this result belongs to, so a query that reads as a date can match
  /// it. Only past alarms set this.
  final DateTime? date;

  bool get opensExternally => externalUrl != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          id == other.id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'SearchResult(${kind.name}:$id)';
}
