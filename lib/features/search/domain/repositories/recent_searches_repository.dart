import 'package:critalarm/core/result/result.dart';

/// The last few things the user searched for, newest first.
abstract interface class RecentSearchesRepository {
  Future<AppResult<List<String>>> getRecent();

  /// Adds [query] to the front and returns the new list. A query already in
  /// the list moves to the front instead of appearing twice.
  Future<AppResult<List<String>>> add(String query);

  Future<AppResult<Unit>> clear();
}
