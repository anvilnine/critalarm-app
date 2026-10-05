import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';

/// [SetupTestRing] in memory.
class FakeSetupTestRing implements SetupTestRing {
  FakeSetupTestRing([Iterable<String> ids = const []]) {
    for (final id in ids) {
      incidentIds.add(id);
      setupIncidentIds.add(id);
      incidentId = id;
    }
  }

  @override
  String? incidentId;

  @override
  final Set<String> incidentIds = {};

  @override
  final Set<String> unclosedIds = {};

  @override
  final Set<String> setupIncidentIds = {};

  @override
  FirstToolAlarm? firstTool;

  /// What [holdFirstMessage] stamps a new record with.
  DateTime heldAt = DateTime(2026, 10, 4, 21, 45);

  @override
  String? get firstToolIncidentId => firstTool?.incidentId;

  @override
  Future<void> holdFirstMessage(String incidentId) async {
    firstTool = FirstToolAlarm(incidentId: incidentId, heldAt: heldAt);
    setupIncidentIds.add(incidentId);
  }

  @override
  Future<void> noteFirstToolSeen({
    required DateTime? openedAt,
    required DateTime? lastMessageAt,
  }) async {
    final held = firstTool;
    if (held == null) return;
    firstTool = FirstToolAlarm(
      incidentId: held.incidentId,
      heldAt: held.heldAt,
      openedAt: openedAt ?? held.openedAt,
      lastMessageAt: lastMessageAt ?? held.lastMessageAt,
      wasAcked: held.wasAcked,
    );
  }

  @override
  Future<void> noteFirstToolAcked() async {
    final held = firstTool;
    if (held == null) return;
    firstTool = FirstToolAlarm(
      incidentId: held.incidentId,
      heldAt: held.heldAt,
      openedAt: held.openedAt,
      lastMessageAt: held.lastMessageAt,
      wasAcked: true,
    );
  }

  @override
  Future<void> forgetFirstTool() async => firstTool = null;

  @override
  Future<void> settleFirstToolAtLaunch() async {
    if (firstTool?.wasAcked ?? false) firstTool = null;
  }

  @override
  Future<void> hold(String incidentId) async {
    this.incidentId = incidentId;
    incidentIds.add(incidentId);
    setupIncidentIds.add(incidentId);
  }

  @override
  Future<void> markUnclosed(String incidentId) async {
    incidentIds.remove(incidentId);
    unclosedIds.add(incidentId);
  }

  @override
  Future<void> markClosed(String incidentId) async {
    unclosedIds.remove(incidentId);
  }

  @override
  Future<void> clear() async {
    incidentId = null;
    incidentIds.clear();
  }
}
