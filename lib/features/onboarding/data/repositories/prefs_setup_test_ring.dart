import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SetupTestRing] on the phone, under `onboarding_real_ring_incident`.
class PrefsSetupTestRing implements SetupTestRing {
  PrefsSetupTestRing(this._prefs);

  final SharedPreferences _prefs;

  static const incidentIdKey = 'onboarding_real_ring_incident';

  @override
  String? get incidentId {
    final id = _prefs.getString(incidentIdKey);
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<void> hold(String incidentId) async {
    await _prefs.setString(incidentIdKey, incidentId);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(incidentIdKey);
  }
}
