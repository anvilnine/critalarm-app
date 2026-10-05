import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SetupTestRing] on the phone: the newest id under
/// `onboarding_real_ring_incident`, every id of the run under
/// `onboarding_real_ring_incidents`, the ones still to close under
/// `onboarding_real_ring_unclosed`, and the alarm of the first hook-up
/// message under `onboarding_first_tool_incident`.
class PrefsSetupTestRing implements SetupTestRing {
  PrefsSetupTestRing(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static const incidentIdKey = 'onboarding_real_ring_incident';
  static const incidentIdsKey = 'onboarding_real_ring_incidents';
  static const unclosedIdsKey = 'onboarding_real_ring_unclosed';

  /// Outlives [clear]: the alarm is answered after setup completes.
  static const firstToolIncidentKey = 'onboarding_first_tool_incident';
  static const firstToolHeldAtKey = 'onboarding_first_tool_held_at';
  static const firstToolOpenedAtKey = 'onboarding_first_tool_opened_at';
  static const firstToolLastMessageAtKey =
      'onboarding_first_tool_last_message_at';
  static const firstToolAckedKey = 'onboarding_first_tool_acked';

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
    // A new record: nothing an earlier alarm left may describe this one.
    await forgetFirstTool();
    await _prefs.setString(firstToolIncidentKey, incidentId);
    await _prefs.setInt(firstToolHeldAtKey, _now().millisecondsSinceEpoch);
    await _remember(incidentId);
  }

  @override
  String? get firstToolIncidentId {
    final id = _prefs.getString(firstToolIncidentKey);
    return id == null || id.isEmpty ? null : id;
  }

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  FirstToolAlarm? get firstTool {
    final id = firstToolIncidentId;
    if (id == null) return null;
    return FirstToolAlarm(
      incidentId: id,
      // A record with no time is from a build that saved only the id. It
      // counts as held long ago, so only a ring it can prove is its first.
      heldAt:
          _time(firstToolHeldAtKey) ?? DateTime.fromMillisecondsSinceEpoch(0),
      openedAt: _time(firstToolOpenedAtKey),
      lastMessageAt: _time(firstToolLastMessageAtKey),
      wasAcked: _prefs.getBool(firstToolAckedKey) ?? false,
    );
  }

  @override
  Future<void> noteFirstToolSeen({
    required DateTime? openedAt,
    required DateTime? lastMessageAt,
  }) async {
    if (firstToolIncidentId == null) return;
    if (openedAt != null) {
      await _prefs.setInt(
        firstToolOpenedAtKey,
        openedAt.millisecondsSinceEpoch,
      );
    }
    if (lastMessageAt != null) {
      await _prefs.setInt(
        firstToolLastMessageAtKey,
        lastMessageAt.millisecondsSinceEpoch,
      );
    }
  }

  @override
  Future<void> noteFirstToolAcked() async {
    if (firstToolIncidentId == null) return;
    await _prefs.setBool(firstToolAckedKey, true);
  }

  @override
  Future<void> forgetFirstTool() async {
    await _prefs.remove(firstToolIncidentKey);
    await _prefs.remove(firstToolHeldAtKey);
    await _prefs.remove(firstToolOpenedAtKey);
    await _prefs.remove(firstToolLastMessageAtKey);
    await _prefs.remove(firstToolAckedKey);
  }

  @override
  Future<void> settleFirstToolAtLaunch() async {
    if (firstTool?.wasAcked ?? false) await forgetFirstTool();
  }

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
