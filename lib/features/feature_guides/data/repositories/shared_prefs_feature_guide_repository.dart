import 'package:critalarm/features/feature_guides/domain/repositories/feature_guide_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsFeatureGuideRepository implements FeatureGuideRepository {
  const SharedPrefsFeatureGuideRepository(this._prefs);

  final SharedPreferences _prefs;

  /// The key the one long tour wrote. Kept, so a device that already sat
  /// through that is not shown the per-screen guides unasked.
  static const _legacyKey = 'has_completed_showcase_tour';

  /// The guides seen so far, by name.
  static const _key = 'tour_guides_seen';

  @override
  bool hasSeenGuide(String guide) =>
      (_prefs.getBool(_legacyKey) ?? false) ||
      (_prefs.getStringList(_key)?.contains(guide) ?? false);

  @override
  Future<void> markGuidesSeen(Iterable<String> guides) {
    final seen = {...?_prefs.getStringList(_key), ...guides};
    return _prefs.setStringList(_key, seen.toList()..sort());
  }
}
