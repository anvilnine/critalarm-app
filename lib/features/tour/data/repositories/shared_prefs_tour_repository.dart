import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsTourRepository implements TourRepository {
  const SharedPrefsTourRepository(this._prefs);

  final SharedPreferences _prefs;

  /// The key the first version of the tour wrote. Kept, so a device that
  /// already sat through that one is not shown this one unasked.
  static const _key = 'has_completed_showcase_tour';

  @override
  bool hasSeenTour() => _prefs.getBool(_key) ?? false;

  @override
  Future<void> markTourSeen() => _prefs.setBool(_key, true);
}
