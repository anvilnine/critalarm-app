import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches in SharedPreferences, newest first.
class SharedPrefsRecentSearchesRepository implements RecentSearchesRepository {
  const SharedPrefsRecentSearchesRepository(this._prefs);

  static const String _key = 'search_recent_queries';

  /// How many to keep. Enough to be useful, short enough to fit above the
  /// keyboard without scrolling.
  static const int max = 8;

  final SharedPreferences _prefs;

  List<String> get _stored => _prefs.getStringList(_key) ?? const <String>[];

  @override
  Future<AppResult<List<String>>> getRecent() async => _stored.toSuccess();

  @override
  Future<AppResult<List<String>>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return _stored.toSuccess();

    // Same words typed with different capitals are the same search, and the
    // newest spelling is the one worth keeping.
    final lower = trimmed.toLowerCase();
    final next = <String>[trimmed];
    for (final existing in _stored) {
      if (next.length >= max) break;
      if (existing.toLowerCase() == lower) continue;
      next.add(existing);
    }

    final saved = await _prefs.setStringList(_key, next);
    if (!saved) {
      return Failure.unexpected(
        message: LocaleKeys.storage_errors_save_recent_searches.tr(),
      ).toFailure<List<String>>();
    }
    return next.toSuccess();
  }

  @override
  Future<AppResult<Unit>> clear() async {
    await _prefs.remove(_key);
    return unit.toSuccess();
  }
}
