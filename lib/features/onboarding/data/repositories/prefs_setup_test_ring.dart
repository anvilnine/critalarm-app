import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SetupTestRing] on the phone: the newest id under
/// `onboarding_real_ring_incident`, every id of the run under
/// `onboarding_real_ring_incidents`, the ones still to close under
/// `onboarding_real_ring_unclosed`, and the alarm of the first hook-up
/// message under `onboarding_first_tool_incident`.
class PrefsSetupTestRing implements SetupTestRing {
  PrefsSetupTestRing(this._prefs);

  final SharedPreferences _prefs;

  static const incidentIdKey = 'onboarding_real_ring_incident';
  static const incidentIdsKey = 'onboarding_real_ring_incidents';
  static const unclosedIdsKey = 'onboarding_real_ring_unclosed';

  /// Outlives [clear]: the alarm is answered after setup completes.
  static const firstToolIncidentKey = 'onboarding_first_tool_incident';

  /// Outlives [clear]. A handful of ids per setup run, capped.
  static const setupIncidentIdsKey = 'onboarding_setup_incidents';
  static const _setupIncidentCap = 20;

  @override
  String? get incidentId {
    final id = _prefs.getString(incidentIdKey);
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Set<String> get incidentIds => _read(incidentIdsKey);

  @override
  Set<String> get unclosedIds => _read(unclosedIdsKey);

  Set<String> _read(String key) => {
    for (final id in _prefs.getStringList(key) ?? const <String>[])
      if (id.isNotEmpty) id,
  };

  Future<void> _write(String key, Set<String> ids) async {
    if (ids.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setStringList(key, ids.toList());
    }
  }

  @override
  Future<void> hold(String incidentId) async {
    if (incidentId.isEmpty) return;
    await _prefs.setString(incidentIdKey, incidentId);
    await _write(incidentIdsKey, {...incidentIds, incidentId});
    await _remember(incidentId);
  }

  @override
  Set<String> get setupIncidentIds => _read(setupIncidentIdsKey);

  @override
  Future<void> holdFirstMessage(String incidentId) async {
    if (incidentId.isEmpty) return;
    await _prefs.setString(firstToolIncidentKey, incidentId);
    await _remember(incidentId);
  }

  @override
  String? get firstToolIncidentId {
    final id = _prefs.getString(firstToolIncidentKey);
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<void> forgetFirstTool() => _prefs.remove(firstToolIncidentKey);

  Future<void> _remember(String incidentId) async {
    final ids = [
      ...setupIncidentIds.where((id) => id != incidentId),
      incidentId,
    ];
    final kept = ids.length > _setupIncidentCap
        ? ids.sublist(ids.length - _setupIncidentCap)
        : ids;
    await _prefs.setStringList(setupIncidentIdsKey, kept);
  }

  @override
  Future<void> markUnclosed(String incidentId) async {
    await _write(incidentIdsKey, {...incidentIds}..remove(incidentId));
    await _write(unclosedIdsKey, {...unclosedIds, incidentId});
  }

  @override
  Future<void> markClosed(String incidentId) async {
    await _write(unclosedIdsKey, {...unclosedIds}..remove(incidentId));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(incidentIdKey);
    await _prefs.remove(incidentIdsKey);
  }
}
