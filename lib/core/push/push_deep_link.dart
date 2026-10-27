import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/paywall/paywall_source.dart' as paywall;
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
  static const String homeLocation = AppLinkRoutes.home;

  /// `open=paywall` comes from a locked widget. Widgets are part of Pro.
  static const openPaywall = 'paywall';
  static final String paywallLocation = paywall.paywallLocation(
    paywall.PaywallSource.widgetLocked,
  );

  /// A bare `/paywall` from the Android widget tap says where it came from.
  static String tagged(String location) =>
      location == paywall.paywallPath ? paywallLocation : location;

  /// `from=done` rides on an incident link that a native Done button
  /// opened: the Done on an acknowledged card, a Live Activity or a widget
  /// whose topic owes a wake-up challenge, which opens the app where it
  /// used to close. Native only draws Done on an incident it holds as
  /// acknowledged, so the marker means "native says this one is
  /// acknowledged". A plain tap on a card never carries it.
  ///
  /// Android `MainActivity.FROM_DONE` and iOS `WidgetLink.fromDone` hold
  /// the same two words. Keep the three in step.
  static const fromKey = 'from';
  static const fromDone = 'done';

  static String incidentLocation(
    String incidentId, {
    bool cameFromDone = false,
  }) {
    final location = AppLinkRoutes.incident(incidentId);
    return cameFromDone ? '$location?$fromKey=$fromDone' : location;
  }

  /// Whether a route the router is building came from a native Done.
  static bool cameFromDone(Uri location) =>
      location.queryParameters[fromKey] == fromDone;

  /// The incident id an incident route names, or null for any other
  /// route. The marker and anything else after `?` is not part of it.
  static String? incidentIdIn(String location) {
    final segments = Uri.tryParse(location)?.pathSegments ?? const <String>[];
    if (segments.length != 2 || segments.first != 'incidents') return null;
    return segments[1].isEmpty ? null : segments[1];
  }

  static String topicLocation(String topic) => AppLinkRoutes.topic(topic);

  /// Route for a relay push. Null for a `p4` forward with no incident, which
  /// has nothing specific to open.
  static String? forPush(IncidentPush push) {
    final id = push.incidentId;
    return id == null ? null : incidentLocation(id);
  }

  /// The scheme the Android tap intents carry on their data URI. It only keeps
  /// two PendingIntents apart; nothing outside the app sends one.
  static const String appScheme = appLinkScheme;

  /// Maps a `critalarm://` location that reached the router to a real route,
  /// or null when [location] is not one. `critalarm://incidents/<id>` opens
  /// that incident, `critalarm://topics/<name>` that topic, and any other
  /// `critalarm://` location (a reminder tap, say) opens Home. Never a Page
  /// Not Found.
  ///
  /// The answer comes from [parseAppLink], the one link parser. A connect
  /// link has no route, so one that got this far opens Home and its token
  /// goes nowhere.
  static String? fromAppUri(Uri location) {
    if (location.scheme != appScheme) return null;
    return switch (parseAppLink(location)) {
      AppLinkRoute(location: final route) =>
        // The marker survives on an incident link and on nothing else.
        cameFromDone(location) && incidentIdIn(route) != null
            ? '$route?$fromKey=$fromDone'
            : route,
      _ => homeLocation,
    };
  }

  /// Route for the extras attached to a tapped notification.
  static String? fromNotificationData(Map<String, String> data) {
    final incidentId = data[incidentIdKey];
    if (incidentId != null && incidentId.isNotEmpty) {
      return incidentLocation(
        incidentId,
        cameFromDone: data[fromKey] == fromDone,
      );
    }
    final topic = data[topicKey];
    if (topic != null && topic.isNotEmpty) return topicLocation(topic);
    if (data[openKey] == openHome) return homeLocation;
    if (data[openKey] == openPaywall) return paywallLocation;
    return null;
  }
}
