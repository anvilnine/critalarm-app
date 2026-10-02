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

  /// `open=paywall` comes from a locked widget. Widgets are part of Pro.
  static const openPaywall = 'paywall';
  static const paywallLocation = '/paywall';

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

  /// The scheme the Android tap intents carry on their data URI. It only keeps
  /// two PendingIntents apart; nothing outside the app sends one.
  static const appScheme = 'critalarm';

  /// Maps a `critalarm://` location that reached the router to a real route,
  /// or null when [location] is not one. `critalarm://incidents/<id>` opens
  /// that incident, `critalarm://topics/<name>` that topic, and any other
  /// `critalarm://` location (a reminder tap, say) opens Home. Never a Page
  /// Not Found.
  static String? fromAppUri(Uri location) {
    if (location.scheme != appScheme) return null;
    final segments = [
      for (final s in location.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.length == 1) {
      if (location.host == 'incidents') return incidentLocation(segments[0]);
      if (location.host == 'topics') return topicLocation(segments[0]);
    }
    return homeLocation;
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
    if (data[openKey] == openPaywall) return paywallLocation;
    return null;
  }
}
