import 'package:critalarm/core/models/incident.dart';

/// Tells a test alarm from a real one.
abstract final class IncidentKinds {
  /// The title `POST /v1/test` gives its message (api.md 3.3).
  static const String testAlarmTitle = 'Crit Alarm test';

  /// Onboarding's local demo alarm.
  static const String demoIncidentId = 'inc_demo';
  static const String demoTopic = 'demo-topic';

  static bool isTest(Incident incident) =>
      incident.id == demoIncidentId ||
      incident.topic == demoTopic ||
      incident.messages.any((m) => m.title == testAlarmTitle);
}
