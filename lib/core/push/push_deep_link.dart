import 'package:critalarm/core/push/incident_push.dart';

/// Where a tapped notification should land.
///
/// A push that carries an incident opens that incident. A priority 1-3 message
/// never reaches the relay (api.md §1.7), so its notification is posted locally
/// after a poll and carries the topic instead; those open the topic.
abstract final class PushDeepLink {
  static const incidentIdKey = 'incident_id';
  static const topicKey = 'topic';

  /// `open=home` comes from the open count widget, which has no incident or
  /// topic of its own and opens Home.
  static const openKey = 'open';
  static const openHome = 'home';
  static const homeLocation = '/';

  static String incidentLocation(String incidentId) =>
      '/incidents/${Uri.encodeComponent(incidentId)}';

  static String topicLocation(String topic) =>
      '/topics/${Uri.encodeComponent(topic)}';

  /// Route for a relay push. Null for a `p4` forward with no incident, which
  /// has nothing specific to open.
  static String? forPush(IncidentPush push) {
    final id = push.incidentId;
    return id == null ? null : incidentLocation(id);
  }

  /// Route for the extras attached to a tapped notification.
  static String? fromNotificationData(Map<String, String> data) {
    final incidentId = data[incidentIdKey];
    if (incidentId != null && incidentId.isNotEmpty) {
      return incidentLocation(incidentId);
    }
    final topic = data[topicKey];
    if (topic != null && topic.isNotEmpty) return topicLocation(topic);
    if (data[openKey] == openHome) return homeLocation;
    return null;
  }
}
