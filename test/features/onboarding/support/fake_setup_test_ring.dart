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
  Future<void> holdFirstMessage(String incidentId) async {
    setupIncidentIds.add(incidentId);
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
